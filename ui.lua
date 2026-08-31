--[[
    AetherUI — Modern UI Library for Roblox Script GUIs
    Self-contained, Instance-based, Tween-animated.

    Usage:
        local AetherUI = loadstring(game:HttpGet("URL/AetherUI.lua"))()
        local Window = AetherUI:CreateWindow({ Title = "My Script" })
]]

-- ================= Services =================
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local CoreGui          = game:GetService("CoreGui")
local LocalPlayer      = Players.LocalPlayer

-- ================= Utilities =================
local Utils = {}

function Utils.New(class, parent, props)
    local inst = Instance.new(class)
    if parent then
        inst.Parent = parent
    end
    for k, v in pairs(props or {}) do
        inst[k] = v
    end
    return inst
end

function Utils.Tween(inst, duration, props, easingStyle, easingDirection)
    local info = TweenInfo.new(
        duration or 0.2,
        easingStyle or Enum.EasingStyle.Quad,
        easingDirection or Enum.EasingDirection.Out,
        0, false, 0
    )
    local tween = TweenService:Create(inst, info, props)
    tween:Play()
    return tween
end

function Utils.Clamp(v, min, max)
    return math.max(min, math.min(max, v))
end

function Utils.Round(v, decimals)
    local m = 10 ^ (decimals or 1)
    return math.floor(v * m + 0.5) / m
end

-- HSV <-> RGB
function Utils.HSVtoRGB(h, s, v)
    h = (h % 1) * 6
    local i = math.floor(h)
    local f = h - i
    local p = v * (1 - s)
    local q = v * (1 - s * f)
    local t = v * (1 - s * (1 - f))
    local r, g, b
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    else r, g, b = v, p, q end
    return r, g, b
end

function Utils.RGBtoHSV(r, g, b)
    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local d = max - min
    local h
    if d == 0 then
        h = 0
    elseif max == r then
        h = ((g - b) / d) % 6
    elseif max == g then
        h = (b - r) / d + 2
    else
        h = (r - g) / d + 4
    end
    h = h / 6
    local s = (max == 0) and 0 or (d / max)
    return h, s, max
end

-- ================= Themes =================
local Themes = {}

Themes.Dark = {
    Accent    = Color3.fromRGB(89, 132, 255),
    WindowBG  = Color3.fromRGB(22, 22, 26),
    SidebarBG = Color3.fromRGB(18, 18, 22),
    ContentBG = Color3.fromRGB(25, 25, 31),
    SectionBG = Color3.fromRGB(30, 30, 37),
    ElementBG = Color3.fromRGB(36, 36, 44),
    Hover     = Color3.fromRGB(44, 44, 54),
    Text      = Color3.fromRGB(235, 235, 242),
    Subtext   = Color3.fromRGB(148, 148, 158),
    Stroke    = Color3.fromRGB(46, 46, 54),
}

Themes.Light = {
    Accent    = Color3.fromRGB(70, 110, 245),
    WindowBG  = Color3.fromRGB(245, 245, 248),
    SidebarBG = Color3.fromRGB(235, 235, 240),
    ContentBG = Color3.fromRGB(250, 250, 252),
    SectionBG = Color3.fromRGB(255, 255, 255),
    ElementBG = Color3.fromRGB(232, 232, 238),
    Hover     = Color3.fromRGB(220, 220, 228),
    Text      = Color3.fromRGB(25, 25, 32),
    Subtext   = Color3.fromRGB(110, 110, 120),
    Stroke    = Color3.fromRGB(210, 210, 220),
}

-- ================= Library =================
local AetherUI = {}

local function MakeElement(window, setter, getter)
    local el = {
        _win    = window,
        _set    = setter or function() end,
        _get    = getter or function() return nil end,
        _cb     = nil,
        _flag   = nil,
    }
    function el:Set(value) self:_set(value) return self end
    function el:Get() return self:_get() end
    function el:Bind(callback) self._cb = callback return self end
    function el:SetFlag(name)
        self._flag = name
        local saved = window.Flags[name]
        if saved ~= nil then
            self:_set(saved)
        end
        window._Elements[name] = self
        return self
    end
    el._fire = function(value)
        if el._flag then
            window.Flags[el._flag] = value
        end
        if el._cb then
            pcall(el._cb, value)
        end
    end
    return el
end

