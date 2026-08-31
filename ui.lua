--[[
	AuroraUI Core v1.2
	Ядро библиотеки. Загружается ПЕРВЫМ через loadstring.
	Содержит: сервисы, Drawing API, темы, Input, Element, UI (базовый).
	После ядра загрузите AuroraUI_components.lua.
]]

local AuroraUI = { Version = "1.2", Components = {} }

local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- ===== Drawing API =====
local DrawingLib = nil
do
	local function g(f) if f and f.Drawing then return f.Drawing end end
	pcall(function() DrawingLib = g(getgenv()) end)
	if not DrawingLib then pcall(function() DrawingLib = g(getrenv()) end) end
	if not DrawingLib then pcall(function() DrawingLib = g(shared) end) end
	if not DrawingLib and Drawing then DrawingLib = Drawing end
end
if not DrawingLib or not DrawingLib.new then
	error("[AuroraUI] Drawing API не найдена", 2)
end

local function NewDrawing(kind) return DrawingLib.new(kind) end

-- ===== Утилиты =====
local Utils = {}
function Utils.clamp(v, a, b) if v < a then return a end if v > b then return b end return v end
function Utils.round(v) return math.floor(v + 0.5) end
function Utils.easeOut(t) return 1 - (1 - t) * (1 - t) end
function Utils.hex(c) return string.format("#%02X%02X%02X", Utils.round(c.R * 255), Utils.round(c.G * 255), Utils.round(c.B * 255)) end

local clamp = Utils.clamp

-- ===== Темы =====
local Themes = {
	Dark = {
		Background = Color3.fromRGB(18,18,24), Secondary = Color3.fromRGB(28,28,36),
		Element = Color3.fromRGB(36,36,46), Accent = Color3.fromRGB(80,130,255),
		AccentDark = Color3.fromRGB(60,100,210), Text = Color3.fromRGB(230,230,238),
		Subtext = Color3.fromRGB(140,140,152), Border = Color3.fromRGB(48,48,58),
		Danger = Color3.fromRGB(220,80,80)
	},
	Light = {
		Background = Color3.fromRGB(240,240,245), Secondary = Color3.fromRGB(255,255,255),
		Element = Color3.fromRGB(225,225,230), Accent = Color3.fromRGB(60,110,255),
		AccentDark = Color3.fromRGB(40,90,220), Text = Color3.fromRGB(20,20,25),
		Subtext = Color3.fromRGB(110,110,120), Border = Color3.fromRGB(200,200,210),
		Danger = Color3.fromRGB(200,60,60)
	}
}

-- ===== Input =====
local Input = {}
Input.__index = Input
function Input.new()
	return setmetatable({ MousePos = Vector2.new(), HeldElement = nil, KeyPressed = nil,
		BindingTarget = nil, UI = nil, FocusedTextbox = nil }, Input)
