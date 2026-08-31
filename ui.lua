local Library = {}
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

function Library:CreateWindow(titleText)
    -- 1. Главный контейнер GUI
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Parent = game:GetService("CoreGui") 
    ScreenGui.Name = "MyCustomLibrary"
    ScreenGui.ResetOnSpawn = false

    -- 2. Главное Окно
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 300, 0, 420)
    MainFrame.Position = UDim2.new(0.5, -150, 0.5, -210)
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Parent = ScreenGui

    -- Скругление углов главного окна
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 8)
    MainCorner.Parent = MainFrame

    -- 3. Верхняя панель (Заголовок)
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    Title.Text = titleText or "UI Window"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 18
    Title.Font = Enum.Font.SourceSansBold
    Title.Parent = MainFrame

    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 8)
    TitleCorner.Parent = Title

    -- Скрываем нижние углы заголовка, чтобы они не вылезали на MainFrame
    local HideTitleBottom = Instance.new("Frame")
    HideTitleBottom.Size = UDim2.new(1, 0, 0, 10)
    HideTitleBottom.Position = UDim2.new(0, 0, 1, -10)
    HideTitleBottom.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    HideTitleBottom.BorderSizePixel = 0
    HideTitleBottom.Parent = Title

    -- 4. Контейнер для элементов с прокруткой (если элементов много)
    local Container = Instance.new("ScrollingFrame")
    Container.Size = UDim2.new(1, -20, 1, -60)
    Container.Position = UDim2.new(0, 10, 0, 50)
    Container.BackgroundTransparency = 1
    Container.BorderSizePixel = 0
    Container.ScrollBarThickness = 4
    Container.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
    Container.Parent = MainFrame

    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.Padding = UDim.new(0, 8)
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Parent = Container

    -- Автоматическое изменение размера зоны прокрутки под количество элементов
    UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        Container.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y + 10)
    end)

    -- Скрипт Плавного Перетаскивания (Smooth Dragging) за верхнюю панель
    local dragging, dragInput, dragStart, startPos
    local function update(input)
        local delta = input.Position - dragStart
        local targetPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        TweenService:Create(MainFrame, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = targetPos}):Play()
    end

    Title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)

    Title.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then update(input) end
    end)


    -- Объект методов окна
    local Window = {}

    -- МЕТОД: Создание обычной Кнопки
    function Window:CreateButton(buttonText, callback)
        local Button = Instance.new("TextButton")
        Button.Size = UDim2.new(1, -4, 0, 35)
        Button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        Button.Text = buttonText
        Button.TextColor3 = Color3.fromRGB(255, 255, 255)
        Button.Font = Enum.Font.SourceSans
        Button.TextSize = 16
        Button.Parent = Container

        local UICorner = Instance.new("UICorner")
        UICorner.CornerRadius = UDim.new(0, 6)
        UICorner.Parent = Button

        Button.MouseButton1Click:Connect(function()
            pcall(callback)
        end)
    end

    -- МЕТОД: Создание Переключателя (Toggle)
    function Window:CreateToggle(toggleText, callback)
        local state = false

        local ToggleButton = Instance.new("TextButton")
        ToggleButton.Size = UDim2.new(1, -4, 0, 35)
        ToggleButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        ToggleButton.Text = "  " .. toggleText .. " [OFF]"
        ToggleButton.TextColor3 = Color3.fromRGB(200, 200, 200)
        ToggleButton.TextXAlignment = Enum.TextXAlignment.Left
        ToggleButton.Font = Enum.Font.SourceSans
        ToggleButton.TextSize = 16
        ToggleButton.Parent = Container

        local UICorner = Instance.new("UICorner")
        UICorner.CornerRadius = UDim.new(0, 6)
        UICorner.Parent = ToggleButton

        ToggleButton.MouseButton1Click:Connect(function()
            state = not state
            if state then
                ToggleButton.Text = "  " .. toggleText .. " [ON]"
                ToggleButton.TextColor3 = Color3.fromRGB(100, 255, 100)
                TweenService:Create(ToggleButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(50, 70, 50)}):Play()
            else
                ToggleButton.Text = "  " .. toggleText .. " [OFF]"
                ToggleButton.TextColor3 = Color3.fromRGB(200, 200, 200)
                TweenService:Create(ToggleButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(60, 60, 60)}):Play()
            end
            pcall(callback, state)
        end)
    end

    -- МЕТОД: Создание Слайдера (Slider)
    function Window:CreateSlider(sliderText, min, max, default, callback)
        local min = min or 0
        local max = max or 100
        local default = default or min
        local value = default

        -- Основной задний фон слайдера
        local SliderFrame = Instance.new("Frame")
        SliderFrame.Size = UDim2.new(1, -4, 0, 45)
        SliderFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        SliderFrame.Parent = Container

        local UICorner = Instance.new("UICorner")
        UICorner.CornerRadius = UDim.new(0, 6)
        UICorner.Parent = SliderFrame

        -- Текст с названием и текущим значением
        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(1, -20, 0, 20)
        Label.Position = UDim2.new(0, 10, 0, 4)
        Label.BackgroundTransparency = 1
        Label.Text = sliderText .. ": " .. tostring(value)
        Label.TextColor3 = Color3.fromRGB(255, 255, 255)
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Font = Enum.Font.SourceSans
        Label.TextSize = 14
        Label.Parent = SliderFrame

        -- Пустая полоска трека слайдера
        local Track = Instance.new("TextButton")
        Track.Size = UDim2.new(1, -20, 0, 6)
        Track.Position = UDim2.new(0, 10, 0, 30)
        Track.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        Track.Text = ""
        Track.AutoButtonColor = false
        Track.Parent = SliderFrame

        local TrackCorner = Instance.new("UICorner")
        TrackCorner.CornerRadius = UDim.new(0, 3)
        TrackCorner.Parent = Track

        -- Заполняющая полоска активного значения
        local Fill = Instance.new("Frame")
        Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
        Fill.BackgroundColor3 = Color3.fromRGB(100, 150, 255) -- Синий ползунок
        Fill.BorderSizePixel = 0
        Fill.Parent = Track

        local FillCorner = Instance.new("UICorner")
        FillCorner.CornerRadius = UDim.new(0, 3)
        FillCorner.Parent = Fill

        -- Логика движения слайдера
        local sliding = false

        local function move(input)
            local scale = math.clamp((input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteWidth, 0, 1)
            value = math.floor(min + (scale * (max - min)))
            
            -- Плавное изменение ширины полоски заполнения
            TweenService:Create(Fill, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(scale, 0, 1, 0)}):Play()
            Label.Text = sliderText .. ": " .. tostring(value)
            
            pcall(callback, value)
        end

        Track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                sliding = true
                move(input)
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                move(input)
            end
        end)

        UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                -- Прекращаем слайд, если мышка отпущена где угодно на экране
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then sliding = false end
                end)
            end
        end)
    end

    return Window
end

return Library
