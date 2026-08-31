--[[
	AuroraUI — универсальная UI библиотека для Roblox exploiting
	Версия: 1.0.0

	Поддерживаемые API:
	  - Универсальный Drawing API (getgenv / getrenv / global)
	  - UserInputService, RunService, HttpService
	  - writefile / readfile для сохранения конфигурации

	Быстрый старт:
	  local lib = loadstring(game:HttpGet("..."))()
	  local win = lib:CreateWindow("My Hub")
	  local tab = win:CreateTab("Main")
	  local section = tab:CreateSection("Combat")
	  section:AddToggle("Aimbot", false, function(v) print(v) end)
	  section:AddSlider("Speed", 0, 100, 50, function(v) print(v) end)
	  section:AddButton("Execute", function() print("clicked") end)
	  lib:Init()

	Автор: Eldar Elmurodov
]]

local AuroraUI = { Version = "1.0.0" }

-- ===================== СЕРВИСЫ =====================
local gameInstance = game
local UIS = gameInstance:GetService("UserInputService")
local RunService = gameInstance:GetService("RunService")
local HttpService = gameInstance:GetService("HttpService")

-- ===================== DRAWING API =====================
local DrawingLib = nil
do
	local function safeGet(from)
		if from and from.Drawing then
			return from.Drawing
		end
	end
	pcall(function() DrawingLib = safeGet(getgenv()) end)
	if not DrawingLib then pcall(function() DrawingLib = safeGet(getrenv()) end) end
	if not DrawingLib then pcall(function() DrawingLib = safeGet(shared) end) end
	if not DrawingLib and Drawing then DrawingLib = Drawing end
end

if not DrawingLib or not DrawingLib.new then
	return error("[AuroraUI] Drawing API не найдена. Убедитесь, что библиотека загружена через loadstring в поддерживаемом исполнителе.", 2)
end

local function NewDrawing(kind)
	return DrawingLib.new(kind)
end

-- ===================== УТИЛИТЫ =====================
local function clamp(v, min, max)
	if v < min then return min end
	if v > max then return max end
	return v
end

local function round(v)
	return math.floor(v + 0.5)
end

local function easeOutQuad(t)
	return 1 - (1 - t) * (1 - t)
end

local function easeInOutQuad(t)
	if t < 0.5 then
		return 2 * t * t
	else
		return 1 - math.pow(-2 * t + 2, 2) / 2
	end
end

local function ColorToHex(c)
	return string.format("#%02X%02X%02X", round(c.R * 255), round(c.G * 255), round(c.B * 255))
end

local function HexToColor(hex)
	hex = hex:gsub("#", "")
	if #hex == 3 then
		hex = string.format("%c%c%c%c%c%c", hex:sub(1,1), hex:sub(1,1), hex:sub(2,2), hex:sub(2,2), hex:sub(3,3), hex:sub(3,3))
	end
	if #hex ~= 6 then
		return Color3.fromRGB(255, 255, 255)
	end
	local r = tonumber(hex:sub(1,2), 16) or 255
	local g = tonumber(hex:sub(3,4), 16) or 255
	local b = tonumber(hex:sub(5,6), 16) or 255
	return Color3.fromRGB(r, g, b)
end

local function TextWidth(text, fontSize)
	fontSize = fontSize or 15
	return #text * (fontSize * 0.58) + 8
end

-- ===================== ТЕМЫ =====================
local Themes = {
	Dark = {
		Background = Color3.fromRGB(18, 18, 24),
		Secondary = Color3.fromRGB(28, 28, 36),
		Element = Color3.fromRGB(36, 36, 46),
		Accent = Color3.fromRGB(80, 130, 255),
		AccentDark = Color3.fromRGB(60, 100, 210),
		Text = Color3.fromRGB(230, 230, 238),
		Subtext = Color3.fromRGB(140, 140, 152),
		Border = Color3.fromRGB(48, 48, 58),
		Danger = Color3.fromRGB(220, 80, 80)
	},
	Light = {
		Background = Color3.fromRGB(240, 240, 245),
		Secondary = Color3.fromRGB(255, 255, 255),
		Element = Color3.fromRGB(225, 225, 230),
		Accent = Color3.fromRGB(60, 110, 255),
		AccentDark = Color3.fromRGB(40, 90, 220),
		Text = Color3.fromRGB(20, 20, 25),
		Subtext = Color3.fromRGB(110, 110, 120),
		Border = Color3.fromRGB(200, 200, 210),
		Danger = Color3.fromRGB(200, 60, 60)
	}
}

-- ===================== INPUT =====================
local Input = {}
Input.__index = Input

function Input.new()
	local self = setmetatable({}, Input)
	self.MousePos = Vector2.new(0, 0)
	self.MouseDown = false
	self.MouseDownPos = nil
	self.HeldElement = nil
	self.KeyPressed = nil
	self.BindingTarget = nil
	self.UI = nil
	self.FocusedTextbox = nil
	return self
end

function Input:Init(ui)
	self.UI = ui
	UIS.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.MouseDown = true
			self.MouseDownPos = self.MousePos
			local elem = self.UI:GetTopElementAt(self.MousePos)
			self.HeldElement = elem
			if elem and elem.OnMouseDown then
				elem:OnMouseDown(self.MousePos)
			end
		elseif input.UserInputType == Enum.UserInputType.Keyboard then
			self.KeyPressed = input.KeyCode
			if self.BindingTarget then
				self.BindingTarget:SetKey(input.KeyCode)
				self.BindingTarget = nil
			end
		end
	end)

	UIS.InputChanged:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			self.MousePos = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	UIS.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.MouseDown = false
			local elem = self.HeldElement
			self.HeldElement = nil
			if elem then
				if elem:IsInBounds(self.MousePos) and elem.OnClick then
					elem:OnClick(self.MousePos)
				end
				if elem.OnMouseUp then
					elem:OnMouseUp(self.MousePos)
				end
			end
		end
	end)
end

function Input:BeginKeybind(target)
	self.BindingTarget = target
end

function Input:SetFocused(textbox)
	self.FocusedTextbox = textbox
end

-- ===================== БАЗОВЫЙ ЭЛЕМЕНТ =====================
local Element = {}
Element.__index = Element

function Element.new(ui, props)
	props = props or {}
	local self = setmetatable({}, Element)
	self.UI = ui
	self.Parent = props.Parent
	self.Position = props.Position or Vector2.new(0, 0)
	self.Size = props.Size or Vector2.new(100, 20)
	self.Visible = props.Visible ~= false
	self.ZIndex = props.ZIndex or 1
	self.Drawings = {}
	self.Children = {}
	self.AbsPos = Vector2.new(0, 0)
	self.AbsSize = Vector2.new(0, 0)
	self.Type = "Element"
	self.Hovered = false
	self.Alpha = 1
	self.Animating = false
	self.AnimStart = 0
	self.AnimDuration = 0
	self.AnimFrom = 1
	self.AnimTo = 1

	if self.Parent then
		self.Parent:AddChild(self)
	end
	ui:RegisterElement(self)
	self:Create()
	return self
end

function Element:AddChild(child)
	table.insert(self.Children, child)
	child.Parent = self
end

function Element:AddDrawing(kind, props)
	props = props or {}
	local d = NewDrawing(kind)
	d.Position = props.Position or Vector2.new(0, 0)
	d.Size = props.Size or Vector2.new(100, 20)
	d.Color = props.Color or Color3.fromRGB(255, 255, 255)
	d.Transparency = props.Transparency or 0
	d.Visible = props.Visible ~= false
	d.ZIndex = self.ZIndex
	if kind == "Text" then
		d.Text = props.Text or ""
		d.Font = props.Font or 3
		d.Size = props.FontSize or 15
		d.Center = props.Center ~= false
		d.Outline = props.Outline ~= false
	elseif kind == "Line" then
		d.Thickness = props.Thickness or 1
		d.From = props.From or Vector2.new(0, 0)
		d.To = props.To or Vector2.new(1, 1)
	end
	table.insert(self.Drawings, d)
	return d
end

function Element:SetVisible(v, propagate)
	self.Visible = v
	for _, d in ipairs(self.Drawings) do
		d.Visible = v
	end
	if propagate ~= false then
		for _, c in ipairs(self.Children) do
			c:SetVisible(v, propagate)
		end
	end
end

function Element:SetZIndex(z)
	self.ZIndex = z
	for _, d in ipairs(self.Drawings) do
		d.ZIndex = z
	end
	for _, c in ipairs(self.Children) do
		c:SetZIndex(z + 1)
	end