function AetherUI:CreateWindow(config)
    config = config or {}
    local title    = config.Title or "AetherUI"
    local subtitle = config.Subtitle or ""

    -- Theme resolution
    local themeKey = config.Theme or "Dark"
    local theme = (type(themeKey) == "table") and themeKey or Themes[themeKey] or Themes.Dark
    if config.Accent then
        theme = {}
        for k, v in pairs(Themes[themeKey] or Themes.Dark) do theme[k] = v end
        theme.Accent = config.Accent
    end

    -- Window object
    local window = {
        Title        = title,
        Theme        = theme,
        Tabs         = {},
        Flags        = {},
        _Elements    = {},
        _CurrentTab  = nil,
    }

    -- Root GUI
    local holder = config.Parent or CoreGui
    local gui = Utils.New("ScreenGui", holder, {
        Name = "AetherUI_" .. title,
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })

    -- Main window frame
    local winSize = config.Size or UDim2.fromOffset(600, 450)
    local win = Utils.New("Frame", gui, {
        Name = "Window",
        Size = winSize,
        BackgroundColor3 = theme.WindowBG,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    })

    if config.Center then
        win.AnchorPoint = Vector2.new(0.5, 0.5)
        win.Position = UDim2.new(0.5, 0, 0.5, 0)
    else
        win.Position = config.Position or UDim2.new(0.5, -300, 0.5, -225)
    end

    Utils.New("UICorner", win, { CornerRadius = UDim.new(0, 10) })
    Utils.New("UIStroke", win, { Color = theme.Stroke, Thickness = 1 })
    Utils.New("UIStroke", win, { Color = Color3.fromRGB(0, 0, 0), Thickness = 1, Transparency = 0.85 })

    local gradient = Utils.New("UIGradient", win, {
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, theme.WindowBG),
            ColorSequenceKeypoint.new(1, theme.WindowBG:Lerp(Color3.new(0, 0, 0), 0.25)),
        }),
    })

    -- ---- Title bar ----
    local titleBar = Utils.New("Frame", win, {
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    local accentBar = Utils.New("Frame", titleBar, {
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 0, 30),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 3,
    })
    Utils.New("UICorner", accentBar, { CornerRadius = UDim.new(0, 10) })

    Utils.New("TextLabel", titleBar, {
        Text = title,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(0, 200, 1, 0),
        BackgroundTransparency = 1,
        TextColor3 = theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
    })

    if subtitle ~= "" then
        Utils.New("TextLabel", titleBar, {
            Text = subtitle,
            Position = UDim2.new(0, 215, 0, 0),
            Size = UDim2.new(0, 180, 1, 0),
            BackgroundTransparency = 1,
            TextColor3 = theme.Subtext,
            TextXAlignment = Enum.TextXAlignment.Left,
            Font = Enum.Font.Gotham,
            TextSize = 12,
        })
    end

    -- Close button
    local closeBtn = Utils.New("TextButton", titleBar, {
        Text = "✕",
        Size = UDim2.fromOffset(26, 20),
        Position = UDim2.new(1, -32, 0, 6),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
        TextColor3 = theme.Subtext,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
    })
    closeBtn.MouseEnter:Connect(function() closeBtn.TextColor3 = Color3.fromRGB(255, 90, 90) end)
    closeBtn.MouseLeave:Connect(function() closeBtn.TextColor3 = theme.Subtext end)
    closeBtn.MouseButton1Click:Connect(function()
        window:Destroy()
    end)

    -- Minimize button
    local miniBtn = Utils.New("TextButton", titleBar, {
        Text = "—",
        Size = UDim2.fromOffset(26, 20),
        Position = UDim2.new(1, -62, 0, 6),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
        TextColor3 = theme.Subtext,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
    })
    local minimized = false
    local miniOrigSize = win.Size
    miniBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            miniBtn.Text = "+"
            Utils.Tween(win, 0.25, { Size = UDim2.new(miniOrigSize.X.Scale, miniOrigSize.X.Offset, 0, 32) })
        else
            miniBtn.Text = "—"
            Utils.Tween(win, 0.25, { Size = miniOrigSize })
        end
    end)

    -- ---- Dragging ----
    local dragging, dragStart, winStart = false, nil, nil
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            winStart = win.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local dx = input.Position.X - dragStart.X
            local dy = input.Position.Y - dragStart.Y
            win.Position = UDim2.new(winStart.X.Scale, winStart.X.Offset + dx, winStart.Y.Scale, winStart.Y.Offset + dy)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    -- ---- Layout ----
    local main = Utils.New("Frame", win, {
        Size = UDim2.new(1, 0, 1, -32),
        Position = UDim2.new(0, 0, 0, 32),
        BackgroundColor3 = theme.ContentBG,
        BorderSizePixel = 0,
    })

    local sidebar = Utils.New("Frame", main, {
        Size = UDim2.new(0, 150, 1, 0),
        BackgroundColor3 = theme.SidebarBG,
        BorderSizePixel = 0,
    })
    Utils.New("UIStroke", sidebar, { Color = theme.Stroke, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })

    local tabList = Utils.New("Frame", sidebar, {
        Size = UDim2.new(1, -10, 1, -16),
        Position = UDim2.new(0, 5, 0, 8),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    local tabListLayout = Utils.New("UIListLayout", tabList, {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
    })

    local content = Utils.New("Frame", main, {
        Size = UDim2.new(1, -150, 1, 0),
        Position = UDim2.new(0, 150, 0, 0),
        BackgroundColor3 = theme.ContentBG,
        BorderSizePixel = 0,
    })

    -- ---- Notifications ----
    local notifHolder = Utils.New("Frame", gui, {
        Size = UDim2.fromOffset(270, 0),
        Position = UDim2.new(1, -290, 0, 10),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 20,
    })
    local notifList = Utils.New("UIListLayout", notifHolder, {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        VerticalAlignment = Enum.VerticalAlignment.Top,
    })

    function window:Notify(nTitle, nText, duration)
        duration = duration or 3
        local card = Utils.New("Frame", notifHolder, {
            Size = UDim2.new(1, -20, 0, 62),
            Position = UDim2.new(0, 10, 0, 0),
            BackgroundColor3 = theme.WindowBG,
            BorderSizePixel = 0,
            ZIndex = 20,
            LayoutOrder = 1,
            BackgroundTransparency = 1,
        })
        local accent = Utils.New("Frame", card, {
            Size = UDim2.new(0, 3, 1, 0),
            BackgroundColor3 = theme.Accent,
            BorderSizePixel = 0,
            ZIndex = 21,
        })
        Utils.New("UICorner", accent, { CornerRadius = UDim.new(1, 0) })
        Utils.New("UICorner", card, { CornerRadius = UDim.new(0, 8) })
        Utils.New("UIStroke", card, { Color = theme.Stroke, Thickness = 1, ZIndex = 21 })

        Utils.New("TextLabel", card, {
            Text = nTitle,
            Position = UDim2.new(0, 12, 0, 8),
            Size = UDim2.new(1, -24, 0, 18),
            BackgroundTransparency = 1,
            TextColor3 = theme.Text,
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 21,
        })
        Utils.New("TextLabel", card, {
            Text = nText,
            Position = UDim2.new(0, 12, 0, 28),
            Size = UDim2.new(1, -24, 0, 28),
            BackgroundTransparency = 1,
            TextColor3 = theme.Subtext,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            ZIndex = 21,
        })

        -- Slide in
        card.Position = UDim2.new(1, 0, 0, 0)
        Utils.Tween(card, 0.3, { Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 0 })

        task.delay(duration, function()
            pcall(function()
                Utils.Tween(card, 0.3, { BackgroundTransparency = 1 })
                Utils.Tween(card, 0.3, { Position = UDim2.new(1, 0, 0, 0) })
                task.wait(0.35)
                card:Destroy()
            end)
        end)
    end

    -- ---- Scrolling content ----
    local scroll = Utils.New("ScrollingFrame", content, {
        Size = UDim2.new(1, -20, 1, -20),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = theme.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
    })

    local scrollLayout = Utils.New("UIListLayout", scroll, {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 12),
    })

    -- ================= Tab =================
    local Tab = {}
    Tab.__index = Tab

    function Tab.new(winObj, name, order)
        local self = setmetatable({ Window = winObj, Name = name, Sections = {} }, Tab)
        self._order = order

        self.Button = Utils.New("TextButton", tabList, {
            Text = name,
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 1,
            TextColor3 = winObj.Theme.Subtext,
            Font = Enum.Font.GothamMedium,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = order,
        })
        local pad = Utils.New("UIPadding", self.Button, { PaddingLeft = UDim.new(0, 14) })
        self.Accent = Utils.New("Frame", self.Button, {
            Size = UDim2.new(0, 3, 0, 16),
            Position = UDim2.new(0, 4, 0.5, -8),
            BackgroundColor3 = winObj.Theme.Accent,
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
        })
        Utils.New("UICorner", self.Accent, { CornerRadius = UDim.new(1, 0) })
        Utils.New("UICorner", self.Button, { CornerRadius = UDim.new(0, 7) })

        self.Container = Utils.New("Frame", scroll, {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Visible = false,
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = order,
        })
        self.Layout = Utils.New("UIListLayout", self.Container, {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 12),
        })

        self.Button.MouseButton1Click:Connect(function()
            winObj:_SelectTab(self)
        end)
        self.Button.MouseEnter:Connect(function()
            if winObj._CurrentTab ~= self then
                Utils.Tween(self.Button, 0.15, { BackgroundTransparency = 0.85 })
            end
        end)
        self.Button.MouseLeave:Connect(function()
            if winObj._CurrentTab ~= self then
                Utils.Tween(self.Button, 0.15, { BackgroundTransparency = 1 })
            end
        end)

        return self
    end

    function Tab:Select()
        self.Window:_SelectTab(self)
    end

    function Tab:AddSection(name)
        local section = {
            Window = self.Window,
            Tab = self,
            Name = name,
            _y = 0,
        }

        section.Container = Utils.New("Frame", self.Container, {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = self.Window.Theme.SectionBG,
            BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.Y,
        })
        Utils.New("UICorner", section.Container, { CornerRadius = UDim.new(0, 9) })
        Utils.New("UIStroke", section.Container, { Color = self.Window.Theme.Stroke, Thickness = 1 })

        section.Header = Utils.New("TextLabel", section.Container, {
            Text = name or "Section",
            Position = UDim2.new(0, 12, 0, 10),
            Size = UDim2.new(1, -24, 0, 18),
            BackgroundTransparency = 1,
            TextColor3 = self.Window.Theme.Accent,
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
        })

        section.List = Utils.New("Frame", section.Container, {
            Position = UDim2.new(0, 0, 0, 36),
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.Y,
        })
        section.Layout = Utils.New("UIListLayout", section.List, {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8),
        })
        local pad = Utils.New("UIPadding", section.List, {
            PaddingLeft = UDim.new(0, 12),
            PaddingRight = UDim.new(0, 12),
            PaddingBottom = UDim.new(0, 12),
        })

        local function addElement(height, layoutOrder)
            local holder = Utils.New("Frame", section.List, {
                Size = UDim2.new(1, 0, 0, height),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = layoutOrder,
            })
            return holder
        end

        -- ============ ELEMENTS ============
        local order = 0

        function section:AddButton(name, callback)
            order = order + 1
            local holder = addElement(28, order)
            local btn = Utils.New("TextButton", holder, {
                Text = name,
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = self.Window.Theme.ElementBG,
                BorderSizePixel = 0,
                TextColor3 = self.Window.Theme.Text,
                Font = Enum.Font.GothamMedium,
                TextSize = 13,
                AutoButtonColor = false,
            })
            Utils.New("UICorner", btn, { CornerRadius = UDim.new(0, 6) })
            Utils.New("UIStroke", btn, { Color = self.Window.Theme.Stroke, Thickness = 1 })

            btn.MouseEnter:Connect(function()
                Utils.Tween(btn, 0.15, { BackgroundColor3 = self.Window.Theme.Hover })
            end)
            btn.MouseLeave:Connect(function()
                Utils.Tween(btn, 0.15, { BackgroundColor3 = self.Window.Theme.ElementBG })
            end)
            btn.MouseButton1Down:Connect(function()
                Utils.Tween(btn, 0.06, { BackgroundColor3 = self.Window.Theme.Accent })
            end)
            btn.MouseButton1Up:Connect(function()
                Utils.Tween(btn, 0.12, { BackgroundColor3 = self.Window.Theme.Hover })
            end)
            btn.MouseButton1Click:Connect(function()
                if callback then pcall(callback) end
            end)

            return MakeElement(self.Window)
        end

        function section:AddLabel(text)
            order = order + 1
            local holder = addElement(18, order)
            Utils.New("TextLabel", holder, {
                Text = text,
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                TextColor3 = self.Window.Theme.Subtext,
                Font = Enum.Font.GothamMedium,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            return MakeElement(self.Window)
        end

        function section:AddParagraph(title, text)
            order = order + 1
            local holder = addElement(46, order)
            Utils.New("TextLabel", holder, {
                Text = title,
                Size = UDim2.new(1, 0, 0, 16),
                BackgroundTransparency = 1,
                TextColor3 = self.Window.Theme.Text,
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            Utils.New("TextLabel", holder, {
                Text = text,
                Position = UDim2.new(0, 0, 0, 16),
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundTransparency = 1,
                TextColor3 = self.Window.Theme.Subtext,
                Font = Enum.Font.Gotham,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
            })
            return MakeElement(self.Window)
        end

        function section:AddDivider()
            order = order + 1
            local holder = addElement(10, order)
            Utils.New("Frame", holder, {
                Size = UDim2.new(1, 0, 0, 1),
                Position = UDim2.new(0, 0, 0.5, 0),
                BackgroundColor3 = self.Window.Theme.Stroke,
                BorderSizePixel = 0,
            })
            return MakeElement(self.Window)
        end
        
function section:AddToggle(name, default, callback)
    order = order + 1
    local holder = addElement(28, order)
    Utils.New("TextLabel", holder, {
        Text = name,
        Size = UDim2.new(1, -46, 1, 0),
        BackgroundTransparency = 1,
        TextColor3 = self.Window.Theme.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local btn = Utils.New("TextButton", holder, {
        Size = UDim2.new(0, 38, 0, 20),
        Position = UDim2.new(1, -38, 0.5, -10),
        BackgroundColor3 = self.Window.Theme.ElementBG,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    })
    Utils.New("UICorner", btn, { CornerRadius = UDim.new(1, 0) })
    Utils.New("UIStroke", btn, { Color = self.Window.Theme.Stroke, Thickness = 1 })
    local knob = Utils.New("Frame", btn, {
        Size = UDim2.fromOffset(14, 14),
        Position = UDim2.new(0, 3, 0.5, -7),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
    })
    Utils.New("UICorner", knob, { CornerRadius = UDim.new(1, 0) })

    local value = default == true
    local el = MakeElement(self.Window,
        function(v)
            value = v
            knob.Position = v and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
            btn.BackgroundColor3 = v and self.Window.Theme.Accent or self.Window.Theme.ElementBG
        end,
        function() return value end)

    btn.MouseButton1Click:Connect(function()
        value = not value
        el:_set(value)
        el:_fire(value)
    end)
    el:_set(value)
    return el
end

function section:AddSlider(name, min, max, default, callback, decimals)
    order = order + 1
    local holder = addElement(44, order)
    local decimals = decimals or 1

    Utils.New("TextLabel", holder, {
        Text = name,
        Size = UDim2.new(0, 150, 0, 14),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        TextColor3 = self.Window.Theme.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local valueLabel = Utils.New("TextLabel", holder, {
        Text = tostring(default),
        Size = UDim2.new(0, 60, 0, 14),
        Position = UDim2.new(1, -60, 0, 0),
        BackgroundTransparency = 1,
        TextColor3 = self.Window.Theme.Accent,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local track = Utils.New("Frame", holder, {
        Size = UDim2.new(1, 0, 0, 6),
        Position = UDim2.new(0, 0, 0, 20),
        BackgroundColor3 = self.Window.Theme.ElementBG,
        BorderSizePixel = 0,
    })
    Utils.New("UICorner", track, { CornerRadius = UDim.new(1, 0) })
    local fill = Utils.New("Frame", track, {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = self.Window.Theme.Accent,
        BorderSizePixel = 0,
    })
    Utils.New("UICorner", fill, { CornerRadius = UDim.new(1, 0) })
    local knob = Utils.New("Frame", track, {
        Size = UDim2.fromOffset(12, 12),
        Position = UDim2.new(0, 0, 0.5, -6),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 2,
    })
    Utils.New("UICorner", knob, { CornerRadius = UDim.new(1, 0) })
    Utils.New("UIStroke", knob, { Color = theme.Stroke, Thickness = 1 })

    local value = default or min
    local el = MakeElement(self.Window,
        function(v)
            value = Utils.Clamp(v, min, max)
            local frac = (value - min) / (max - min)
            fill.Size = UDim2.new(frac, 0, 1, 0)
            knob.Position = UDim2.new(frac, -6, 0.5, -6)
            valueLabel.Text = tostring(Utils.Round(value, decimals))
        end,
        function() return value end)

    local function updateFromInput(input)
        local frac = Utils.Clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local v = min + frac * (max - min)
        el:_set(v)
        el:_fire(v)
    end

    local sliding = false
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = true
            updateFromInput(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateFromInput(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = false
        end
    end)

    el:_set(value)
    return el
end

function section:AddDropdown(name, options, default, callback)
    order = order + 1
    local holder = addElement(28, order)
    local options = options or {}
    local selected = default or options[1]

    Utils.New("TextLabel", holder, {
        Text = name,
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 0, -16),
        BackgroundTransparency = 1,
        TextColor3 = self.Window.Theme.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local btn = Utils.New("TextButton", holder, {
        Text = "  " .. tostring(selected) .. "  ▾",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = self.Window.Theme.ElementBG,
        BorderSizePixel = 0,
        TextColor3 = self.Window.Theme.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
    })
    Utils.New("UICorner", btn, { CornerRadius = UDim.new(0, 6) })
    Utils.New("UIStroke", btn, { Color = self.Window.Theme.Stroke, Thickness = 1 })

    local dropdown = Utils.New("Frame", holder, {
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 1, 2),
        BackgroundColor3 = self.Window.Theme.SectionBG,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 5,
    })
    Utils.New("UICorner", dropdown, { CornerRadius = UDim.new(0, 6) })
    Utils.New("UIStroke", dropdown, { Color = self.Window.Theme.Stroke, Thickness = 1, ZIndex = 6 })
    local ddList = Utils.New("UIListLayout", dropdown, {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
    })

    local open = false
    local el = MakeElement(self.Window,
        function(v) selected = v; btn.Text = "  " .. tostring(v) .. "  ▾" end,
        function() return selected end)

    local function toggle()
        open = not open
        local h = open and (#options * 26 + 4) or 0
        Utils.Tween(dropdown, 0.2, { Size = UDim2.new(1, 0, 0, h) })
    end

    btn.MouseButton1Click:Connect(toggle)

    for i, opt in ipairs(options) do
        local ob = Utils.New("TextButton", dropdown, {
            Text = "  " .. tostring(opt),
            Size = UDim2.new(1, -4, 0, 26),
            Position = UDim2.new(0, 2, 0, 0),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 1,
            TextColor3 = self.Window.Theme.Text,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = false,
            LayoutOrder = i,
            ZIndex = 6,
        })
        ob.MouseEnter:Connect(function()
            Utils.Tween(ob, 0.12, { BackgroundTransparency = 0.85 })
        end)
        ob.MouseLeave:Connect(function()
            Utils.Tween(ob, 0.12, { BackgroundTransparency = 1 })
        end)
        ob.MouseButton1Click:Connect(function()
            selected = opt
            btn.Text = "  " .. tostring(opt) .. "  ▾"
            toggle()
            el:_fire(selected)
        end)
    end

    return el
end

function section:AddMultiDropdown(name, options, defaults, callback)
    order = order + 1
    local holder = addElement(28, order)
    local options = options or {}
    local selected = {}
    local defaults = defaults or {}
    for _, d in ipairs(defaults) do selected[d] = true end

    Utils.New("TextLabel", holder, {
        Text = name,
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 0, -16),
        BackgroundTransparency = 1,
        TextColor3 = self.Window.Theme.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local function fmtText()
        local active = {}
        for _, o in ipairs(options) do if selected[o] then table.insert(active, tostring(o)) end end
        local s = #active > 0 and table.concat(active, ", ") or "None"
        return "  " .. s .. "  ▾"
    end

    local btn = Utils.New("TextButton", holder, {
        Text = fmtText(),
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = self.Window.Theme.ElementBG,
        BorderSizePixel = 0,
        TextColor3 = self.Window.Theme.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        AutoButtonColor = false,
    })
    Utils.New("UICorner", btn, { CornerRadius = UDim.new(0, 6) })
    Utils.New("UIStroke", btn, { Color = self.Window.Theme.Stroke, Thickness = 1 })

    local dropdown = Utils.New("Frame", holder, {
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 1, 2),
        BackgroundColor3 = self.Window.Theme.SectionBG,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 5,
    })
    Utils.New("UICorner", dropdown, { CornerRadius = UDim.new(0, 6) })
    Utils.New("UIStroke", dropdown, { Color = self.Window.Theme.Stroke, Thickness = 1, ZIndex = 6 })
    Utils.New("UIListLayout", dropdown, {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
    })

    local open = false
    local el = MakeElement(self.Window,
        function(v) selected = v; btn.Text = fmtText() end,
        function() return selected end)

    local function toggle()
        open = not open
        local h = open and (#options * 26 + 4) or 0
        Utils.Tween(dropdown, 0.2, { Size = UDim2.new(1, 0, 0, h) })
    end

    btn.MouseButton1Click:Connect(toggle)

    for i, opt in ipairs(options) do
        local ob = Utils.New("TextButton", dropdown, {
            Text = "  " .. tostring(opt),
            Size = UDim2.new(1, -4, 0, 26),
            Position = UDim2.new(0, 2, 0, 0),
            BackgroundColor3 = selected[opt] and theme.Accent or Color3.new(1, 1, 1),
            BackgroundTransparency = selected[opt] and 0.15 or 1,
            TextColor3 = self.Window.Theme.Text,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = false,
            LayoutOrder = i,
            ZIndex = 6,
        })
        ob.MouseEnter:Connect(function()
            if not selected[opt] then Utils.Tween(ob, 0.12, { BackgroundTransparency = 0.85 }) end
        end)
        ob.MouseLeave:Connect(function()
            if not selected[opt] then Utils.Tween(ob, 0.12, { BackgroundTransparency = 1 }) end
        end)
        ob.MouseButton1Click:Connect(function()
            selected[opt] = not selected[opt]
            if selected[opt] then
                ob.BackgroundColor3 = theme.Accent
                ob.BackgroundTransparency = 0.15
            else
                ob.BackgroundColor3 = Color3.new(1, 1, 1)
                ob.BackgroundTransparency = 1
            end
            btn.Text = fmtText()
            el:_fire(selected)
        end)
    end

    return el
end

function section:AddTextbox(name, default, callback)
    order = order + 1
    local holder = addElement(28, order)
    Utils.New("TextLabel", holder, {
        Text = name,
        Size = UDim2.new(0, 120, 1, 0),
        BackgroundTransparency = 1,
        TextColor3 = self.Window.Theme.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local box = Utils.New("TextBox", holder, {
        Text = default or "",
        Size = UDim2.new(1, -128, 1, 0),
        Position = UDim2.new(0, 128, 0, 0),
        BackgroundColor3 = self.Window.Theme.ElementBG,
        BorderSizePixel = 0,
        TextColor3 = self.Window.Theme.Text,
        PlaceholderColor3 = self.Window.Theme.Subtext,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    Utils.New("UICorner", box, { CornerRadius = UDim.new(0, 6) })
    Utils.New("UIStroke", box, { Color = self.Window.Theme.Stroke, Thickness = 1 })

    local value = default or ""
    local el = MakeElement(self.Window,
        function(v) value = v; box.Text = v end,
        function() return value end)
    box.FocusLost:Connect(function(enter)
        value = box.Text
        el:_fire(value)
    end)
    return el
end

function section:AddKeybind(name, default, callback)
    order = order + 1
    local holder = addElement(28, order)
    Utils.New("TextLabel", holder, {
        Text = name,
        Size = UDim2.new(1, -92, 1, 0),
        BackgroundTransparency = 1,
        TextColor3 = self.Window.Theme.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local btn = Utils.New("TextButton", holder, {
        Text = tostring(default or Enum.KeyCode.None),
        Size = UDim2.new(0, 84, 1, 0),
        Position = UDim2.new(1, -84, 0, 0),
        BackgroundColor3 = self.Window.Theme.ElementBG,
        BorderSizePixel = 0,
        TextColor3 = self.Window.Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        AutoButtonColor = false,
    })
    Utils.New("UICorner", btn, { CornerRadius = UDim.new(0, 6) })
    Utils.New("UIStroke", btn, { Color = self.Window.Theme.Stroke, Thickness = 1 })

    local key = default
    local listening = false
    local inputConn

    local el = MakeElement(self.Window,
        function(v) key = v; btn.Text = tostring(v.KeyCode or v.Name or v) end,
        function() return key end)

    local function stopListening()
        listening = false
        btn.Text = tostring(key.KeyCode or key.Name or key)
        btn.TextColor3 = self.Window.Theme.Text
        if inputConn then inputConn:Disconnect(); inputConn = nil end
    end

    btn.MouseButton1Click:Connect(function()
        listening = not listening
        if listening then
            btn.Text = "..."
            btn.TextColor3 = self.Window.Theme.Accent
            inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    key = input.KeyCode
                    stopListening()
                    el:_fire(key)
                elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
                    key = input.UserInputType
                    stopListening()
                    el:_fire(key)
                end
            end)
        else
            stopListening()
        end
    end)

    return el
end

function section:AddColorpicker(name, default, callback)
    order = order + 1
    local holder = addElement(28, order)
    local color = default or Color3.fromRGB(255, 0, 0)

    Utils.New("TextLabel", holder, {
        Text = name,
        Size = UDim2.new(1, -46, 1, 0),
        BackgroundTransparency = 1,
        TextColor3 = self.Window.Theme.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local swatch = Utils.New("TextButton", holder, {
        Size = UDim2.fromOffset(30, 20),
        Position = UDim2.new(1, -30, 0.5, -10),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    })
    Utils.New("UICorner", swatch, { CornerRadius = UDim.new(0, 5) })
    Utils.New("UIStroke", swatch, { Color = self.Window.Theme.Stroke, Thickness = 1 })

    local popup = Utils.New("Frame", holder, {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0, 0, 1, 2),
        BackgroundColor3 = self.Window.Theme.SectionBG,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 5,
    })
    Utils.New("UICorner", popup, { CornerRadius = UDim.new(0, 7) })
    Utils.New("UIStroke", popup, { Color = self.Window.Theme.Stroke, Thickness = 1, ZIndex = 6 })

    -- SV picker
    local svBox = Utils.New("TextButton", popup, {
        Size = UDim2.new(1, -24, 0, 120),
        Position = UDim2.new(0, 12, 0, 12),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 6,
    })
    Utils.New("UICorner", svBox, { CornerRadius = UDim.new(0, 5) })

    local satGrad = Utils.New("UIGradient", svBox, {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
        ZIndex = 7,
    })
    local valGrad = Utils.New("UIGradient", svBox, {
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
        ZIndex = 7,
    })

    -- Hue slider
    local hueTrack = Utils.New("Frame", popup, {
        Size = UDim2.new(1, -24, 0, 10),
        Position = UDim2.new(0, 12, 0, 142),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 6,
    })
    Utils.New("UICorner", hueTrack, { CornerRadius = UDim.new(1, 0) })
    Utils.New("UIGradient", hueTrack, {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.34, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(0.84, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
        }),
        ZIndex = 7,
    })

    local hexLabel = Utils.New("TextLabel", popup, {
        Text = "#" .. color:ToHex(),
        Size = UDim2.new(1, -24, 0, 16),
        Position = UDim2.new(0, 12, 0, 160),
        BackgroundTransparency = 1,
        TextColor3 = self.Window.Theme.Subtext,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
    })

    local open = false
    local el = MakeElement(self.Window,
        function(v) color = v; swatch.BackgroundColor3 = v; hexLabel.Text = "#" .. v:ToHex() end,
        function() return color end)

    local function updateFromSV(input)
        local fx = Utils.Clamp((input.Position.X - svBox.AbsolutePosition.X) / svBox.AbsoluteSize.X, 0, 1)
        local fy = Utils.Clamp((input.Position.Y - svBox.AbsolutePosition.Y) / svBox.AbsoluteSize.Y, 0, 1)
        local h, _, _ = Utils.RGBtoHSV(color.R, color.G, color.B)
        local r, g, b = Utils.HSVtoRGB(h, fx, 1 - fy)
        el:_set(Color3.fromRGB(r * 255, g * 255, b * 255))
        el:_fire(color)
    end

    local function updateFromHue(input)
        local fx = Utils.Clamp((input.Position.X - hueTrack.AbsolutePosition.X) / hueTrack.AbsoluteSize.X, 0, 1)
        local _, s, v = Utils.RGBtoHSV(color.R, color.G, color.B)
        local r, g, b = Utils.HSVtoRGB(fx, s, v)
        el:_set(Color3.fromRGB(r * 255, g * 255, b * 255))
        el:_fire(color)
    end

    local draggingSv, draggingHue = false, false
    svBox.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingSv = true; updateFromSV(i) end
    end)
    hueTrack.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingHue = true; updateFromHue(i) end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if draggingSv and i.UserInputType == Enum.UserInputType.MouseMovement then updateFromSV(i) end
        if draggingHue and i.UserInputType == Enum.UserInputType.MouseMovement then updateFromHue(i) end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingSv, draggingHue = false, false end
    end)

    swatch.MouseButton1Click:Connect(function()
        open = not open
        local h = open and 188 or 0
        Utils.Tween(popup, 0.25, { Size = UDim2.new(1, 0, 0, h) })
    end)

    return el
end

table.insert(self.Sections, section)
return section
end

table.insert(window.Tabs, self)
return self
end

-- ================= Window methods =================
function window:_SelectTab(tab)
for _, t in ipairs(self.Tabs) do
    local active = (t == tab)
    t.Container.Visible = active
    Utils.Tween(t.Button, 0.2, { BackgroundTransparency = active and 0.8 or 1 })
    Utils.Tween(t.Accent, 0.2, { BackgroundTransparency = active and 0 or 1 })
    t.Button.TextColor3 = active and self.Theme.Text or self.Theme.Subtext
end
self._CurrentTab = tab
end

function window:AddTab(name)
local tab = Tab.new(self, name, #self.Tabs)
if not self._CurrentTab then
    self:_SelectTab(tab)
end
return tab
end

function window:GetFlags()
return self.Flags
end

function window:SaveConfig()
local data = {}
for k, v in pairs(self.Flags) do
    if typeof(v) == "Color3" then
        data[k] = { "Color3", v.R, v.G, v.B }
    elseif typeof(v) == "EnumItem" then
        data[k] = { "KeyCode", tostring(v) }
    elseif typeof(v) == "table" then
        local keys = {}
        for kk in pairs(v) do table.insert(keys, tostring(kk)) end
        data[k] = { "Table", keys }
    else
        data[k] = { typeof(v), tostring(v) }
    end
end
local json = HttpService:JSONEncode(data)
pcall(function()
    writefile("AetherUI_" .. self.Title .. ".json", json)
end)
self:Notify("Config", "Saved " .. #data .. " flags", 2)
return json
end

function window:LoadConfig()
local json
pcall(function()
    json = readfile("AetherUI_" .. self.Title .. ".json")
end)
if not json then return false end
local data = HttpService:JSONDecode(json)
for k, v in pairs(data) do
    local el = self._Elements[k]
    if el and v then
        local etype, val = v[1], v[2]
        if etype == "Color3" then
            el:Set(Color3.fromRGB(v[2], v[3], v[4]))
        elseif etype == "KeyCode" then
            el:Set(Enum.KeyCode[val])
        elseif etype == "Table" then
            local tbl = {}
            for _, kk in ipairs(val) do tbl[kk] = true end
            el:Set(tbl)
        elseif etype == "boolean" then
            el:Set(val == "true")
        elseif etype == "number" then
            el:Set(tonumber(val))
        else
            el:Set(val)
        end
    end
end
self:Notify("Config", "Loaded", 2)
return true
end

function window:Destroy()
gui:Destroy()
end

window._gui = gui
window._win = win

return window
end

return AetherUI
