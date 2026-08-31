-- Save this script on a site like GitHub Gist or Pastebin
local Library = {}

function Library:CreateWindow(titleText)
    -- 1. Create the Main ScreenGui
    local ScreenGui = Instance.new("ScreenGui")
    -- Protect the UI from being seen by normal game scripts
    ScreenGui.Parent = game:GetService("CoreGui") 
    ScreenGui.Name = "MyCustomLibrary"
    ScreenGui.ResetOnSpawn = false

    -- 2. Create the Main Window Frame
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 300, 0, 400)
    MainFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30) -- Dark theme
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true -- Simple built-in dragging (deprecated but works for testing)
    MainFrame.Parent = ScreenGui

    -- 3. Add a Title Label
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    Title.Text = titleText or "UI Window"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 18
    Title.Font = Enum.Font.SourceSansBold
    Title.Parent = MainFrame

    -- 4. Container for UI elements (Buttons, Toggles)
    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(1, -20, 1, -60)
    Container.Position = UDim2.new(0, 10, 0, 50)
    Container.BackgroundTransparency = 1
    Container.Parent = MainFrame

    -- Layout manager to stack elements automatically
    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.Padding = UDim.new(0, 5)
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Parent = Container

    -- Window Methods Object
    local Window = {}

    -- Method to create a button inside this window
    function Window:CreateButton(buttonText, callback)
        local Button = Instance.new("TextButton")
        Button.Size = UDim2.new(1, 0, 0, 35)
        Button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        Button.Text = buttonText
        Button.TextColor3 = Color3.fromRGB(255, 255, 255)
        Button.Font = Enum.Font.SourceSans
        Button.TextSize = 16
        Button.Parent = Container

        -- Round the corners slightly
        local UICorner = Instance.new("UICorner")
        UICorner.CornerRadius = UDim.new(0, 6)
        UICorner.Parent = Button

        -- Trigger the user function when clicked
        Button.MouseButton1Click:Connect(function()
            pcall(callback) -- pcall prevents the library from breaking if the callback has an error
        end)
    end

    return Window
end

return Library