end

function Element:UpdateAbs()
	if self.Parent then
		self.AbsPos = self.Parent.AbsPos + self.Position
	else
		self.AbsPos = self.Position
	end
	self.AbsSize = self.Size
	for _, c in ipairs(self.Children) do
		c:UpdateAbs()
	end
end

function Element:IsInBounds(pos)
	if not self.Visible then return false end
	local p = self.AbsPos
	local s = self.AbsSize
	if s.X == 0 or s.Y == 0 then return false end
	return pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y
end

function Element:Render()
	for _, d in ipairs(self.Drawings) do
		if d.Type == "Frame" or d.Type == "Square" or d.Type == "Rectangle" then
			d.Position = self.AbsPos
			d.Size = self.AbsSize
		elseif d.Type == "Line" then
			d.From = self.AbsPos
			d.To = self.AbsPos + self.Size
		end
	end
	for _, c in ipairs(self.Children) do
		c:Render()
	end
end

function Element:Destroy()
	for _, d in ipairs(self.Drawings) do
		pcall(function() d:Remove() end)
	end
	for _, c in ipairs(self.Children) do
		c:Destroy()
	end
	self.Children = {}
	if self.Parent then
		local newChildren = {}
		for _, c in ipairs(self.Parent.Children) do
			if c ~= self then
				table.insert(newChildren, c)
			end
		end
		self.Parent.Children = newChildren
		self.Parent = nil
	end
	if self.UI then
		self.UI:UnregisterElement(self)
	end
end

function Element:AnimateTo(goal, duration, onComplete)
	self.AnimFrom = self.Alpha
	self.AnimTo = goal
	self.AnimStart = tick()
	self.AnimDuration = duration or 0.3
	self.Animating = true
	self.AnimComplete = onComplete
end

function Element:UpdateAnimation()
	if not self.Animating then return end
	local dt = tick() - self.AnimStart
	local t = clamp(dt / self.AnimDuration, 0, 1)
	self.Alpha = self.AnimFrom + (self.AnimTo - self.AnimFrom) * easeOutQuad(t)
	if t >= 1 then
		self.Animating = false
		self.Alpha = self.AnimTo
		if self.AnimComplete then
			local cb = self.AnimComplete
			self.AnimComplete = nil
			cb()
		end
	end
end

-- ===================== UI =====================
local UI = {}
UI.__index = UI

function UI.new(config)
	config = config or {}
	local self = setmetatable({}, UI)
	self.Name = config.Name or "AuroraUI"
	self.ThemeName = config.Theme or "Dark"
	self.Theme = Themes[self.ThemeName] or Themes.Dark
	self.Accent = config.Accent or self.Theme.Accent
	self.AccentDark = config.AccentDark or self.Theme.AccentDark
	self.Elements = {}
	self.Windows = {}
	self.Input = Input.new()
	self.WatermarkObjects = {}
	self.AutoSave = config.AutoSave ~= false
	self.ConfigFile = config.ConfigFile or "aurora_config.json"
	self.Loaded = false
	self.Initialized = false
	self.RenderLoop = nil
	self.UnloadCallback = config.UnloadCallback
	self.OnReady = config.OnReady

	self.Input:Init(self)
	self:Init()
	return self
end

function UI:Init()
	if self.Initialized then return end
	self.Initialized = true

	self.RenderLoop = RunService.Heartbeat:Connect(function(dt)
		self:Render(dt)
	end)

	if self.AutoSave then
		self:LoadConfig()
	end

	if self.OnReady then
		self.OnReady()
	end
end

function UI:RegisterElement(elem)
	table.insert(self.Elements, elem)
end

function UI:UnregisterElement(elem)
	local newList = {}
	for _, e in ipairs(self.Elements) do
		if e ~= elem then
			table.insert(newList, e)
		end
	end
	self.Elements = newList
end

function UI:GetTopElementAt(pos)
	local top = nil
	local topZ = -math.huge
	for _, elem in ipairs(self.Elements) do
		if elem.Visible and elem:IsInBounds(pos) then
			if elem.ZIndex > topZ then
				top = elem
				topZ = elem.ZIndex
			end
		end
	end
	return top
end

function UI:Render(dt)
	-- обновление позиций
	for _, elem in ipairs(self.Elements) do
		if elem.Visible or elem.Animating then
			elem:UpdateAbs()
		end
	end
	-- анимации
	for _, elem in ipairs(self.Elements) do
		if elem.Animating then
			elem:UpdateAnimation()
		end
	end
	-- рендер
	for _, elem in ipairs(self.Elements) do
		if elem.Visible or elem.Animating then
			elem:Render()
		end
	end
	-- обработка нажатий клавиш для Textbox
	if self.Input and self.Input.FocusedTextbox and self.Input.FocusedTextbox.Focused then
		local tb = self.Input.FocusedTextbox
		if self.Input.KeyPressed then
			local key = self.Input.KeyPressed
			tb:TypeKey(key)
		end
	end
	-- обработка драг окон и слайдеров
	for _, elem in ipairs(self.Elements) do
		if elem.UpdateDrag then
			elem:UpdateDrag()
		end
	end
	-- сброс KeyPressed после обработки
	if self.Input then
		self.Input.KeyPressed = nil
	end
end

function UI:CreateWindow(title, props)
	props = props or {}
	local win = Window.new(self, {
		Title = title or "Window",
		Position = props.Position or Vector2.new(100, 100),
		Size = props.Size or Vector2.new(480, 320),
		ZIndex = 10,
		Resizable = props.Resizable ~= false,
		Draggable = props.Draggable ~= false
	})
	table.insert(self.Windows, win)
	return win
end

function UI:SetTheme(name, accent)
	if Themes[name] then
		self.ThemeName = name
		self.Theme = Themes[name]
		if accent then
			self.Accent = accent
			self.AccentDark = Color3.new(
				clamp(accent.R * 0.8, 0, 1),
				clamp(accent.G * 0.8, 0, 1),
				clamp(accent.B * 0.8, 0, 1)
			)
		end
		for _, elem in ipairs(self.Elements) do
			if elem.UpdateTheme then
				elem:UpdateTheme()
			end
		end
	end
end

function UI:SetAccent(color)
	self.Accent = color
	self.AccentDark = Color3.new(
		clamp(color.R * 0.8, 0, 1),
		clamp(color.G * 0.8, 0, 1),
		clamp(color.B * 0.8, 0, 1)
	)
	for _, elem in ipairs(self.Elements) do
		if elem.UpdateTheme then
			elem:UpdateTheme()
		end
	end
end

function UI:SaveConfig()
	local data = {}
	for _, w in ipairs(self.Windows) do
		data[w.ConfigKey] = w:GetConfig()
	end
	local json = HttpService:JSONEncode(data)
	if writefile then
		pcall(function() writefile(self.ConfigFile, json) end)
	end
end

function UI:LoadConfig()
	if not readfile then return end
	local ok, raw = pcall(readfile, self.ConfigFile)
	if not ok or not raw then return end
	local data = HttpService:JSONDecode(raw)
	for _, w in ipairs(self.Windows) do
		if data[w.ConfigKey] then
			w:SetConfig(data[w.ConfigKey])
		end
	end
end

function UI:Unload()
	if self.RenderLoop then
		self.RenderLoop:Disconnect()
		self.RenderLoop = nil
	end
	for _, elem in ipairs(self.Elements) do
		elem:Destroy()
	end
	self.Elements = {}
	self.Windows = {}
	if self.UnloadCallback then
		self.UnloadCallback()
	end
end

function UI:Restart()
	self:Unload()
	self.Loaded = false
	self.Initialized = false
	self:Init()
end

function UI:Watermark(text, props)
	props = props or {}
	local wm = Watermark.new(self, {
		Text = text,
		Position = props.Position or Vector2.new(10, 10),
		FontSize = props.FontSize or 18,
		Accent = props.Accent
	})
	table.insert(self.WatermarkObjects, wm)
	return wm
end

-- ===================== WATERMARK =====================
local Watermark = {}
Watermark.__index = Watermark
setmetatable(Watermark, Element)

function Watermark.new(ui, props)
	local self = Element.new(ui, {
		Parent = nil,
		Position = props.Position or Vector2.new(10, 10),
		Size = Vector2.new(TextWidth(props.Text or "", props.FontSize or 18), props.FontSize or 18),
		ZIndex = 999,
		Visible = true
	})
	setmetatable(self, Watermark)
	self.Text = props.Text or ""
	self.FontSize = props.FontSize or 18
	self.AccentColor = props.Accent or ui.Accent
	self:Create()
	return self