end
function Input:Init(ui)
	self.UI = ui
	UIS.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local e = self.UI:GetTopElementAt(self.MousePos)
			self.HeldElement = e
			if e and e.OnMouseDown then e:OnMouseDown(self.MousePos) end
		elseif input.UserInputType == Enum.UserInputType.Keyboard then
			self.KeyPressed = input.KeyCode
			if self.BindingTarget then self.BindingTarget:SetKey(input.KeyCode) self.BindingTarget = nil end
		end
	end)
	UIS.InputChanged:Connect(function(input, gp)
		if gp then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			self.MousePos = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UIS.InputEnded:Connect(function(input, gp)
		if gp then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local e = self.HeldElement self.HeldElement = nil
			if e then
				if e:IsInBounds(self.MousePos) and e.OnClick then e:OnClick(self.MousePos) end
				if e.OnMouseUp then e:OnMouseUp(self.MousePos) end
			end
		end
	end)
end
function Input:BeginKeybind(t) self.BindingTarget = t end
function Input:SetFocused(tb) self.FocusedTextbox = tb end

-- ===== Element =====
local Element = {}
Element.__index = Element
function Element.new(ui, p)
	p = p or {}
	local s = setmetatable({
		UI = ui, Parent = p.Parent, Position = p.Position or Vector2.new(),
		Size = p.Size or Vector2.new(100,20), Visible = p.Visible ~= false,
		ZIndex = p.ZIndex or 1, Drawings = {}, Children = {},
		AbsPos = Vector2.new(), AbsSize = Vector2.new(), Hovered = false,
		Alpha = 1, Animating = false
	}, Element)
	if s.Parent then s.Parent:AddChild(s) end
	ui:RegisterElement(s)
	s:Create()
	return s
end
function Element:AddChild(c) table.insert(self.Children, c) c.Parent = self end
function Element:AddDrawing(kind, p)
	p = p or {}
	local d = NewDrawing(kind)
	d.Position = p.Position or Vector2.new(); d.Size = p.Size or Vector2.new(100,20)
	d.Color = p.Color or Color3.new(1,1,1); d.Transparency = p.Transparency or 0
	d.Visible = p.Visible ~= false; d.ZIndex = self.ZIndex
	if kind == "Text" then
		d.Text = p.Text or ""; d.Font = p.Font or 3; d.Size = p.FontSize or 15
		d.Center = p.Center ~= false; d.Outline = p.Outline ~= false
	end
	table.insert(self.Drawings, d); return d
end
function Element:SetVisible(v, prop)
	self.Visible = v
	for _, d in ipairs(self.Drawings) do d.Visible = v end
	if prop ~= false then for _, c in ipairs(self.Children) do c:SetVisible(v, prop) end end
end
function Element:SetZIndex(z)
	self.ZIndex = z
	for _, d in ipairs(self.Drawings) do d.ZIndex = z end
	for _, c in ipairs(self.Children) do c:SetZIndex(z + 1) end
end
function Element:UpdateAbs()
	self.AbsPos = self.Parent and (self.Parent.AbsPos + self.Position) or self.Position
	self.AbsSize = self.Size
	for _, c in ipairs(self.Children) do c:UpdateAbs() end
end
function Element:IsInBounds(pos)
	if not self.Visible then return false end
	return pos.X >= self.AbsPos.X and pos.X <= self.AbsPos.X + self.AbsSize.X
		and pos.Y >= self.AbsPos.Y and pos.Y <= self.AbsPos.Y + self.AbsSize.Y
end
function Element:Render()
	for _, d in ipairs(self.Drawings) do
		if d.Type == "Frame" or d.Type == "Square" then
			d.Position = self.AbsPos; d.Size = self.AbsSize
		end
	end
	for _, c in ipairs(self.Children) do c:Render() end
end
function Element:Destroy()
	for _, d in ipairs(self.Drawings) do pcall(function() d:Remove() end) end
	for _, c in ipairs(self.Children) do c:Destroy() end
	self.Children = {}
	if self.Parent then
		local nc = {}
		for _, c in ipairs(self.Parent.Children) do if c ~= self then table.insert(nc, c) end end
		self.Parent.Children = nc self.Parent = nil
	end
	self.UI:UnregisterElement(self)
end
function Element:AnimateTo(goal, dur, cb)
	self.AnimFrom = self.Alpha; self.AnimTo = goal; self.AnimStart = tick()
	self.AnimDuration = dur or 0.3; self.Animating = true; self.AnimComplete = cb
end
function Element:UpdateAnimation()
	if not self.Animating then return end
	local t = clamp((tick() - self.AnimStart) / self.AnimDuration, 0, 1)
	self.Alpha = self.AnimFrom + (self.AnimTo - self.AnimFrom) * Utils.easeOut(t)
	if t >= 1 then
		self.Animating = false; self.Alpha = self.AnimTo
		local cb = self.AnimComplete self.AnimComplete = nil if cb then cb() end
	end
end

-- ===== UI (базовый) =====
local UI = {}
UI.__index = UI
function UI.new(cfg)
	cfg = cfg or {}
	local themeName = cfg.Theme or "Dark"
	local theme = Themes[themeName] or Themes.Dark
	local s = setmetatable({
		Name = cfg.Name or "AuroraUI", ThemeName = themeName, Theme = theme,
		Accent = cfg.Accent or theme.Accent, AccentDark = cfg.AccentDark or theme.AccentDark,
		Elements = {}, Windows = {}, Input = Input.new(),
		AutoSave = cfg.AutoSave ~= false, ConfigFile = cfg.ConfigFile or "aurora_config.json",
		Initialized = false, RenderLoop = nil, UnloadCallback = cfg.UnloadCallback, OnReady = cfg.OnReady
	}, UI)
	if cfg.Accent then
		s.AccentDark = Color3.new(clamp(cfg.Accent.R * 0.8, 0, 1), clamp(cfg.Accent.G * 0.8, 0, 1), clamp(cfg.Accent.B * 0.8, 0, 1))
	end
	s.Input:Init(s)
	s:Init()
	return s
end
function UI:Init()
	if self.Initialized then return end
	self.Initialized = true
	self.RenderLoop = RunService.Heartbeat:Connect(function() self:Render() end)
	if self.AutoSave then self:LoadConfig() end
	if self.OnReady then self.OnReady() end
end
function UI:RegisterElement(e) table.insert(self.Elements, e) end
function UI:UnregisterElement(e)
	local nl = {}
	for _, x in ipairs(self.Elements) do if x ~= e then table.insert(nl, x) end end
	self.Elements = nl
end
function UI:GetTopElementAt(pos)
	local top, topZ = nil, -math.huge
	for _, e in ipairs(self.Elements) do
		if e.Visible and e:IsInBounds(pos) and e.ZIndex > topZ then top, topZ = e, e.ZIndex end
	end
	return top
end
function UI:Render()
	for _, e in ipairs(self.Elements) do if e.Visible or e.Animating then e:UpdateAbs() end end
	for _, e in ipairs(self.Elements) do if e.Animating then e:UpdateAnimation() end end
	for _, e in ipairs(self.Elements) do if e.Visible or e.Animating then e:Render() end end
	if self.Input.FocusedTextbox and self.Input.FocusedTextbox.Focused and self.Input.KeyPressed then
		self.Input.FocusedTextbox:TypeKey(self.Input.KeyPressed)
	end
	for _, e in ipairs(self.Elements) do if e.UpdateDrag then e:UpdateDrag() end end
	self.Input.KeyPressed = nil
end
function UI:CreateWindow(title, props)
	props = props or {}
	local Window = AuroraUI.Components.Window
	if not Window then error("[AuroraUI] Компоненты не загружены. Сначала запустите AuroraUI_components.lua", 2) end
	local w = Window.new(self, {
		Title = title or "Window", Position = props.Position or Vector2.new(100, 100),
		Size = props.Size or Vector2.new(480, 320), ZIndex = 10,
		Resizable = props.Resizable ~= false, Draggable = props.Draggable ~= false })
	table.insert(self.Windows, w)
	return w
end
function UI:SetTheme(name, accent)
	if not Themes[name] then return end
	self.ThemeName = name self.Theme = Themes[name]
	if accent then
		self.Accent = accent
		self.AccentDark = Color3.new(clamp(accent.R * 0.8, 0, 1), clamp(accent.G * 0.8, 0, 1), clamp(accent.B * 0.8, 0, 1))
	end
	for _, e in ipairs(self.Elements) do if e.UpdateTheme then e:UpdateTheme() end end
end
function UI:SetAccent(color)
	self.Accent = color
	self.AccentDark = Color3.new(clamp(color.R * 0.8, 0, 1), clamp(color.G * 0.8, 0, 1), clamp(color.B * 0.8, 0, 1))
	for _, e in ipairs(self.Elements) do if e.UpdateTheme then e:UpdateTheme() end end
end
function UI:SaveConfig()
	local data = {}
	for _, w in ipairs(self.Windows) do data[w.ConfigKey] = w:GetConfig() end
	if writefile then pcall(function() writefile(self.ConfigFile, HttpService:JSONEncode(data)) end) end
end
function UI:LoadConfig()
	if not readfile then return end
	local ok, raw = pcall(readfile, self.ConfigFile)
	if not ok or not raw then return end
	local data = HttpService:JSONDecode(raw)
	for _, w in ipairs(self.Windows) do if data[w.ConfigKey] then w:SetConfig(data[w.ConfigKey]) end end
end
function UI:Unload()
	if self.RenderLoop then self.RenderLoop:Disconnect() self.RenderLoop = nil end
	for _, e in ipairs(self.Elements) do e:Destroy() end
	self.Elements = {} self.Windows = {}
	if self.UnloadCallback then self.UnloadCallback() end
end
function UI:Restart()
	self:Unload() self.Initialized = false self:Init()
end

-- ===== Регистрация компонентов =====
function AuroraUI:RegisterComponent(name, ctor)
	self.Components[name] = ctor
end

AuroraUI.new = function(cfg) return UI.new(cfg) end
AuroraUI.Element = Element
AuroraUI.Input = Input
AuroraUI.UI = UI
AuroraUI.Themes = Themes
AuroraUI.Utils = Utils
AuroraUI.NewDrawing = NewDrawing

if getgenv then getgenv().AuroraCore = AuroraUI end
return AuroraUI
