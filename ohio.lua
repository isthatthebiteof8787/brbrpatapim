--[[
	AuroraUI Components v1.2
	Компоненты. Загружается ВТОРЫМ через loadstring, после AuroraUI_core.lua.
	Определяет Window, Tab, Section и все элементы интерфейса.
]]

local Core = getgenv and getgenv().AuroraCore
if not Core then error("[AuroraUI] Ядро не загружено. Сначала запустите AuroraUI_core.lua", 2) end

local Element = Core.Element
local UI = Core.UI
local Themes = Core.Themes
local Utils = Core.Utils
local clamp = Utils.clamp

-- ===== Window =====
local Window = {} Window.__index = Window setmetatable(Window, Element)
function Window.new(ui, p)
	local s = Element.new(ui, { Position = p.Position or Vector2.new(100,100),
		Size = p.Size or Vector2.new(480,320), ZIndex = p.ZIndex or 10 })
	setmetatable(s, Window)
	s.Title = p.Title or "Window"; s.Tabs = {}; s.ActiveTab = nil
	s.Draggable = p.Draggable ~= false; s.Resizable = p.Resizable ~= false
	s.Dragging = false; s.Resizing = false; s.DragOffset = Vector2.new()
	s.Minimized = false; s.MinSize = Vector2.new(200,150)
	s.ConfigKey = "window_" .. s.Title; s.ContentOffset = Vector2.new(10,45)
	s:Create(); s:UpdateTheme(); return s
end
function Window:Create()
	local th = self.UI.Theme
	self.Bg = self:AddDrawing("Frame", { Color = th.Background, Transparency = 0.05 })
	self.TitleBar = self:AddDrawing("Frame", { Color = th.Secondary })
	self.TitleText = self:AddDrawing("Text", { Text = self.Title, FontSize = 16, Color = th.Text })
	self.CloseBtn = self:AddDrawing("Frame", { Color = th.Danger })
	self.CloseText = self:AddDrawing("Text", { Text = "X", FontSize = 14, Color = Color3.new(1,1,1), Center = true })
	self.MinBtn = self:AddDrawing("Frame", { Color = th.Element })
	self.MinText = self:AddDrawing("Text", { Text = "—", FontSize = 14, Color = th.Text, Center = true })
	if self.Resizable then self.ResizeHandle = self:AddDrawing("Frame", { Color = th.Accent, Transparency = 0.3 }) end
end
function Window:UpdateTheme()
	local th = self.UI.Theme
	self.Bg.Color = th.Background; self.TitleBar.Color = th.Secondary
	self.TitleText.Color = th.Text; self.CloseBtn.Color = th.Danger
	self.MinBtn.Color = th.Element; self.MinText.Color = th.Text
end
function Window:Render()
	Window.__index.Render(self)
	local p, sz = self.AbsPos, self.AbsSize
	self.Bg.Position = p self.Bg.Size = sz self.Bg.Transparency = 0.05 * (1 - self.Alpha)
	self.TitleBar.Position = p self.TitleBar.Size = Vector2.new(sz.X, 30) self.TitleBar.Transparency = 1 - self.Alpha
	self.TitleText.Position = p + Vector2.new(10, 6) self.TitleText.Transparency = 1 - self.Alpha
	local cp = p + Vector2.new(sz.X - 30, 5); local cs = Vector2.new(24, 20)
	self.CloseBtn.Position = cp self.CloseBtn.Size = cs self.CloseBtn.Transparency = 1 - self.Alpha
	self.CloseText.Position = cp + Vector2.new(0, -1) self.CloseText.Transparency = 1 - self.Alpha
	local mp = cp - Vector2.new(26, 0)
	self.MinBtn.Position = mp self.MinBtn.Size = cs self.MinBtn.Transparency = 1 - self.Alpha
	self.MinText.Position = mp + Vector2.new(0, -1) self.MinText.Transparency = 1 - self.Alpha
	if self.ResizeHandle then
		self.ResizeHandle.Position = p + sz - Vector2.new(12, 12)
		self.ResizeHandle.Size = Vector2.new(12, 12) self.ResizeHandle.Transparency = 0.3 * (1 - self.Alpha)
	end
	local tx = 10
	for _, t in ipairs(self.Tabs) do
		t.Position = Vector2.new(tx, 32) tx = tx + 90
		t.ButtonColor = t.Active and self.UI.Accent or self.UI.Theme.Element
	end
	if self.ActiveTab and not self.Minimized then
		self.ActiveTab:SetVisible(true) self.ActiveTab.Position = self.ContentOffset
	elseif self.ActiveTab and self.Minimized then
		self.ActiveTab:SetVisible(false)
	end