end

function Watermark:Create()
	self.TextDraw = self:AddDrawing("Text", {
		Text = self.Text,
		FontSize = self.FontSize,
		Color = self.AccentColor,
		Center = false
	})
	self.TextDraw.Outline = true
	self.TextDraw.OutlineColor = Color3.new(0, 0, 0)
end

function Watermark:Render()
	Watermark.__index.Render(self)
	if self.TextDraw then
		self.TextDraw.Position = self.AbsPos
		self.TextDraw.Text = self.Text
		self.TextDraw.Size = self.FontSize
		self.TextDraw.Color = self.AccentColor
		self.TextDraw.Transparency = 1 - self.Alpha
	end
end

function Watermark:SetText(text)
	self.Text = text
end

-- ===================== WINDOW =====================
local Window = {}
Window.__index = Window
setmetatable(Window, Element)

function Window.new(ui, props)
	local self = Element.new(ui, {
		Parent = nil,
		Position = props.Position or Vector2.new(100, 100),
		Size = props.Size or Vector2.new(480, 320),
		ZIndex = props.ZIndex or 10,
		Visible = true
	})
	setmetatable(self, Window)
	self.Title = props.Title or "Window"
	self.Tabs = {}
	self.ActiveTab = nil
	self.Draggable = props.Draggable ~= false
	self.Resizable = props.Resizable ~= false
	self.Dragging = false
	self.Resizing = false
	self.DragOffset = Vector2.new(0, 0)
	self.ResizeStart = nil
	self.ResizeSizeStart = nil
	self.Minimized = false
	self.MinSize = Vector2.new(200, 150)
	self.ConfigKey = string.format("window_%s", self.Title)
	self.ContentOffset = Vector2.new(10, 45)
	self.TabBarHeight = 30
	self:Create()
	self:UpdateTheme()
	return self
end

function Window:Create()
	local ui = self.UI
	self.Bg = self:AddDrawing("Frame", {
		Color = ui.Theme.Background,
		Transparency = 0.05,
		Visible = true
	})
	self.Border = self:AddDrawing("Frame", {
		Color = ui.Theme.Border,
		Transparency = 0,
		Visible = true
	})
	self.TitleBar = self:AddDrawing("Frame", {
		Color = ui.Theme.Secondary,
		Transparency = 0,
		Visible = true
	})
	self.TitleText = self:AddDrawing("Text", {
		Text = self.Title,
		FontSize = 16,
		Color = ui.Theme.Text,
		Center = false
	})
	self.TitleText.Outline = false
	self.CloseBtn = self:AddDrawing("Frame", {
		Color = ui.Theme.Danger,
		Transparency = 0,
		Visible = true
	})
	self.CloseText = self:AddDrawing("Text", {
		Text = "X",
		FontSize = 14,
		Color = Color3.fromRGB(255,255,255),
		Center = true
	})
	self.CloseText.Outline = false
	self.MinBtn = self:AddDrawing("Frame", {
		Color = ui.Theme.Element,
		Transparency = 0,
		Visible = true
	})
	self.MinText = self:AddDrawing("Text", {
		Text = "—",
		FontSize = 14,
		Color = ui.Theme.Text,
		Center = true
	})
	self.MinText.Outline = false
	if self.Resizable then
		self.ResizeHandle = self:AddDrawing("Frame", {
			Color = ui.Theme.Accent,
			Transparency = 0.3,
			Visible = true
		})
	end
end

function Window:UpdateTheme()
	local ui = self.UI
	if self.Bg then self.Bg.Color = ui.Theme.Background end
	if self.Border then self.Border.Color = ui.Theme.Border end
	if self.TitleBar then self.TitleBar.Color = ui.Theme.Secondary end
	if self.TitleText then self.TitleText.Color = ui.Theme.Text end
	if self.CloseBtn then self.CloseBtn.Color = ui.Theme.Danger end
	if self.MinBtn then self.MinBtn.Color = ui.Theme.Element end
	if self.MinText then self.MinText.Color = ui.Theme.Text end
end

function Window:Render()
	Window.__index.Render(self)
	local ui = self.UI
	local p = self.AbsPos
	local s = self.AbsSize
	local th = 30

	if self.Bg then
		self.Bg.Position = p
		self.Bg.Size = s
		self.Bg.Transparency = 0.05 * (1 - self.Alpha)
	end
	if self.Border then
		self.Border.Position = p
		self.Border.Size = Vector2.new(s.X, 1)
		self.Border.Transparency = 1 - self.Alpha
	end
	if self.TitleBar then
		self.TitleBar.Position = p
		self.TitleBar.Size = Vector2.new(s.X, th)
		self.TitleBar.Transparency = 1 - self.Alpha
	end
	if self.TitleText then
		self.TitleText.Position = p + Vector2.new(10, 6)
		self.TitleText.Text = self.Title
		self.TitleText.Size = 16
		self.TitleText.Transparency = 1 - self.Alpha
	end
	local closeSize = Vector2.new(24, 20)
	local closePos = p + Vector2.new(s.X - 30, 5)
	if self.CloseBtn then
		self.CloseBtn.Position = closePos
		self.CloseBtn.Size = closeSize
		self.CloseBtn.Transparency = 1 - self.Alpha
	end
	if self.CloseText then
		self.CloseText.Position = closePos + Vector2.new(0, -1)
		self.CloseText.Size = 14
		self.CloseText.Transparency = 1 - self.Alpha
	end
	local minPos = closePos - Vector2.new(26, 0)
	if self.MinBtn then
		self.MinBtn.Position = minPos
		self.MinBtn.Size = closeSize
		self.MinBtn.Transparency = 1 - self.Alpha
	end
	if self.MinText then
		self.MinText.Position = minPos + Vector2.new(0, -1)
		self.MinText.Size = 14
		self.MinText.Transparency = 1 - self.Alpha
	end
	if self.ResizeHandle and self.Resizable then
		self.ResizeHandle.Position = p + s - Vector2.new(12, 12)
		self.ResizeHandle.Size = Vector2.new(12, 12)
		self.ResizeHandle.Transparency = 0.3 * (1 - self.Alpha)
	end

	-- обновление позиции табов
	local tabX = 10
	for _, tab in ipairs(self.Tabs) do
		tab.Position = Vector2.new(tabX, 32)
		tabX = tabX + 90
		if tab.Active then
			tab.ButtonColor = ui.Accent
		else
			tab.ButtonColor = ui.Theme.Element
		end
	end

	-- если не минимизировано, позиционируем активный контент
	if self.ActiveTab and not self.Minimized then
		self.ActiveTab:SetVisible(true)
		self.ActiveTab.Position = self.ContentOffset
	elseif self.ActiveTab and self.Minimized then
		self.ActiveTab:SetVisible(false)
	end
end

