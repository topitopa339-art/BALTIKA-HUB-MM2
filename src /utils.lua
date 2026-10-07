local BHUB = _G.BHUB
local UserInputService = game:GetService("UserInputService")

local Theme = {
    BgMain = Color3.fromRGB(15, 15, 20),
    BgSidebar = Color3.fromRGB(12, 12, 16),
    BgCard = Color3.fromRGB(22, 22, 28),
    BgInput = Color3.fromRGB(18, 18, 24),
    ToggleOff = Color3.fromRGB(35, 35, 45),
    ToggleOn = Color3.fromRGB(130, 85, 255),
    Accent = Color3.fromRGB(130, 85, 255),
    AccentGlow = Color3.fromRGB(160, 120, 255),
    Success = Color3.fromRGB(50, 220, 130),
    Error = Color3.fromRGB(255, 75, 75),
    Warning = Color3.fromRGB(255, 185, 50),
    TextWhite = Color3.fromRGB(245, 245, 250),
    TextMuted = Color3.fromRGB(140, 140, 160),
    Border = Color3.fromRGB(40, 40, 52)
}

local function ApplyCorner(obj, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = obj
end

local function ApplyStroke(obj, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Theme.Border
    stroke.Thickness = thickness or 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = obj
end

local function ApplyPadding(obj, top, bottom, left, right)
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, top or 0)
    padding.PaddingBottom = UDim.new(0, bottom or 0)
    padding.PaddingLeft = UDim.new(0, left or 0)
    padding.PaddingRight = UDim.new(0, right or 0)
    padding.Parent = obj
end

local function MakeSmoothDraggable(dragArea, moveFrame)
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil

    dragArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = moveFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    dragArea.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            moveFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local function getHum(char)
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

BHUB.Theme = Theme
BHUB.ApplyCorner = ApplyCorner
BHUB.ApplyStroke = ApplyStroke
BHUB.ApplyPadding = ApplyPadding
BHUB.MakeSmoothDraggable = MakeSmoothDraggable
BHUB.getHum = getHum