end
function Window:CreateTab(name)
	local t = Tab.new(self.UI, { Parent = self, Name = name,
		Position = Vector2.new(10 + #self.Tabs * 90, 32), Size = Vector2.new(80, 22),
		ZIndex = self.ZIndex + 1 })
	table.insert(self.Tabs, t)
	if #self.Tabs == 1 then self:SetActiveTab(t) end
	return t
end
function Window:SetActiveTab(t)
	if self.ActiveTab then self.ActiveTab:SetVisible(false) self.ActiveTab.Active = false end
	self.ActiveTab = t
	if t then t.Active = true t:SetVisible(true) t.Position = self.ContentOffset end
end
function Window:SetTitle(t) self.Title = t self.ConfigKey = "window_" .. t end
function Window:Minimize() self.Minimized = not self.Minimized end
function Window:Close() self:Destroy() end
function Window:OnMouseDown(pos)
	if not self.Draggable or self.Minimized then return end
	local lp = pos - self.AbsPos
	if lp.X >= self.Size.X - 30 and lp.Y >= 5 and lp.Y <= 25 then return end
	if lp.X >= self.Size.X - 56 and lp.X <= self.Size.X - 32 and lp.Y >= 5 and lp.Y <= 25 then return end
	if self.Resizable and lp.X >= self.Size.X - 12 and lp.Y >= self.Size.Y - 12 then
		self.Resizing = true self.ResizeStart = pos self.ResizeSizeStart = self.Size return
	end
	if lp.Y <= 30 then self.Dragging = true self.DragOffset = pos - self.AbsPos end
end
function Window:OnMouseUp() self.Dragging = false self.Resizing = false end
function Window:UpdateDrag()
	if self.Dragging then self.Position = self.UI.Input.MousePos - self.DragOffset end
	if self.Resizing then
		local d = self.UI.Input.MousePos - self.ResizeStart
		self.Size = Vector2.new(math.max(self.MinSize.X, self.ResizeSizeStart.X + d.X),
			math.max(self.MinSize.Y, self.ResizeSizeStart.Y + d.Y))
	end
end
function Window:GetConfig()
	return { Position = self.Position, Size = self.Size, Minimized = self.Minimized,
		ActiveTab = self.ActiveTab and self.ActiveTab.Name or nil }
end
function Window:SetConfig(c)
	if c.Position then self.Position = c.Position end
	if c.Size then self.Size = c.Size end
	if c.Minimized then self.Minimized = c.Minimized end
end

-- ===== Tab =====
local Tab = {} Tab.__index = Tab setmetatable(Tab, Element)
function Tab.new(ui, p)
	local s = Element.new(ui, { Parent = p.Parent, Position = p.Position or Vector2.new(0,32),
		Size = p.Size or Vector2.new(80,22), ZIndex = p.ZIndex or 20 })
	setmetatable(s, Tab)
	s.Name = p.Name or "Tab"; s.Active = false; s.Sections = {}
	s.ButtonColor = ui.Theme.Element
	s:Create(); return s
end
function Tab:Create()
	self.TabBtn = self:AddDrawing("Frame", { Color = self.UI.Theme.Element })
	self.TabText = self:AddDrawing("Text", { Text = self.Name, FontSize = 14, Color = self.UI.Theme.Text, Center = true })
end
function Tab:Render()
	Tab.__index.Render(self)
	self.TabBtn.Position = self.AbsPos self.TabBtn.Size = self.AbsSize
	self.TabBtn.Color = self.Active and self.UI.Accent or self.UI.Theme.Element
	self.TabBtn.Transparency = 1 - self.Alpha
	self.TabText.Position = self.AbsPos + Vector2.new(0, -1)
	self.TabText.Transparency = 1 - self.Alpha
end
function Tab:OnClick() if self.Parent.SetActiveTab then self.Parent:SetActiveTab(self) end end
function Tab:CreateSection(name)
	local sec = Section.new(self.UI, { Parent = self, Name = name,
		Position = Vector2.new(10, 5 + #self.Sections), Size = Vector2.new(self.Parent.Size.X - 40, 20),
		ZIndex = self.ZIndex + 1 })
	table.insert(self.Sections, sec) self:Relayout() return sec
end
function Tab:Relayout()
	local y = 5
	for _, s in ipairs(self.Sections) do s.Position = Vector2.new(10, y) y = y + s.Height + 10 end
end
function Tab:UpdateTheme() for _, s in ipairs(self.Sections) do if s.UpdateTheme then s:UpdateTheme() end end end

-- ===== Section =====
local Section = {} Section.__index = Section setmetatable(Section, Element)
function Section.new(ui, p)
	local s = Element.new(ui, { Parent = p.Parent, Position = p.Position or Vector2.new(10,5),
		Size = Vector2.new(p.Size.X or 300, 20), ZIndex = p.ZIndex or 30 })
	setmetatable(s, Section)
	s.Name = p.Name or "Section"; s.Items = {}; s.Height = 30
	s:Create(); return s
end
function Section:Create()
	self.Bg = self:AddDrawing("Frame", { Color = self.UI.Theme.Secondary })
	self.Line = self:AddDrawing("Frame", { Color = self.UI.Accent })
	self.Text = self:AddDrawing("Text", { Text = self.Name, FontSize = 15, Color = self.UI.Theme.Text })
end
function Section:Render()
	Section.__index.Render(self)
	self.Bg.Position = self.AbsPos self.Bg.Size = Vector2.new(self.AbsSize.X, self.Height)
	self.Bg.Transparency = 1 - self.Alpha
	self.Line.Position = self.AbsPos self.Line.Size = Vector2.new(2, self.Height)
	self.Line.Transparency = 1 - self.Alpha
	self.Text.Position = self.AbsPos + Vector2.new(10, 4)
	self.Text.Transparency = 1 - self.Alpha
	local y = 26
	for _, item in ipairs(self.Items) do item.Position = Vector2.new(10, y) y = y + item.Height + 6 end
	self.Height = math.max(y + 4, 30)
end
function Section:AddItem(i) table.insert(self.Items, i) self.Height = self.Height + i.Height + 6 return i end
function Section:UpdateTheme()
	self.Bg.Color = self.UI.Theme.Secondary self.Line.Color = self.UI.Accent
	self.Text.Color = self.UI.Theme.Text
	for _, i in ipairs(self.Items) do if i.UpdateTheme then i:UpdateTheme() end end
end
function Section:AddToggle(n, d, cb)
	return self:AddItem(Toggle.new(self.UI, { Parent = self, Name = n, Value = d, Callback = cb,
		Position = Vector2.new(10, 26 + #self.Items * 24), Size = Vector2.new(self.Size.X - 20, 18), ZIndex = self.ZIndex + 1 }))
end
function Section:AddSlider(n, mn, mx, d, cb)
	return self:AddItem(Slider.new(self.UI, { Parent = self, Name = n, Min = mn, Max = mx, Value = d or mn, Callback = cb,
		Position = Vector2.new(10, 26 + #self.Items * 24), Size = Vector2.new(self.Size.X - 20, 26), ZIndex = self.ZIndex + 1 }))
end
function Section:AddButton(n, cb)
	return self:AddItem(Button.new(self.UI, { Parent = self, Name = n, Callback = cb,
		Position = Vector2.new(10, 26 + #self.Items * 24), Size = Vector2.new(self.Size.X - 20, 22), ZIndex = self.ZIndex + 1 }))
end
function Section:AddDropdown(n, opts, cb)
	return self:AddItem(Dropdown.new(self.UI, { Parent = self, Name = n, Options = opts, Callback = cb,
		Position = Vector2.new(10, 26 + #self.Items * 24), Size = Vector2.new(self.Size.X - 20, 22), ZIndex = self.ZIndex + 1 }))
end
function Section:AddLabel(t)
	return self:AddItem(Label.new(self.UI, { Parent = self, Text = t,
		Position = Vector2.new(10, 26 + #self.Items * 24), Size = Vector2.new(self.Size.X - 20, 14), ZIndex = self.ZIndex + 1 }))
end
function Section:AddKeybind(n, k, cb)
	return self:AddItem(Keybind.new(self.UI, { Parent = self, Name = n, Key = k, Callback = cb,
		Position = Vector2.new(10, 26 + #self.Items * 24), Size = Vector2.new(self.Size.X - 20, 18), ZIndex = self.ZIndex + 1 }))
end
function Section:AddColorPicker(n, c, cb)
	return self:AddItem(ColorPicker.new(self.UI, { Parent = self, Name = n, Color = c or Color3.new(1,1,1), Callback = cb,
		Position = Vector2.new(10, 26 + #self.Items * 24), Size = Vector2.new(self.Size.X - 20, 22), ZIndex = self.ZIndex + 1 }))
end

-- ===== Toggle =====
local Toggle = {} Toggle.__index = Toggle setmetatable(Toggle, Element)
function Toggle.new(ui, p)
	local s = Element.new(ui, { Parent = p.Parent, Position = p.Position, Size = p.Size or Vector2.new(200,18), ZIndex = p.ZIndex or 40 })
	setmetatable(s, Toggle)
	s.Name = p.Name or ""; s.Value = p.Value or false; s.Callback = p.Callback; s.Height = 18
	s:Create(); return s
end
function Toggle:Create()
	self.Label = self:AddDrawing("Text", { Text = self.Name, FontSize = 14, Color = self.UI.Theme.Text })
	self.Box = self:AddDrawing("Frame", { Color = self.UI.Theme.Element })
	self.Fill = self:AddDrawing("Frame", { Color = self.UI.Accent })
end
function Toggle:Render()
	Toggle.__index.Render(self)
	self.Label.Position = self.AbsPos self.Label.Transparency = 1 - self.Alpha
	local bx = self.AbsPos.X + self.Size.X - 34
	self.Box.Position = Vector2.new(bx, self.AbsPos.Y) self.Box.Size = Vector2.new(32, 16)
	self.Box.Transparency = 1 - self.Alpha
	self.Fill.Position = Vector2.new(bx + (self.Value and 16 or 0), self.AbsPos.Y + 2)
	self.Fill.Size = Vector2.new(12, 12)
	self.Fill.Color = self.Value and self.UI.Accent or self.UI.Theme.Border
	self.Fill.Transparency = 1 - self.Alpha
end
function Toggle:OnClick()
	self.Value = not self.Value
	if self.Callback then self.Callback(self.Value) end
	self.UI:SaveConfig()
end
function Toggle:UpdateTheme() self.Label.Color = self.UI.Theme.Text self.Box.Color = self.UI.Theme.Element end

-- ===== Slider =====
local Slider = {} Slider.__index = Slider setmetatable(Slider, Element)
function Slider.new(ui, p)
	local s = Element.new(ui, { Parent = p.Parent, Position = p.Position, Size = p.Size or Vector2.new(200,26), ZIndex = p.ZIndex or 40 })
	setmetatable(s, Slider)
	s.Name = p.Name or ""; s.Min = p.Min or 0; s.Max = p.Max or 100
	s.Value = p.Value or s.Min; s.Callback = p.Callback; s.Height = 26; s.Dragging = false
	s:Create(); return s
end
function Slider:Create()
	self.Label = self:AddDrawing("Text", { Text = self.Name, FontSize = 14, Color = self.UI.Theme.Text })
	self.Val = self:AddDrawing("Text", { Text = tostring(self.Value), FontSize = 12, Color = self.UI.Theme.Subtext })
	self.Bg = self:AddDrawing("Frame", { Color = self.UI.Theme.Element })
	self.Fill = self:AddDrawing("Frame", { Color = self.UI.Accent })
	self.Knob = self:AddDrawing("Frame", { Color = self.UI.Theme.Text })
end
function Slider:Render()
	Slider.__index.Render(self)
	self.Label.Position = self.AbsPos self.Label.Transparency = 1 - self.Alpha
	self.Val.Position = self.AbsPos + Vector2.new(self.Size.X - 20, 0)
	self.Val.Text = string.format("%.1f", self.Value) self.Val.Transparency = 1 - self.Alpha
	local sx = self.AbsPos.X + self.Size.X - 100 local sw = 80 local y = self.AbsPos.Y + 6
	self.Bg.Position = Vector2.new(sx, y + 2) self.Bg.Size = Vector2.new(sw, 6) self.Bg.Transparency = 1 - self.Alpha
	local r = clamp((self.Value - self.Min) / (self.Max - self.Min), 0, 1)
	self.Fill.Position = Vector2.new(sx, y + 2) self.Fill.Size = Vector2.new(sw * r, 6) self.Fill.Transparency = 1 - self.Alpha
	self.Knob.Position = Vector2.new(sx + sw * r - 4, y) self.Knob.Size = Vector2.new(8, 12) self.Knob.Transparency = 1 - self.Alpha
end
function Slider:OnMouseDown(pos) self.Dragging = true self:UpdateValue(pos.X) end
function Slider:OnMouseUp() self.Dragging = false self.UI:SaveConfig() end
function Slider:UpdateValue(mx)
	local sx = self.AbsPos.X + self.Size.X - 100 local sw = 80
	local r = clamp((mx - sx) / sw, 0, 1)
	self.Value = self.Min + (self.Max - self.Min) * r
	if self.Callback then self.Callback(self.Value) end
end
function Slider:UpdateDrag() if self.Dragging then self:UpdateValue(self.UI.Input.MousePos.X) end end
function Slider:UpdateTheme()
	self.Label.Color = self.UI.Theme.Text self.Val.Color = self.UI.Theme.Subtext
	self.Bg.Color = self.UI.Theme.Element
end

-- ===== Button =====
local Button = {} Button.__index = Button setmetatable(Button, Element)
function Button.new(ui, p)
	local s = Element.new(ui, { Parent = p.Parent, Position = p.Position, Size = p.Size or Vector2.new(200,22), ZIndex = p.ZIndex or 40 })
	setmetatable(s, Button)
	s.Name = p.Name or ""; s.Callback = p.Callback; s.Height = 22
	s:Create(); return s
end
function Button:Create()
	self.Bg = self:AddDrawing("Frame", { Color = self.UI.Theme.Element })
	self.Text = self:AddDrawing("Text", { Text = self.Name, FontSize = 13, Color = self.UI.Theme.Text, Center = true })
end
function Button:Render()
	Button.__index.Render(self)
	self.Bg.Position = self.AbsPos self.Bg.Size = self.AbsSize
	self.Bg.Color = self.Hovered and self.UI.AccentDark or self.UI.Theme.Element
	self.Bg.Transparency = 1 - self.Alpha
	self.Text.Position = self.AbsPos + Vector2.new(0, -1) self.Text.Transparency = 1 - self.Alpha
end
function Button:OnClick() if self.Callback then self.Callback() end end
function Button:UpdateTheme() self.Bg.Color = self.UI.Theme.Element self.Text.Color = self.UI.Theme.Text end

-- ===== Label =====
local Label = {} Label.__index = Label setmetatable(Label, Element)
function Label.new(ui, p)
	local s = Element.new(ui, { Parent = p.Parent, Position = p.Position, Size = Vector2.new(p.Size.X or 200, 14), ZIndex = p.ZIndex or 40 })
	setmetatable(s, Label)
	s.Text = p.Text or ""; s.FontSize = p.FontSize or 13; s.Color = p.Color; s.Height = 14
	s:Create(); return s
end
function Label:Create()
	self.L = self:AddDrawing("Text", { Text = self.Text, FontSize = self.FontSize,
		Color = self.Color or self.UI.Theme.Subtext })
end
function Label:Render()
	Label.__index.Render(self)
	self.L.Position = self.AbsPos self.L.Text = self.Text self.L.Size = self.FontSize
	self.L.Color = self.Color or self.UI.Theme.Subtext self.L.Transparency = 1 - self.Alpha
end
function Label:SetText(t) self.Text = t end
function Label:UpdateTheme() self.L.Color = self.Color or self.UI.Theme.Subtext end

-- ===== Dropdown =====
local Dropdown = {} Dropdown.__index = Dropdown setmetatable(Dropdown, Element)
function Dropdown.new(ui, p)
	local s = Element.new(ui, { Parent = p.Parent, Position = p.Position, Size = p.Size or Vector2.new(200,22), ZIndex = p.ZIndex or 40 })
	setmetatable(s, Dropdown)
	s.Name = p.Name or ""; s.Options = p.Options or {}; s.Value = s.Options[1] or ""
	s.Callback = p.Callback; s.Height = 22; s.Open = false; s.ItemElements = {}
	s:Create(); return s
end
function Dropdown:Create()
	self.Label = self:AddDrawing("Text", { Text = self.Name, FontSize = 14, Color = self.UI.Theme.Text })
	self.Btn = self:AddDrawing("Frame", { Color = self.UI.Theme.Element })
	self.BtnText = self:AddDrawing("Text", { Text = self.Value, FontSize = 13, Color = self.UI.Theme.Text, Center = true })
end
function Dropdown:Render()
	Dropdown.__index.Render(self)
	self.Label.Position = self.AbsPos self.Label.Transparency = 1 - self.Alpha
	local bx = self.AbsPos.X + self.Size.X - 90
	self.Btn.Position = Vector2.new(bx, self.AbsPos.Y) self.Btn.Size = Vector2.new(90, 20) self.Btn.Transparency = 1 - self.Alpha
	self.BtnText.Position = Vector2.new(bx, self.A
	self.BtnText.Position = Vector2.new(bx, self.AbsPos.Y - 1) self.BtnText.Text = self.Value self.BtnText.Transparency = 1 - self.Alpha
	for i, item in ipairs(self.ItemElements) do
		if self.Open then item.Visible = true item.Position = Vector2.new(bx, self.AbsPos.Y + i * 20) item.Size = Vector2.new(90, 20)
		else item.Visible = false end
	end
end
function Dropdown:OnClick() self.Open = not self.Open if self.Open then self:BuildItems() end end
function Dropdown:BuildItems()
	for _, i in ipairs(self.ItemElements) do i:Destroy() end
	self.ItemElements = {}
	for i, opt in ipairs(self.Options) do
		table.insert(self.ItemElements, DropdownItem.new(self.UI, { Parent = self, Dropdown = self, Option = opt,
			Position = Vector2.new(self.Size.X - 90, 20 + i * 20), Size = Vector2.new(90, 20), ZIndex = self.ZIndex + 2 }))
	end
end
function Dropdown:Select(opt)
	self.Value = opt self.Open = false
	if self.Callback then self.Callback(opt) end
	self.UI:SaveConfig()
end
function Dropdown:UpdateTheme()
	self.Label.Color = self.UI.Theme.Text self.Btn.Color = self.UI.Theme.Element
	self.BtnText.Color = self.UI.Theme.Text
end

local DropdownItem = {} DropdownItem.__index = DropdownItem setmetatable(DropdownItem, Element)
function DropdownItem.new(ui, p)
	local s = Element.new(ui, { Parent = p.Parent, Position = p.Position, Size = p.Size or Vector2.new(90,20), ZIndex = p.ZIndex or 45, Visible = false })
	setmetatable(s, DropdownItem)
	s.Dropdown = p.Dropdown; s.Option = p.Option
	s:Create(); return s
end
function DropdownItem:Create()
	self.Bg = self:AddDrawing("Frame", { Color = self.UI.Theme.Secondary })
	self.Text = self:AddDrawing("Text", { Text = self.Option, FontSize = 12, Color = self.UI.Theme.Text, Center = true })
end
function DropdownItem:Render()
	DropdownItem.__index.Render(self)
	self.Bg.Position = self.AbsPos self.Bg.Size = self.AbsSize
	self.Bg.Color = self.Hovered and self.UI.AccentDark or self.UI.Theme.Secondary
	self.Bg.Transparency = 1 - self.Alpha
	self.Text.Position = self.AbsPos + Vector2.new(0, -1) self.Text.Transparency = 1 - self.Alpha
end
function DropdownItem:OnClick() if self.Dropdown then self.Dropdown:Select(self.Option) end end

local Keybind = {} Keybind.__index = Keybind setmetatable(Keybind, Element)
function Keybind.new(ui, p)
	local s = Element.new(ui, { Parent = p.Parent, Position = p.Position, Size = p.Size or Vector2.new(200,18), ZIndex = p.ZIndex or 40 })
	setmetatable(s, Keybind)
	s.Name = p.Name or ""; s.Key = p.Key or Enum.KeyCode.F; s.Callback = p.Callback
	s.Height = 18; s.Binding = false
	s:Create(); return s
end
function Keybind:Create()
	self.Label = self:AddDrawing("Text", { Text = self.Name, FontSize = 14, Color = self.UI.Theme.Text })
	self.Btn = self:AddDrawing("Frame", { Color = self.UI.Theme.Element })
	self.BtnText = self:AddDrawing("Text", { Text = tostring(self.Key), FontSize = 12, Color = self.UI.Theme.Text, Center = true })
end
function Keybind:Render()
	Keybind.__index.Render(self)
	self.Label.Position = self.AbsPos self.Label.Transparency = 1 - self.Alpha
	local bx = self.AbsPos.X + self.Size.X - 80
	self.Btn.Position = Vector2.new(bx, self.AbsPos.Y) self.Btn.Size = Vector2.new(80, 16)
	self.Btn.Color = self.Binding and self.UI.Accent or self.UI.Theme.Element
	self.Btn.Transparency = 1 - self.Alpha
	self.BtnText.Position = Vector2.new(bx, self.AbsPos.Y - 1)
	self.BtnText.Text = self.Binding and "..." or tostring(self.Key)
	self.BtnText.Transparency = 1 - self.Alpha
end
function Keybind:OnClick() self.Binding = true self.UI.Input:BeginKeybind(self) end
function Keybind:SetKey(k) self.Key = k self.Binding = false self.UI:SaveConfig() end
function Keybind:UpdateTheme()
	self.Label.Color = self.UI.Theme.Text self.Btn.Color = self.UI.Theme.Element
	self.BtnText.Color = self.UI.Theme.Text
end

local ColorPicker = {} ColorPicker.__index = ColorPicker setmetatable(ColorPicker, Element)
function ColorPicker.new(ui, p)
	local s = Element.new(ui, { Parent = p.Parent, Position = p.Position, Size = p.Size or Vector2.new(200,22), ZIndex = p.ZIndex or 40 })
	setmetatable(s, ColorPicker)
	s.Name = p.Name or ""; s.Color = p.Color or Color3.new(1,1,1)
	s.Callback = p.Callback; s.Height = 22; s.Open = false; s.Popup = nil
	s:Create(); return s
end
function ColorPicker:Create()
	self.Label = self:AddDrawing("Text", { Text = self.Name, FontSize = 14, Color = self.UI.Theme.Text })
	self.Preview = self:AddDrawing("Frame", { Color = self.Color })
	self.PrevText = self:AddDrawing("Text", { Text = Utils.hex(self.Color), FontSize = 11, Color = self.UI.Theme.Text, Center = true })
end
function ColorPicker:Render()
	ColorPicker.__index.Render(self)
	self.Label.Position = self.AbsPos self.Label.Transparency = 1 - self.Alpha
	local px = self.AbsPos.X + self.Size.X - 110
	self.Preview.Position = Vector2.new(px, self.AbsPos.Y) self.Preview.Size = Vector2.new(70, 18)
	self.Preview.Color = self.Color self.Preview.Transparency = 1 - self.Alpha
	self.PrevText.Position = Vector2.new(px, self.AbsPos.Y - 1) self.PrevText.Text = Utils.hex(self.Color)
	self.PrevText.Transparency = 1 - self.Alpha
	if self.Open and self.Popup then self.Popup.Visible = true self.Popup.Position = self.AbsPos + Vector2.new(self.Size.X - 110, 20)
	elseif self.Popup then self.Popup.Visible = false end
end
function ColorPicker:OnClick() self.Open = not self.Open if self.Open then self:BuildPopup() end end
function ColorPicker:BuildPopup()
	if self.Popup then self.Popup:Destroy() self.Popup = nil end
	self.Popup = ColorPickerPopup.new(self.UI, { Parent = self, Picker = self,
		Position = Vector2.new(self.Size.X - 110, 20), Size = Vector2.new(110, 80), ZIndex = self.ZIndex + 3 })
end
function ColorPicker:SetColor(c) self.Color = c if self.Callback then self.Callback(c) end self.UI:SaveConfig() end
function ColorPicker:UpdateTheme() self.Label.Color = self.UI.Theme.Text self.PrevText.Color = self.UI.Theme.Text end

local ColorPickerPopup = {} ColorPickerPopup.__index = ColorPickerPopup setmetatable(ColorPickerPopup, Element)
function ColorPickerPopup.new(ui, p)
	local s = Element.new(ui, { Parent = p.Parent, Position = p.Position, Size = p.Size or Vector2.new(110,80), ZIndex = p.ZIndex or 50 })
	setmetatable(s, ColorPickerPopup)
	s.Picker = p.Picker
	s:Create(); return s
end
function ColorPickerPopup:Create()
	local ui, pc = self.UI, self.Picker
	self.Bg = self:AddDrawing("Frame", { Color = ui.Theme.Secondary })
	self.SliderR = PopupSlider.new(ui, { Parent = self, Min = 0, Max = 255, Value = Utils.round(pc.Color.R * 255), Label = "R", Position = Vector2.new(5, 5), Size = Vector2.new(100, 20), ZIndex = self.ZIndex + 1,
		OnChange = function(v) pc:SetColor(Color3.fromRGB(v, Utils.round(pc.Color.G * 255), Utils.round(pc.Color.B * 255))) end })
	self.SliderG = PopupSlider.new(ui, { Parent = self, Min = 0, Max = 255, Value = Utils.round(pc.Color.G * 255), Label = "G", Position = Vector2.new(5, 30), Size = Vector2.new(100, 20), ZIndex = self.ZIndex + 1,
		OnChange = function(v) pc:SetColor(Color3.fromRGB(Utils.round(pc.Color.R * 255), v, Utils.round(pc.Color.B * 255))) end })
	self.SliderB = PopupSlider.new(ui, { Parent = self, Min = 0, Max = 255, Value = Utils.round(pc.Color.B * 255), Label = "B", Position = Vector2.new(5, 55), Size = Vector2.new(100, 20), ZIndex = self.ZIndex + 1,
		OnChange = function(v) pc:SetColor(Color3.fromRGB(Utils.round(pc.Color.R * 255), Utils.round(pc.Color.G * 255), v)) end })
end
function ColorPickerPopup:Render()
	ColorPickerPopup.__index.Render(self)
	self.Bg.Position = self.AbsPos self.Bg.Size = self.AbsSize self.Bg.Transparency = 1 - self.Alpha
end

local PopupSlider = {} PopupSlider.__index = PopupSlider setmetatable(PopupSlider, Element)
function PopupSlider.new(ui, p)
	local s = Element.new(ui, { Parent = p.Parent, Position = p.Position, Size = p.Size or Vector2.new(100,20), ZIndex = p.ZIndex or 51 })
	setmetatable(s, PopupSlider)
	s.Min = p.Min or 0; s.Max = p.Max or 255; s.Value = p.Value or 0
	s.Label = p.Label or ""; s.OnChange = p.OnChange; s.Dragging = false
	s:Create(); return s
end
function PopupSlider:Create()
	self.L = self:AddDrawing("Text", { Text = self.Label, FontSize = 10, Color = self.UI.Theme.Subtext })
	self.Bg = self:AddDrawing("Frame", { Color = self.UI.Theme.Element })
	self.Fill = self:AddDrawing("Frame", { Color = self.UI.Accent })
	self.Knob = self:AddDrawing("Frame", { Color = self.UI.Theme.Text })
end
function PopupSlider:Render()
	PopupSlider.__index.Render(self)
	self.L.Position = self.AbsPos self.L.Transparency = 1 - self.Alpha
	local sx = self.AbsPos.X + 15 local sw = self.Size.X - 25
	self.Bg.Position = Vector2.new(sx, self.AbsPos.Y + 3) self.Bg.Size = Vector2.new(sw, 4) self.Bg.Transparency = 1 - self.Alpha
	local r = clamp((self.Value - self.Min) / (self.Max - self.Min), 0, 1)
	self.Fill.Position = Vector2.new(sx, self.AbsPos.Y + 3) self.Fill.Size = Vector2.new(sw * r, 4) self.Fill.Transparency = 1 - self.Alpha
	self.Knob.Position = Vector2.new(sx + sw * r - 3, self.AbsPos.Y + 1) self.Knob.Size = Vector2.new(6, 8) self.Knob.Transparency = 1 - self.Alpha
end
function PopupSlider:OnMouseDown(pos) self.Dragging = true self:UpdateValue(pos.X) end
function PopupSlider:OnMouseUp() self.Dragging = false end
function PopupSlider:UpdateValue(mx)
	local sx = self.AbsPos.X + 15 local sw = self.Size.X - 25
	local r = clamp((mx - sx) / sw, 0, 1)
	self.Value = self.Min + (self.Max - self.Min) * r
	if self.OnChange then self.OnChange(self.Value) end
end
function PopupSlider:UpdateDrag() if self.Dragging then self:UpdateValue(self.UI.Input.MousePos.X) end end

local Textbox = {} Textbox.__index = Textbox setmetatable(Textbox, Element)
function Textbox.new(ui, p)
	local s = Element.new(ui, { Parent = p.Parent, Position = p.Position, Size = p.Size or Vector2.new(200,22), ZIndex = p.ZIndex or 40 })
	setmetatable(s, Textbox)
	s.Name = p.Name or ""; s.Value = p.Value or ""; s.Placeholder = p.Placeholder or ""
	s.Callback = p.Callback; s.Height = 22; s.Focused = false
	s:Create(); return s
end
function Textbox:Create()
	self.Label = self:AddDrawing("Text", { Text = self.Name, FontSize = 14, Color = self.UI.Theme.Text })
	self.Box = self:AddDrawing("Frame", { Color = self.UI.Theme.Element })
	self.Text = self:AddDrawing("Text", { Text = self.Value ~= "" and self.Value or self.Placeholder, FontSize = 13, Color = self.UI.Theme.Text })
end
function Textbox:Render()
	Textbox.__index.Render(self)
	self.Label.Position = self.AbsPos self.Label.Transparency = 1 - self.Alpha
	local bx = self.AbsPos.X + self.Size.X - 100
	self.Box.Position = Vector2.new(bx, self.AbsPos.Y) self.Box.Size = Vector2.new(100, 20)
	self.Box.Color = self.Focused and self.UI.AccentDark or self.UI.Theme.Element
	self.Box.Transparency = 1 - self.Alpha
	local disp = self.Value ~= "" and self.Value or self.Placeholder
	self.Text.Position = Vector2.new(bx + 5, self.AbsPos.Y + 2)
	self.Text.Text = disp .. (self.Focused and "|" or "")
	self.Text.Color = self.Value == "" and self.UI.Theme.Subtext or self.UI.Theme.Text
	self.Text.Transparency = 1 - self.Alpha
end
function Textbox:OnClick() self.Focused = true self.UI.Input:SetFocused(self) end
function Textbox:SetFocused(v) self.Focused = v end
function Textbox:TypeKey(kc)
	if kc == Enum.KeyCode.Backspace then self.Value = self.Value:sub(1, -2)
	elseif kc == Enum.KeyCode.Return then self.Focused = false if self.Callback then self.Callback(self.Value) end self.UI:SaveConfig()
	else
		local n = kc.Name
		if #n == 1 and n:match("%a") then self.Value = self.Value .. n
		elseif n == "Space" then self.Value = self.Value .. " "
		elseif n == "One" then self.Value = self.Value .. "1"
		elseif n == "Two" then self.Value = self.Value .. "2"
		elseif n == "Three" then self.Value = self.Value .. "3"
		elseif n == "Four" then self.Value = self.Value .. "4"
		elseif n == "Five" then self.Value = self.Value .. "5"
		elseif n == "Six" then self.Value = self.Value .. "6"
		elseif n == "Seven" then self.Value = self.Value .. "7"
		elseif n == "Eight" then self.Value = self.Value .. "8"
		elseif n == "Nine" then self.Value = self.Value .. "9"
		elseif n == "Zero" then self.Value = self.Value .. "0" end
	end
end
function Textbox:UpdateTheme() self.Label.Color = self.UI.Theme.Text self.Box.Color = self.UI.Theme.Element end

Core:RegisterComponent("Window", Window)
Core:RegisterComponent("Tab", Tab)
Core:RegisterComponent("Section", Section)
Core:RegisterComponent("Toggle", Toggle)
Core:RegisterComponent("Slider", Slider)
Core:RegisterComponent("Button", Button)
Core:RegisterComponent("Label", Label)
Core:RegisterComponent("Dropdown", Dropdown)
Core:RegisterComponent("Keybind", Keybind)
Core:RegisterComponent("ColorPicker", ColorPicker)
Core:RegisterComponent("Textbox", Textbox)

return Core