function Window:CreateTab(name)
	local tab = Tab.new(self.UI, {
		Parent = self,
		Name = name,
		Position = Vector2.new(10 + (#self.Tabs * 90), 32),
		Size = Vector2.new(80, 22),
		ZIndex = self.ZIndex + 1
	})
	table.insert(self.Tabs, tab)
	if #self.Tabs == 1 then
		self:SetActiveTab(tab)
	end
	return tab
end

function Window:SetActiveTab(tab)
	if self.ActiveTab then
		self.ActiveTab:SetVisible(false)
		self.ActiveTab.Active = false
	end
	self.ActiveTab = tab
	if tab then
		tab.Active = true
		tab:SetVisible(true)
		tab.Position = self.ContentOffset
	end
end

function Window:SetTitle(title)
	self.Title = title
	self.ConfigKey = string.format("window_%s", title)
end

function Window:Minimize()
	self.Minimized = not self.Minimized
end

function Window:Close()
	self:Destroy()
end

function Window:OnMouseDown(pos)
	if not self.Draggable or self.Minimized then return end
	local localPos = pos - self.AbsPos
	-- клик по кнопкам
	local closePos = Vector2.new(self.Size.X - 30, 5)
	local closeSize = Vector2.new(24, 20)
	local minPos = closePos - Vector2.new(26, 0)
	if localPos.X >= closePos.X and localPos.X <= closePos.X + closeSize.X and localPos.Y >= closePos.Y and localPos.Y <= closePos.Y + closeSize.Y then
		return
	end
	if localPos.X >= minPos.X and localPos.X <= minPos.X + closeSize.X and localPos.Y >= minPos.Y and localPos.Y <= minPos.Y + closeSize.Y then
		return
	end
	-- обработка ресайз-хендла
	if self.Resizable then
		local rp = self.Size - Vector2.new(12, 12)
		if localPos.X >= rp.X and localPos.X <= self.Size.X and localPos.Y >= rp.Y and localPos.Y <= self.Size.Y then
			self.Resizing = true
			self.ResizeStart = pos
			self.ResizeSizeStart = self.Size
			return
		end
	end
	-- тайтлбар
	if localPos.Y >= 0 and localPos.Y <= 30 then
		self.Dragging = true
		self.DragOffset = pos - self.AbsPos
	end
end

function Window:OnMouseUp(pos)
	self.Dragging = false
	self.Resizing = false
end

function Window:UpdateDrag()
	if self.Dragging then
		self.Position = self.UI.Input.MousePos - self.DragOffset
	end
	if self.Resizing then
		local delta = self.UI.Input.MousePos - self.ResizeStart
		self.Size = Vector2.new(
			math.max(self.MinSize.X, self.ResizeSizeStart.X + delta.X),
			math.max(self.MinSize.Y, self.ResizeSizeStart.Y + delta.Y)
		)
	end
end

function Window:GetConfig()
	local cfg = { Position = self.Position, Size = self.Size, Minimized = self.Minimized }
	if self.ActiveTab then
		cfg.ActiveTab = self.ActiveTab.Name
	end
	return cfg
end

function Window:SetConfig(cfg)
	if cfg.Position then self.Position = cfg.Position end
	if cfg.Size then self.Size = cfg.Size end
	if cfg.Minimized then self.Minimized = cfg.Minimized end
end

-- ===================== TAB =====================
local Tab = {}
Tab.__index = Tab
setmetatable(Tab, Element)

function Tab.new(ui, props)
	local self = Element.new(ui, {
		Parent = props.Parent,
		Position = props.Position or Vector2.new(0, 32),
		Size = props.Size or Vector2.new(80, 22),
		ZIndex = props.ZIndex or 20,
		Visible = true
	})
	setmetatable(self, Tab)
	self.Name = props.Name or "Tab"
	self.Active = false
	self.Sections = {}
	self.ButtonColor = ui.Theme.Element
	self:Create()
	return self
end

function Tab:Create()
	local ui = self.UI
	self.TabBtn = self:AddDrawing("Frame", {
		Color = ui.Theme.Element,
		Transparency = 0,
		Visible = true
	})
	self.TabText = self:AddDrawing("Text", {
		Text = self.Name,
		FontSize = 14,
		Color = ui.Theme.Text,
		Center = true
	})
	self.TabText.Outline = false
end

function Tab:Render()
	Tab.__index.Render(self)
	local ui = self.UI
	if self.TabBtn then
		self.TabBtn.Position = self.AbsPos
		self.TabBtn.Size = self.AbsSize
		self.TabBtn.Color = self.Active and ui.Accent or ui.Theme.Element
		self.TabBtn.Transparency = 1 - self.Alpha
	end
	if self.TabText then
		self.TabText.Position = self.AbsPos + Vector2.new(0, -1)
		self.TabText.Text = self.Name
		self.TabText.Size = 14
		self.TabText.Color = ui.Theme.Text
		self.TabText.Transparency = 1 - self.Alpha
	end
end

function Tab:OnClick(pos)
	if self.Parent and self.Parent.SetActiveTab then
		self.Parent:SetActiveTab(self)
	end
end

function Tab:CreateSection(name)
	local section = Section.new(self.UI, {
		Parent = self,
		Name = name,
		Position = Vector2.new(10, 5 + (#self.Sections * 1)),
		Size = Vector2.new(self.Parent.Size.X - 40, 20),
		ZIndex = self.ZIndex + 1
	})
	table.insert(self.Sections, section)
	self:Relayout()
	return section
end

function Tab:Relayout()
	local y = 5
	for _, section in ipairs(self.Sections) do
		section.Position = Vector2.new(10, y)
		y = y + section.Height + 10
	end
end

function Tab:UpdateTheme()
	for _, section in ipairs(self.Sections) do
		if section.UpdateTheme then
			section:UpdateTheme()
		end
	end
end

-- ===================== SECTION =====================
local Section = {}
Section.__index = Section
setmetatable(Section, Element)

function Section.new(ui, props)
	local self = Element.new(ui, {
		Parent = props.Parent,
		Position = props.Position or Vector2.new(10, 5),
		Size = Vector2.new(props.Size.X or 300, 20),
		ZIndex = props.ZIndex or 30,
		Visible = true
	})
	setmetatable(self, Section)
	self.Name = props.Name or "Section"
	self.Items = {}
	self.Height = 30
	self.ItemY = 28
	self:Create()
	return self
end

function Section:Create()
	local ui = self.UI
	self.SectionBg = self:AddDrawing("Frame", {
		Color = ui.Theme.Secondary,
		Transparency = 0,
		Visible = true
	})
	self.SectionLine = self:AddDrawing("Frame", {
		Color = ui.Accent,
		Transparency = 0,
		Visible = true
	})
	self.SectionText = self:AddDrawing("Text", {
		Text = self.Name,
		FontSize = 15,
		Color = ui.Theme.Text,
		Center = false
	})
	self.SectionText.Outline = false
end

function Section:Render()
	Section.__index.Render(self)
	local ui = self.UI
	local p = self.AbsPos
	local s = self.AbsSize
	if self.SectionBg then
		self.SectionBg.Position = p
		self.SectionBg.Size = Vector2.new(s.X, self.Height)
		self.SectionBg.Transparency = 1 - self.Alpha
	end
	if self.SectionLine then
		self.SectionLine.Position = p + Vector2.new(0, 0)
		self.SectionLine.Size = Vector2.new(2, self.Height)
		self.SectionLine.Transparency = 1 - self.Alpha
	end
	if self.SectionText then
		self.SectionText.Position = p + Vector2.new(10, 4)
		self.SectionText.Text = self.Name
		self.SectionText.Size = 15
		self.SectionText.Transparency = 1 - self.Alpha
	end
	-- позиционирование элементов
	local y = 26
	for _, item in ipairs(self.Items) do
		item.Position = Vector2.new(10, y)
		y = y + item.Height + 6
	end
	self.Height = math.max(y + 4, 30)
	self.Size = Vector2.new(self.Size.X, self.Height)
end

function Section:AddItem(item)
	table.insert(self.Items, item)
	self.Height = self.Height + item.Height + 6
	return item
end

function Section:UpdateTheme()
	local ui = self.UI
	if self.SectionBg then self.SectionBg.Color = ui.Theme.Secondary end
	if self.SectionLine then self.SectionLine.Color = ui.Accent end
	if self.SectionText then self.SectionText.Color = ui.Theme.Text end
	for _, item in ipairs(self.Items) do
		if item.UpdateTheme then
			item:UpdateTheme()
		end
	end
end

function Section:AddToggle(name, default, callback)
	local item = Toggle.new(self.UI, {
		Parent = self,
		Name = name,
		Value = default,
		Callback = callback,
		Position = Vector2.new(10, 26 + (#self.Items * 24)),
		Size = Vector2.new(self.Size.X - 20, 18),
		ZIndex = self.ZIndex + 1
	})
	return self:AddItem(item)
end

function Section:AddSlider(name, min, max, default, callback)
	local item = Slider.new(self.UI, {
		Parent = self,
		Name = name,
		Min = min,
		Max = max,
		Value = default or min,
		Callback = callback,
		Position = Vector2.new(10, 26 + (#self.Items * 24)),
		Size = Vector2.new(self.Size.X - 20, 26),
		ZIndex = self.ZIndex + 1
	})
	return self:AddItem(item)
end

function Section:AddButton(name, callback)
	local item = Button.new(self.UI, {
		Parent = self,
		Name = name,
		Callback = callback,
		Position = Vector2.new(10, 26 + (#self.Items * 24)),
		Size = Vector2.new(self.Size.X - 20, 22),
		ZIndex = self.ZIndex + 1
	})
	return self:AddItem(item)
end

function Section:AddDropdown(name, options, callback)
	local item = Dropdown.new(self.UI, {
		Parent = self,
		Name = name,
		Options = options,
		Callback = callback,
		Position = Vector2.new(10, 26 + (#self.Items * 24)),
		Size = Vector2.new(self.Size.X - 20, 22),
		ZIndex = self.ZIndex + 1
	})
	return self:AddItem(item)
end

function Section:AddLabel(text)
	local item = Label.new(self.UI, {
		Parent = self,
		Text = text,
		Position = Vector2.new(10, 26 + (#self.Items * 24)),
		Size = Vector2.new(self.Size.X - 20, 14),
		ZIndex = self.ZIndex + 1
	})
	return self:AddItem(item)
end

function Section:AddKeybind(name, defaultKey, callback)
	local item = Keybind.new(self.UI, {
		Parent = self,
		Name = name,
		Key = defaultKey,
		Callback = callback,
		Position = Vector2.new(10, 26 + (#self.Items * 24)),
		Size = Vector2.new(self.Size.X - 20, 18),
		ZIndex = self.ZIndex + 1
	})
	return self:AddItem(item)
end

function Section:AddColorPicker(name, defaultColor, callback)
	local item = ColorPicker.new(self.UI, {
		Parent = self,
		Name = name,
		Color = defaultColor or Color3.fromRGB(255,255,255),
		Callback = callback,
		Position = Vector2.new(10, 26 + (#self.Items * 24)),
		Size = Vector2.new(self.Size.X - 20, 22),
		ZIndex = self.ZIndex + 1
	})
	return self:AddItem(item)
end

-- ===================== TOGGLE =====================
local Toggle = {}
Toggle.__index = Toggle
setmetatable(Toggle, Element)

function Toggle.new(ui, props)
	local self = Element.new(ui, {
		Parent = props.Parent,
		Position = props.Position,
		Size = props.Size or Vector2.new(200, 18),
		ZIndex = props.ZIndex or 40,
		Visible = true
	})
	setmetatable(self, Toggle)
	self.Name = props.Name or ""
	self.Value = props.Value or false
	self.Callback = props.Callback
	self.Height = 18
	self:Create()
	return self
end

function Toggle:Create()
	local ui = self.UI
	self.LabelDraw = self:AddDrawing("Text", {
		Text = self.Name,
		FontSize = 14,
		Color = ui.Theme.Text,
		Center = false
	})
	self.LabelDraw.Outline = false
	self.Box = self:AddDrawing("Frame", {
		Color = ui.Theme.Element,
		Transparency = 0,
		Visible = true
	})
	self.Fill = self:AddDrawing("Frame", {
		Color = ui.Accent,
		Transparency = 0,
		Visible = true
	})
end

function Toggle:Render()
	Toggle.__index.Render(self)
	local ui = self.UI
	local p = self.AbsPos
	local boxX = p.X + self.Size.X - 34
	if self.LabelDraw then
		self.LabelDraw.Position = p
		self.LabelDraw.Text = self.Name
		self.LabelDraw.Size = 14
		self.LabelDraw.Transparency = 1 - self.Alpha
	end
	if self.Box then
		self.Box.Position = Vector2.new(boxX, p.Y)
		self.Box.Size = Vector2.new(32, 16)
		self.Box.Color = ui.Theme.Element
		self.Box.Transparency = 1 - self.Alpha
	end
	if self.Fill then
		self.Fill.Position = Vector2.new(boxX + (self.Value and 16 or 0), p.Y + 2)
		self.Fill.Size = Vector2.new(12, 12)
		self.Fill.Color = self.Value and ui.Accent or ui.Theme.Border
		self.Fill.Transparency = 1 - self.Alpha
	end
end

function Toggle:OnClick(pos)
	self.Value = not self.Value
	if self.Callback then
		self.Callback(self.Value)
	end
	self.UI:SaveConfig()
end

function Toggle:UpdateTheme()
	local ui = self.UI
	if self.LabelDraw then self.LabelDraw.Color = ui.Theme.Text end
	if self.Box then self.Box.Color = ui.Theme.Element end
end

-- ===================== SLIDER =====================
local Slider = {}
Slider.__index = Slider
setmetatable(Slider, Element)

function Slider.new(ui, props)
	local self = Element.new(ui, {
		Parent = props.Parent,
		Position = props.Position,
		Size = props.Size or Vector2.new(200, 26),
		ZIndex = props.ZIndex or 40,
		Visible = true
	})
	setmetatable(self, Slider)
	self.Name = props.Name or ""
	self.Min = props.Min or 0
	self.Max = props.Max or 100
	self.Value = props.Value or self.Min
	self.Callback = props.Callback
	self.Height = 26
	self.Dragging = false
	self:Create()
	return self
end

function Slider:Create()
	local ui = self.UI
	self.LabelDraw = self:AddDrawing("Text", {
		Text = self.Name,
		FontSize = 14,
		Color = ui.Theme.Text,
		Center = false
	})
	self.LabelDraw.Outline = false
	self.ValueDraw = self:AddDrawing("Text", {
		Text = tostring(self.Value),
		FontSize = 12,
		Color = ui.Theme.Subtext,
		Center = false
	})
	self.ValueDraw.Outline = false
	self.Bg = self:AddDrawing("Frame", {
		Color = ui.Theme.Element,
		Transparency = 0,
		Visible = true
	})
	self.Fill = self:AddDrawing("Frame", {
		Color = ui.Accent,
		Transparency = 0,
		Visible = true
	})
	self.Knob = self:AddDrawing("Frame", {
		Color = ui.Theme.Text,
		Transparency = 0,
		Visible = true
	})
end

function Slider:Render()
	Slider.__index.Render(self)
	local ui = self.UI
	local p = self.AbsPos
	local sliderX = p.X + self.Size.X - 100
	local sliderW = 80
	if self.LabelDraw then
		self.LabelDraw.Position = p
		self.LabelDraw.Text = self.Name
		self.LabelDraw.Size = 14
		self.LabelDraw.Transparency = 1 - self.Alpha
	end
	if self.ValueDraw then
		self.ValueDraw.Position = p + Vector2.new(self.Size.X - 20, 0)
		self.ValueDraw.Text = string.format("%.2f", self.Value)
		self.ValueDraw.Size = 12
		self.ValueDraw.Transparency = 1 - self.Alpha
	end
	local y = p.Y + 6
	if self.Bg then
		self.Bg.Position = Vector2.new(sliderX, y + 2)
		self.Bg.Size = Vector2.new(sliderW, 6)
		self.Bg.Color = ui.Theme.Element
		self.Bg.Transparency = 1 - self.Alpha
	end
	local ratio = clamp((self.Value - self.Min) / (self.Max - self.Min), 0, 1)
	if self.Fill then
		self.Fill.Position = Vector2.new(sliderX, y + 2)
		self.Fill.Size = Vector2.new(sliderW * ratio, 6)
		self.Fill.Color = ui.Accent
		self.Fill.Transparency = 1 - self.Alpha
	end
	if self.Knob then
		self.Knob.Position = Vector2.new(sliderX + sliderW * ratio - 4, y)
		self.Knob.Size = Vector2.new(8, 12)
		self.Knob.Color = ui.Theme.Text
		self.Knob.Transparency = 1 - self.Alpha
	end
end

function Slider:OnMouseDown(pos)
	self.Dragging = true
	self:UpdateValueFromMouse(pos.X)
end

function Slider:OnMouseUp(pos)
	self.Dragging = false
	self.UI:SaveConfig()
end

function Slider:UpdateValueFromMouse(mouseX)
	local p = self.AbsPos
	local sliderX = p.X + self.Size.X - 100
	local sliderW = 80
	local ratio = clamp((mouseX - sliderX) / sliderW, 0, 1)
	self.Value = self.Min + (self.Max - self.Min) * ratio
	self.Value = clamp(self.Value, self.Min, self.Max)
	if self.Callback then
		self.Callback(self.Value)
	end
end

function Slider:UpdateDrag()
	if self.Dragging then
		self:UpdateValueFromMouse(self.UI.Input.MousePos.X)
	end
end

function Slider:UpdateTheme()
	local ui = self.UI
	if self.LabelDraw then self.LabelDraw.Color = ui.Theme.Text end
	if self.ValueDraw then self.ValueDraw.Color = ui.Theme.Subtext end
	if self.Bg then self.Bg.Color = ui.Theme.Element end
end

-- ===================== BUTTON =====================
local Button = {}
Button.__index = Button
setmetatable(Button, Element)

function Button.new(ui, props)
	local self = Element.new(ui, {
		Parent = props.Parent,
		Position = props.Position,
		Size = props.Size or Vector2.new(200, 22),
		ZIndex = props.ZIndex or 40,
		Visible = true
	})
	setmetatable(self, Button)
	self.Name = props.Name or ""
	self.Callback = props.Callback
	self.Height = 22
	self:Create()
	return self
end

function Button:Create()
	local ui = self.UI
	self.Btn = self:AddDrawing("Frame", {
		Color = ui.Theme.Element,
		Transparency = 0,
		Visible = true
	})
	self.BtnText = self:AddDrawing("Text", {
		Text = self.Name,
		FontSize = 13,
		Color = ui.Theme.Text,
		Center = true
	})
	self.BtnText.Outline = false
end

function Button:Render()
	Button.__index.Render(self)
	local ui = self.UI
	if self.Btn then
		self.Btn.Position = self.AbsPos
		self.Btn.Size = self.AbsSize
		self.Btn.Color = self.Hovered and ui.AccentDark or ui.Theme.Element
		self.Btn.Transparency = 1 - self.Alpha
	end
	if self.BtnText then
		self.BtnText.Position = self.AbsPos + Vector2.new(0, -1)
		self.BtnText.Text = self.Name
		self.BtnText.Size = 13
		self.BtnText.Color = ui.Theme.Text
		self.BtnText.Transparency = 1 - self.Alpha
	end
end

function Button:OnClick(pos)
	if self.Callback then
		self.Callback()
	end
end

function Button:UpdateTheme()
	local ui = self.UI
	if self.Btn then self.Btn.Color = ui.Theme.Element end
	if self.BtnText then self.BtnText.Color = ui.Theme.Text end
end

-- ===================== LABEL =====================
local Label = {}
Label.__index = Label
setmetatable(Label, Element)

function Label.new(ui, props)
	local self = Element.new(ui, {
		Parent = props.Parent,
		Position = props.Position,
		Size = Vector2.new(props.Size.X or 200, 14),
		ZIndex = props.ZIndex or 40,
		Visible = true
	})
	setmetatable(self, Label)
	self.Text = props.Text or ""
	self.FontSize = props.FontSize or 13
	self.Color = props.Color
	self.Height = 14
	self:Create()
	return self
end

function Label:Create()
	local ui = self.UI
	self.LabelDraw = self:AddDrawing("Text", {
		Text = self.Text,
		FontSize = self.FontSize,
		Color = self.Color or ui.Theme.Subtext,
		Center = false
	})
	self.LabelDraw.Outline = false
end

function Label:Render()
	Label.__index.Render(self)
	local ui = self.UI
	if self.LabelDraw then
		self.LabelDraw.Position = self.AbsPos
		self.LabelDraw.Text = self.Text
		self.LabelDraw.Size = self.FontSize
		self.LabelDraw.Color = self.Color or ui.Theme.Subtext
		self.LabelDraw.Transparency = 1 - self.Alpha
	end
end

function Label:SetText(text)
	self.Text = text
end

function Label:UpdateTheme()
	local ui = self.UI
	if self.LabelDraw then
		self.LabelDraw.Color = self.Color or ui.Theme.Subtext
	end
end

-- ===================== DROPDOWN =====================
local Dropdown = {}
Dropdown.__index = Dropdown
setmetatable(Dropdown, Element)

function Dropdown.new(ui, props)
	local self = Element.new(ui, {
		Parent = props.Parent,
		Position = props.Position,
		Size = props.Size or Vector2.new(200, 22),
		ZIndex = props.ZIndex or 40,
		Visible = true
	})
	setmetatable(self, Dropdown)
	self.Name = props.Name or ""
	self.Options = props.Options or {}
	self.Value = self.Options[1] or ""
	self.Callback = props.Callback
	self.Height = 22
	self.Open = false
	self.ItemElements = {}
	self:Create()
	return self
end

function Dropdown:Create()
	local ui = self.UI
	self.LabelDraw = self:AddDrawing("Text", {
		Text = self.Name,
		FontSize = 14,
		Color = ui.Theme.Text,
		Center = false
	})
	self.LabelDraw.Outline = false
	self.Btn = self:AddDrawing("Frame", {
		Color = ui.Theme.Element,
		Transparency = 0,
		Visible = true
	})
	self.BtnText = self:AddDrawing("Text", {
		Text = self.Value,
		FontSize = 13,
		Color = ui.Theme.Text,
		Center = true
	})
	self.BtnText.Outline = false
end

function Dropdown:Render()
	Dropdown.__index.Render(self)
	local ui = self.UI
	local p = self.AbsPos
	local btnX = p.X + self.Size.X - 90
	if self.LabelDraw then
		self.LabelDraw.Position = p
		self.LabelDraw.Text = self.Name
		self.LabelDraw.Size = 14
		self.LabelDraw.Transparency = 1 - self.Alpha
	end
	if self.Btn then
		self.Btn.Position = Vector2.new(btnX, p.Y)
		self.Btn.Size = Vector2.new(90, 20)
		self.Btn.Color = ui.Theme.Element
		self.Btn.Transparency = 1 - self.Alpha
	end
	if self.BtnText then
		self.BtnText.Position = Vector2.new(btnX, p.Y - 1)
		self.BtnText.Text = self.Value
		self.BtnText.Size = 13
		self.BtnText.Color = ui.Theme.Text
		self.BtnText.Transparency = 1 - self.Alpha
	end
	-- рендер открытых элементов
	for i, item in ipairs(self.ItemElements) do
		if self.Open then
			item.Visible = true
			item.Position = Vector2.new(btnX, p.Y + i * 20)
			item.Size = Vector2.new(90, 20)
		else
			item.Visible = false
		end
	end
end

function Dropdown:OnClick(pos)
	self.Open = not self.Open
	if self.Open then
		self:BuildItems()
	end
end

function Dropdown:BuildItems()
	for _, item in ipairs(self.ItemElements) do
		item:Destroy()
	end
	self.ItemElements = {}
	for i, opt in ipairs(self.Options) do
		local item = DropdownItem.new(self.UI, {
			Parent = self,
			Dropdown = self,
			Option = opt,
			Index = i,
			Position = Vector2.new(self.Size.X - 90, 20 + i * 20),
			Size = Vector2.new(90, 20),
			ZIndex = self.ZIndex + 2
		})
		table.insert(self.ItemElements, item)
	end
end

function Dropdown:Select(option)
	self.Value = option
	self.Open = false
	if self.Callback then
		self.Callback(option)
	end
	self.UI:SaveConfig()
end

function Dropdown:UpdateTheme()
	local ui = self.UI
	if self.LabelDraw then self.LabelDraw.Color = ui.Theme.Text end
	if self.Btn then self.Btn.Color = ui.Theme.Element end
	if self.BtnText then self.BtnText.Color = ui.Theme.Text end
end

-- DropdownItem
local DropdownItem = {}
DropdownItem.__index = DropdownItem
setmetatable(DropdownItem, Element)

function DropdownItem.new(ui, props)
	local self = Element.new(ui, {
		Parent = props.Parent,
		Position = props.Position,
		Size = props.Size or Vector2.new(90, 20),
		ZIndex = props.ZIndex or 45,
		Visible = false
	})
	setmetatable(self, DropdownItem)
	self.Dropdown = props.Dropdown
	self.Option = props.Option
	self:Create()
	return self
end

function DropdownItem:Create()
	local ui = self.UI
	self.Bg = self:AddDrawing("Frame", {
		Color = ui.Theme.Secondary,
		Transparency = 0,
		Visible = true
	})
	self.Text = self:AddDrawing("Text", {
		Text = self.Option,
		FontSize = 12,
		Color = ui.Theme.Text,
		Center = true
	})
	self.Text.Outline = false
end

function DropdownItem:Render()
	DropdownItem.__index.Render(self)
	local ui = self.UI
	if self.Bg then
		self.Bg.Position = self.AbsPos
		self.Bg.Size = self.AbsSize
		self.Bg.Color = self.Hovered and ui.AccentDark or ui.Theme.Secondary
		self.Bg.Transparency = 1 - self.Alpha
	end
	if self.Text then
		self.Text.Position = self.AbsPos + Vector2.new(0, -1)
		self.Text.Text = self.Option
		self.Text.Size = 12
		self.Text.Color = ui.Theme.Text
		self.Text.Transparency = 1 - self.Alpha
	end
end

function DropdownItem:OnClick(pos)
	if self.Dropdown then
		self.Dropdown:Select(self.Option)
	end
end

-- ===================== KEYBIND =====================
local Keybind = {}
Keybind.__index = Keybind
setmetatable(Keybind, Element)

function Keybind.new(ui, props)
	local self = Element.new(ui, {
		Parent = props.Parent,
		Position = props.Position,
		Size = props.Size or Vector2.new(200, 18),
		ZIndex = props.ZIndex or 40,
		Visible = true
	})
	setmetatable(self, Keybind)
	self.Name = props.Name or ""
	self.Key = props.Key or Enum.KeyCode.F
	self.Callback = props.Callback
	self.Height = 18
	self.Binding = false
	self:Create()
	return self
end

function Keybind:Create()
	local ui = self.UI
	self.LabelDraw = self:AddDrawing("Text", {
		Text = self.Name,
		FontSize = 14,
		Color = ui.Theme.Text,
		Center = false
	})
	self.LabelDraw.Outline = false
	self.BindBtn = self:AddDrawing("Frame", {
		Color = ui.Theme.Element,
		Transparency = 0,
		Visible = true
	})
	self.BindText = self:AddDrawing("Text", {
		Text = tostring(self.Key),
		FontSize = 12,
		Color = ui.Theme.Text,
		Center = true
	})
	self.BindText.Outline = false
end

function Keybind:Render()
	Keybind.__index.Render(self)
	local ui = self.UI
	local p = self.AbsPos
	local bx = p.X + self.Size.X - 80
	if self.LabelDraw then
		self.LabelDraw.Position = p
		self.LabelDraw.Text = self.Name
		self.LabelDraw.Size = 14
		self.LabelDraw.Transparency = 1 - self.Alpha
	end
	if self.BindBtn then
		self.BindBtn.Position = Vector2.new(bx, p.Y)
		self.BindBtn.Size = Vector2.new(80, 16)
		self.BindBtn.Color = self.Binding and ui.Accent or ui.Theme.Element
		self.BindBtn.Transparency = 1 - self.Alpha
	end
	if self.BindText then
		self.BindText.Position = Vector2.new(bx, p.Y - 1)
		self.BindText.Text = self.Binding and "..." or tostring(self.Key)
		self.BindText.Size = 12
		self.BindText.Color = ui.Theme.Text
		self.BindText.Transparency = 1 - self.Alpha
	end
end

function Keybind:OnClick(pos)
	self.Binding = true
	self.UI.Input:BeginKeybind(self)
end

function Keybind:SetKey(key)
	self.Key = key
	self.Binding = false
	self.UI:SaveConfig()
end

function Keybind:UpdateTheme()
	local ui = self.UI
	if self.LabelDraw then self.LabelDraw.Color = ui.Theme.Text end
	if self.BindBtn then self.BindBtn.Color = ui.Theme.Element end
	if self.BindText then self.BindText.Color = ui.Theme.Text end
end

-- ===================== COLORPICKER =====================
local ColorPicker = {}
ColorPicker.__index = ColorPicker
setmetatable(ColorPicker, Element)

function ColorPicker.new(ui, props)
	local self = Element.new(ui, {
		Parent = props.Parent,
		Position = props.Position,
		Size = props.Size or Vector2.new(200, 22),
		ZIndex = props.ZIndex or 40,
		Visible = true
	})
	setmetatable(self, ColorPicker)
	self.Name = props.Name or ""
	self.Color = props.Color or Color3.fromRGB(255,255,255)
	self.Callback = props.Callback
	self.Height = 22
	self.Open = false
	self.Popup = nil
	self:Create()
	return self
end

function ColorPicker:Create()
	local ui = self.UI
	self.LabelDraw = self:AddDrawing("Text", {
		Text = self.Name,
		FontSize = 14,
		Color = ui.Theme.Text,
		Center = false
	})
	self.LabelDraw.Outline = false
	self.Preview = self:AddDrawing("Frame", {
		Color = self.Color,
		Transparency = 0,
		Visible = true
	})
	self.PreviewText = self:AddDrawing("Text", {
		Text = ColorToHex(self.Color),
		FontSize = 11,
		Color = ui.Theme.Text,
		Center = true
	})
	self.PreviewText.Outline = false
end

function ColorPicker:Render()
	ColorPicker.__index.Render(self)
	local ui = self.UI
	local p = self.AbsPos
	local px = p.X + self.Size.X - 110
	if self.LabelDraw then
		self.LabelDraw.Position = p
		self.LabelDraw.Text = self.Name
		self.LabelDraw.Size = 14
		self.LabelDraw.Transparency = 1 - self.Alpha
	end
	if self.Preview then
		self.Preview.Position = Vector2.new(px, p.Y)
		self.Preview.Size = Vector2.new(70, 18)
		self.Preview.Color = self.Color
		self.Preview.Transparency = 1 - self.Alpha
	end
	if self.PreviewText then
		self.PreviewText.Position = Vector2.new(px, p.Y - 1)
		self.PreviewText.Text = ColorToHex(self.Color)
		self.PreviewText.Size = 11
		self.PreviewText.Transparency = 1 - self.Alpha
	end
	if self.Open and self.Popup then
		self.Popup.Visible = true
		self.Popup.Position = self.AbsPos + Vector2.new(self.Size.X - 110, 20)
	elseif self.Popup then
		self.Popup.Visible = false
	end
end

function ColorPicker:OnClick(pos)
	self.Open = not self.Open
	if self.Open then
		self:BuildPopup()
	end
end

function ColorPicker:BuildPopup()
	if self.Popup then
		self.Popup:Destroy()
		self.Popup = nil
	end
	local ui = self.UI
	local popup = ColorPickerPopup.new(ui, {
		Parent = self,
		Picker = self,
		Position = Vector2.new(self.Size.X - 110, 20),
		Size = Vector2.new(110, 80),
		ZIndex = self.ZIndex + 3
	})
	self.Popup = popup
end

function ColorPicker:SetColor(color)
	self.Color = color
	if self.Callback then
		self.Callback(color)
	end
	self.UI:SaveConfig()
end

function ColorPicker:UpdateTheme()
	local ui = self.UI
	if self.LabelDraw then self.LabelDraw.Color = ui.Theme.Text end
	if self.PreviewText then self.PreviewText.Color = ui.Theme.Text end
end

-- ColorPickerPopup
local ColorPickerPopup = {}
ColorPickerPopup.__index = ColorPickerPopup
setmetatable(ColorPickerPopup, Element)

function ColorPickerPopup.new(ui, props)
	local self = Element.new(ui, {
		Parent = props.Parent,
		Position = props.Position,
		Size = props.Size or Vector2.new(110, 80),
		ZIndex = props.ZIndex or 50,
		Visible = true
	})
	setmetatable(self, ColorPickerPopup)
	self.Picker = props.Picker
	self:Create()
	return self
end

function ColorPickerPopup:Create()
	local ui = self.UI
	self.Bg = self:AddDrawing("Frame", {
		Color = ui.Theme.Secondary,
		Transparency = 0,
		Visible = true
	})
	local baseColor = self.Picker.Color
	self.SliderR = PopupSlider.new(ui, {
		Parent = self,
		Min = 0,
		Max = 255,
		Value = round(baseColor.R * 255),
		Label = "R",
		Position = Vector2.new(5, 5),
		Size = Vector2.new(100, 20),
		ZIndex = self.ZIndex + 1,
		OnChange = function(v)
			local c = self.Picker.Color
			self.Picker:SetColor(Color3.fromRGB(v, round(c.G * 255), round(c.B * 255)))
		end
	})
	self.SliderG = PopupSlider.new(ui, {
		Parent = self,
		Min = 0,
		Max = 255,
		Value = round(baseColor.G * 255),
		Label = "G",
		Position = Vector2.new(5, 30),
		Size = Vector2.new(100, 20),
		ZIndex = self.ZIndex + 1,
		OnChange = function(v)
			local c = self.Picker.Color
			self.Picker:SetColor(Color3.fromRGB(round(c.R * 255), v, round(c.B * 255)))
		end
	})
	self.SliderB = PopupSlider.new(ui, {
		Parent = self,
		Min = 0,
		Max = 255,
		Value = round(baseColor.B * 255),
		Label = "B",
		Position = Vector2.new(5, 55),
		Size = Vector2.new(100, 20),
		ZIndex = self.ZIndex + 1,
		OnChange = function(v)
			local c = self.Picker.Color
			self.Picker:SetColor(Color3.fromRGB(round(c.R * 255), round(c.G * 255), v))
		end
	})
end

function ColorPickerPopup:Render()
	ColorPickerPopup.__index.Render(self)
	local ui = self.UI
	if self.Bg then
		self.Bg.Position = self.AbsPos
		self.Bg.Size = self.AbsSize
		self.Bg.Color = ui.Theme.Secondary
		self.Bg.Transparency = 1 - self.Alpha
	end
end

-- PopupSlider (мини-слайдер для RGB)
local PopupSlider = {}
PopupSlider.__index = PopupSlider
setmetatable(PopupSlider, Element)

function PopupSlider.new(ui, props)
	local self = Element.new(ui, {
		Parent = props.Parent,
		Position = props.Position,
		Size = props.Size or Vector2.new(100, 20),
		ZIndex = props.ZIndex or 51,
		Visible = true
	})
	setmetatable(self, PopupSlider)
	self.Min = props.Min or 0
	self.Max = props.Max or 255
	self.Value = props.Value or 0
	self.Label = props.Label or ""
	self.OnChange = props.OnChange
	self.Dragging = false
	self:Create()
	return self
end

function PopupSlider:Create()
	local ui = self.UI
	self.LabelDraw = self:AddDrawing("Text", {
		Text = self.Label,
		FontSize = 10,
		Color = ui.Theme.Subtext,
		Center = false
	})
	self.LabelDraw.Outline = false
	self.Bg = self:AddDrawing("Frame", {
		Color = ui.Theme.Element,
		Transparency = 0,
		Visible = true
	})
	self.Fill = self:AddDrawing("Frame", {
		Color = ui.Accent,
		Transparency = 0,
		Visible = true
	})
	self.Knob = self:AddDrawing("Frame", {
		Color = ui.Theme.Text,
		Transparency = 0,
		Visible = true
	})
end

function PopupSlider:Render()
	PopupSlider.__index.Render(self)
	local ui = self.UI
	local p = self.AbsPos
	if self.LabelDraw then
		self.LabelDraw.Position = p
		self.LabelDraw.Text = self.Label
		self.LabelDraw.Size = 10
		self.LabelDraw.Transparency = 1 - self.Alpha
	end
	local sx = p.X + 15
	local sw = self.Size.X - 25
	if self.Bg then
		self.Bg.Position = Vector2.new(sx, p.Y + 3)
		self.Bg.Size = Vector2.new(sw, 4)
		self.Bg.Color = ui.Theme.Element
		self.Bg.Transparency = 1 - self.Alpha
	end
	local ratio = clamp((self.Value - self.Min) / (self.Max - self.Min), 0, 1)
	if self.Fill then
		self.Fill.Position = Vector2.new(sx, p.Y + 3)
		self.Fill.Size = Vector2.new(sw * ratio, 4)
		self.Fill.Color = ui.Accent
		self.Fill.Transparency = 1 - self.Alpha
	end
	if self.Knob then
		self.Knob.Position = Vector2.new(sx + sw * ratio - 3, p.Y + 1)
		self.Knob.Size = Vector2.new(6, 8)
		self.Knob.Color = ui.Theme.Text
		self.Knob.Transparency = 1 - self.Alpha
	end
end

function PopupSlider:OnMouseDown(pos)
	self.Dragging = true
	self:UpdateValueFromMouse(pos.X)
end

function PopupSlider:OnMouseUp(pos)
	self.Dragging = false
end

function PopupSlider:UpdateValueFromMouse(mouseX)
	local p = self.AbsPos
	local sx = p.X + 15
	local sw = self.Size.X - 25
	local ratio = clamp((mouseX - sx) / sw, 0, 1)
	self.Value = self.Min + (self.Max - self.Min) * ratio
	self.Value = clamp(self.Value, self.Min, self.Max)
	if self.OnChange then
		self.OnChange(self.Value)
	end
end

function PopupSlider:UpdateDrag()
	if self.Dragging then
		self:UpdateValueFromMouse(self.UI.Input.MousePos.X)
	end
end

-- ===================== TEXTBOX =====================
local Textbox = {}
Textbox.__index = Textbox
setmetatable(Textbox, Element)

function Textbox.new(ui, props)
	local self = Element.new(ui, {
		Parent = props.Parent,
		Position = props.Position,
		Size = props.Size or Vector2.new(200, 22),
		ZIndex = props.ZIndex or 40,
		Visible = true
	})
	setmetatable(self, Textbox)
	self.Name = props.Name or ""
	self.Value = props.Value or ""
	self.Placeholder = props.Placeholder or ""
	self.Callback = props.Callback
	self.Height = 22
	self.Focused = false
	self:Create()
	return self
end

function Textbox:Create()
	local ui = self.UI
	self.LabelDraw = self:AddDrawing("Text", {
		Text = self.Name,
		FontSize = 14,
		Color = ui.Theme.Text,
		Center = false
	})
	self.LabelDraw.Outline = false
	self.Box = self:AddDrawing("Frame", {
		Color = ui.Theme.Element,
		Transparency = 0,
		Visible = true
	})
	self.ValueDraw = self:AddDrawing("Text", {
		Text = self.Value or self.Placeholder,
		FontSize = 13,
		Color = ui.Theme.Text,
		Center = false
	})
	self.ValueDraw.Outline = false
end

function Textbox:Render()
	Textbox.__index.Render(self)
	local ui = self.UI
	local p = self.AbsPos
	local bx = p.X + self.Size.X - 100
	if self.LabelDraw then
		self.LabelDraw.Position = p
		self.LabelDraw.Text = self.Name
		self.LabelDraw.Size = 14
		self.LabelDraw.Transparency = 1 - self.Alpha
	end
	if self.Box then
		self.Box.Position = Vector2.new(bx, p.Y)
		self.Box.Size = Vector2.new(100, 20)
		self.Box.Color = self.Focused and ui.AccentDark or ui.Theme.Element
		self.Box.Transparency = 1 - self.Alpha
	end
	if self.ValueDraw then
		local display = self.Value
		if display == "" then display = self.Placeholder end
		self.ValueDraw.Position = Vector2.new(bx + 5, p.Y + 2)
		self.ValueDraw.Text = display .. (self.Focused and "|" or "")
		self.ValueDraw.Size = 13
		self.ValueDraw.Color = self.Value == "" and ui.Theme.Subtext or ui.Theme.Text
		self.ValueDraw.Transparency = 1 - self.Alpha
	end
end

function Textbox:OnClick(pos)
	self.Focused = true
	self.UI.Input:SetFocused(self)
end

function Textbox:SetFocused(v)
	self.Focused = v
end

function Textbox:TypeKey(keyCode)
	if keyCode == Enum.KeyCode.Backspace then
		self.Value = self.Value:sub(1, -2)
	elseif keyCode == Enum.KeyCode.Return then
		self.Focused = false
		if self.Callback then
			self.Callback(self.Value)
		end
		self.UI:SaveConfig()
	else
		local name = keyCode.Name
		if #name == 1 and name:match("%a") then
			self.Value = self.Value .. name
		elseif name == "Space" then
			self.Value = self.Value .. " "
		elseif name == "One" then self.Value = self.Value .. "1"
		elseif name == "Two" then self.Value = self.Value .. "2"
		elseif name == "Three" then self.Value = self.Value .. "3"
		elseif name == "Four" then self.Value = self.Value .. "4"
		elseif name == "Five" then self.Value = self.Value .. "5"
		elseif name == "Six" then self.Value = self.Value .. "6"
		elseif name == "Seven" then self.Value = self.Value .. "7"
		elseif name == "Eight" then self.Value = self.Value .. "8"
		elseif name == "Nine" then self.Value = self.Value .. "9"
		elseif name == "Zero" then self.Value = self.Value .. "0"
		end
	end
end

function Textbox:UpdateTheme()
	local ui = self.UI
	if self.LabelDraw then self.LabelDraw.Color = ui.Theme.Text end
	if self.Box then self.Box.Color = ui.Theme.Element end
end

-- ===================== ЭКСПОРТ =====================
function AuroraUI.new(config)
	return UI.new(config)
end

function AuroraUI:SetTheme(name, accent)
	-- вызывается на экземпляре
end

function AuroraUI.CreateWindow(ui, title, props)
	return ui:CreateWindow(title, props)
end

if getgenv then
	getgenv().AuroraUI = AuroraUI
end

return AuroraUI
