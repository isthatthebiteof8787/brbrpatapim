-- Инициализация библиотеки
local Library = {
    CurrentTab = nil,
    Theme = {
        Main = Color3.fromRGB(25, 25, 30),
        Secondary = Color3.fromRGB(32, 32, 38),
        Accent = Color3.fromRGB(0, 150, 255),
        Text = Color3.fromRGB(255, 255, 255),
        TextDark = Color3.fromRGB(160, 160, 160)
    }
}

-- Защищенный контейнер для UI
local TargetParent = game:GetService("CoreGui") or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

function Library:CreateWindow(title)
    title = title or "Universal Cheat"
    
    -- Создание ScreenGui со случайным именем для обхода детектов
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "UI_" .. math.random(100000, 999999)
    ScreenGui.Parent = TargetParent
    ScreenGui.ResetOnSpawn = false
    
    -- Главный фрейм
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 550, 0, 350)
    MainFrame.Position = UDim2.new(0.5, -275, 0.5, -175)
    MainFrame.BackgroundColor3 = self.Theme.Main
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true -- Базовое перетаскивание (для кастомного нужен UIS)
    MainFrame.Parent = ScreenGui
    
    -- Скругление углов
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 8)
    UICorner.Parent = MainFrame
    
    -- Боковая панель для вкладок (Sidebar)
    local Sidebar = Instance.new("Frame")
    Sidebar.Name = "Sidebar"
    Sidebar.Size = UDim2.new(0, 150, 1, 0)
    Sidebar.BackgroundColor3 = self.Theme.Secondary
    Sidebar.BorderSizePixel = 0
    Sidebar.Parent = MainFrame
    
    local SidebarCorner = Instance.new("UICorner")
    SidebarCorner.CornerRadius = UDim.new(0, 8)
    SidebarCorner.Parent = Sidebar
    
    -- Заголовок
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -10, 0, 40)
    Title.Position = UDim2.new(0, 10, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = title
    Title.TextColor3 = self.Theme.Text
    Title.TextSize = 18
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Sidebar
    
    -- Контейнер для кнопок вкладок
    local TabButtonsContainer = Instance.new("Frame")
    TabButtonsContainer.Size = UDim2.new(1, 0, 1, -50)
    TabButtonsContainer.Position = UDim2.new(0, 0, 0, 50)
    TabButtonsContainer.BackgroundTransparency = 1
    TabButtonsContainer.Parent = Sidebar
    
    local TabListLayout = Instance.new("UIListLayout")
    TabListLayout.Padding = UDim.new(0, 5)
    TabListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    TabListLayout.Parent = TabButtonsContainer
    
    -- Контейнер для страниц
    local PagesContainer = Instance.new("Frame")
    PagesContainer.Size = UDim2.new(1, -160, 1, -20)
    PagesContainer.Position = UDim2.new(0, 155, 0, 10)
    PagesContainer.BackgroundTransparency = 1
    PagesContainer.Parent = MainFrame

    local Window = {}
    
    -- Функция создания вкладки (Tab)
    function Window:CreateTab(tabName)
        -- Кнопка вкладки
        local TabButton = Instance.new("TextButton")
        TabButton.Size = UDim2.new(0, 130, 0, 32)
        TabButton.BackgroundColor3 = Library.Theme.Main
        TabButton.Text = tabName
        TabButton.TextColor3 = Library.Theme.TextDark
        TabButton.Font = Enum.Font.Gotham
        TabButton.TextSize = 14
        TabButton.Parent = TabButtonsContainer
        
        local ButtonCorner = Instance.new("UICorner")
        ButtonCorner.CornerRadius = UDim.new(0, 6)
        ButtonCorner.Parent = TabButton
        
        -- Страница элементов
        local Page = Instance.new("ScrollingFrame")
        Page.Size = UDim2.new(1, 0, 1, 0)
        Page.BackgroundTransparency = 1
        Page.Visible = false
        Page.ScrollBarThickness = 2
        Page.CanvasSize = UDim2.new(0, 0, 0, 0)
        Page.Parent = PagesContainer
        
        local PageListLayout = Instance.new("UIListLayout")
        PageListLayout.Padding = UDim.new(0, 7)
        PageListLayout.Parent = Page
        
        -- Автоматический размер скролла
        PageListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            Page.CanvasSize = UDim2.new(0, 0, 0, PageListLayout.AbsoluteContentSize.Y + 10)
        end)
        
        -- Логика переключения вкладок
        if Library.CurrentTab == nil then
            Library.CurrentTab = {Button = TabButton, Page = Page}
            TabButton.TextColor3 = Library.Theme.Accent
            Page.Visible = true
        end
        
        TabButton.MouseButton1Click:Connect(function()
            if Library.CurrentTab then
                Library.CurrentTab.Button.TextColor3 = Library.Theme.TextDark
                Library.CurrentTab.Page.Visible = false
            end
            TabButton.TextColor3 = Library.Theme.Accent
            Page.Visible = true
            Library.CurrentTab = {Button = TabButton, Page = Page}
        end)
        
        local TabElements = {}
        
        -- Функция добавления Кнопки (Button)
        function TabElements:AddButton(text, callback)
            callback = callback or function() end
            
            local Button = Instance.new("TextButton")
            Button.Size = UDim2.new(1, -10, 0, 35)
            Button.BackgroundColor3 = Library.Theme.Secondary
            Button.Text = "  " .. text
            Button.TextColor3 = Library.Theme.Text
            Button.Font = Enum.Font.Gotham
            Button.TextSize = 14
            Button.TextXAlignment = Enum.TextXAlignment.Left
            Button.Parent = Page
            
            local ElementCorner = Instance.new("UICorner")
            ElementCorner.CornerRadius = UDim.new(0, 6)
            ElementCorner.Parent = Button
            
            Button.MouseButton1Click:Connect(callback)
        end
        
        -- Функция добавления Переключателя (Toggle)
        function TabElements:AddToggle(text, callback)
            callback = callback or function() end
            local Toggled = false
            
            local ToggleFrame = Instance.new("TextButton")
            ToggleFrame.Size = UDim2.new(1, -10, 0, 35)
            ToggleFrame.BackgroundColor3 = Library.Theme.Secondary
            ToggleFrame.Text = "  " .. text
            ToggleFrame.TextColor3 = Library.Theme.Text
            ToggleFrame.Font = Enum.Font.Gotham
            ToggleFrame.TextSize = 14
            ToggleFrame.TextXAlignment = Enum.TextXAlignment.Left
            ToggleFrame.Parent = Page
            
            local ElementCorner = Instance.new("UICorner")
            ElementCorner.CornerRadius = UDim.new(0, 6)
            ElementCorner.Parent = ToggleFrame
            
            -- Индикатор статуса
            local Indicator = Instance.new("Frame")
            Indicator.Size = UDim2.new(0, 18, 0, 18)
            Indicator.Position = UDim2.new(1, -28, 0.5, -9)
            Indicator.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
            Indicator.Parent = ToggleFrame
            
            local IndCorner = Instance.new("UICorner")
            IndCorner.CornerRadius = UDim.new(0, 4)
            IndCorner.Parent = Indicator
            
            ToggleFrame.MouseButton1Click:Connect(function()
                Toggled = not Toggled
                TweenService = game:GetService("TweenService")
                
                local targetColor = Toggled and Library.Theme.Accent or Color3.fromRGB(50, 50, 55)
                TweenService:Create(Indicator, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
                
                callback(Toggled)
            end)
        end
        
        return TabElements
    end
    
    return Window
end

return Library
