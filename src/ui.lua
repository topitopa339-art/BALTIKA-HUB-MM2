local BHUB = _G.BHUB
local Config = BHUB.Config
local keybinds = BHUB.keybinds
local player = BHUB.player
local Theme = BHUB.Theme
local ScreenGui = BHUB.ScreenGui
local ApplyCorner = BHUB.ApplyCorner
local ApplyStroke = BHUB.ApplyStroke
local ApplyPadding = BHUB.ApplyPadding
local MakeSmoothDraggable = BHUB.MakeSmoothDraggable
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local awaitingKeybindAction = nil
local keybindButtons = {}

local FovGui = Instance.new("ScreenGui")
if syn and syn.protect_gui then syn.protect_gui(FovGui) end
FovGui.Parent = CoreGui
FovGui.Name = "BALTIKA_HUB_FOV"
FovGui.ResetOnSpawn = false
local FovCircle = Instance.new("Frame")
FovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
FovCircle.Size = UDim2.new(0, Config.fovRadius * 2, 0, Config.fovRadius * 2)
FovCircle.BackgroundTransparency = 1
FovCircle.Visible = false
FovCircle.Parent = FovGui
local FovStroke = Instance.new("UIStroke")
FovStroke.Color = Color3.fromRGB(255, 255, 255)
FovStroke.Thickness = 1.5
FovStroke.Parent = FovCircle
Instance.new("UICorner", FovCircle).CornerRadius = UDim.new(1, 0)
BHUB.FovCircle = FovCircle
BHUB.FovStroke = FovStroke

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 680, 0, 440)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundColor3 = Theme.BgMain
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Visible = true
MainFrame.ZIndex = 5
MainFrame.Parent = ScreenGui
ApplyCorner(MainFrame, 12)
ApplyStroke(MainFrame, Theme.Border, 1.2)
MakeSmoothDraggable(MainFrame, MainFrame)

local UIScale = Instance.new("UIScale")
UIScale.Name = "AdaptiveScale"
UIScale.Parent = MainFrame

local userScale = 1

local function updateScale()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local autoScale = math.clamp(math.min(vp.X / 900, vp.Y / 600), 0.6, 1.1)
    UIScale.Scale = autoScale * userScale
end

updateScale()
if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    task.wait(0.1)
    updateScale()
    if workspace.CurrentCamera then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
    end
end)

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 180, 1, 0)
Sidebar.BackgroundColor3 = Theme.BgSidebar
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 6
Sidebar.Parent = MainFrame
ApplyCorner(Sidebar, 12)

local SideCover = Instance.new("Frame")
SideCover.Size = UDim2.new(0, 12, 1, 0)
SideCover.Position = UDim2.new(1, -12, 0, 0)
SideCover.BackgroundColor3 = Theme.BgSidebar
SideCover.BorderSizePixel = 0
SideCover.ZIndex = 6
SideCover.Parent = Sidebar

local LogoIcon = Instance.new("Frame")
LogoIcon.Size = UDim2.new(0, 10, 0, 10)
LogoIcon.Position = UDim2.new(0, 16, 0, 22)
LogoIcon.BackgroundColor3 = Theme.Accent
LogoIcon.BorderSizePixel = 0
LogoIcon.ZIndex = 7
LogoIcon.Parent = Sidebar
ApplyCorner(LogoIcon, 10)

local LogoTitle = Instance.new("TextLabel")
LogoTitle.Size = UDim2.new(1, -40, 0, 52)
LogoTitle.Position = UDim2.new(0, 34, 0, 0)
LogoTitle.BackgroundTransparency = 1
LogoTitle.Text = "BALTIKA<font color=\"#8a5cf6\"> HUB [NEW]</font>"
LogoTitle.RichText = true
LogoTitle.TextColor3 = Theme.TextWhite
LogoTitle.Font = Enum.Font.GothamBold
LogoTitle.TextSize = 14
LogoTitle.TextXAlignment = Enum.TextXAlignment.Left
LogoTitle.TextYAlignment = Enum.TextYAlignment.Center
LogoTitle.ZIndex = 7
LogoTitle.Parent = Sidebar

local TabList = Instance.new("ScrollingFrame")
TabList.Size = UDim2.new(1, -16, 1, -135)
TabList.Position = UDim2.new(0, 8, 0, 56)
TabList.BackgroundTransparency = 1
TabList.ScrollBarThickness = 0
TabList.ZIndex = 7
TabList.Parent = Sidebar
local TabLayout = Instance.new("UIListLayout")
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.Padding = UDim.new(0, 4)
TabLayout.Parent = TabList

local UserCard = Instance.new("Frame")
UserCard.Size = UDim2.new(1, -16, 0, 50)
UserCard.Position = UDim2.new(0, 8, 1, -60)
UserCard.BackgroundColor3 = Theme.BgCard
UserCard.ZIndex = 7
UserCard.Parent = Sidebar
ApplyCorner(UserCard, 8)
ApplyStroke(UserCard, Theme.Border, 1)

local UserAvatar = Instance.new("ImageLabel")
UserAvatar.Size = UDim2.new(0, 32, 0, 32)
UserAvatar.Position = UDim2.new(0, 8, 0.5, -16)
pcall(function() UserAvatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150" end)
UserAvatar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
UserAvatar.ZIndex = 8
UserAvatar.Parent = UserCard
ApplyCorner(UserAvatar, 100)

local UserName = Instance.new("TextLabel")
UserName.Size = UDim2.new(1, -48, 0, 16)
UserName.Position = UDim2.new(0, 46, 0, 10)
UserName.BackgroundTransparency = 1
UserName.Text = player.DisplayName
UserName.TextColor3 = Theme.TextWhite
UserName.Font = Enum.Font.GothamBold
UserName.TextSize = 12
UserName.TextXAlignment = Enum.TextXAlignment.Left
UserName.TextTruncate = Enum.TextTruncate.AtEnd
UserName.ZIndex = 8
UserName.Parent = UserCard

local UserStatus = Instance.new("TextLabel")
UserStatus.Size = UDim2.new(1, -48, 0, 14)
UserStatus.Position = UDim2.new(0, 46, 0, 26)
UserStatus.BackgroundTransparency = 1
UserStatus.Text = "t.me/BALTIKA_HUB"
UserStatus.TextColor3 = Theme.AccentGlow
UserStatus.Font = Enum.Font.GothamMedium
UserStatus.TextSize = 10
UserStatus.TextXAlignment = Enum.TextXAlignment.Left
UserStatus.ZIndex = 8
UserStatus.Parent = UserCard

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -190, 1, -18)
ContentArea.Position = UDim2.new(0, 185, 0, 9)
ContentArea.BackgroundTransparency = 1
ContentArea.ZIndex = 10
ContentArea.Parent = MainFrame

local MiniIcon = Instance.new("TextButton")
MiniIcon.Size = UDim2.new(0, 42, 0, 42)
MiniIcon.Position = UDim2.new(0, 20, 0.5, -21)
MiniIcon.BackgroundColor3 = Theme.BgMain
MiniIcon.BackgroundTransparency = 0.05
MiniIcon.Text = "⚡"
MiniIcon.TextColor3 = Theme.AccentGlow
MiniIcon.TextSize = 20
MiniIcon.AutoButtonColor = false
MiniIcon.ZIndex = 50
MiniIcon.Parent = ScreenGui
ApplyCorner(MiniIcon, 21)
ApplyStroke(MiniIcon, Theme.Accent, 1.5)
MakeSmoothDraggable(MiniIcon, MiniIcon)
MiniIcon.MouseButton1Click:Connect(function() MainFrame.Visible = not MainFrame.Visible end)

local CloseHubBtn = Instance.new("TextButton")
CloseHubBtn.Size = UDim2.new(0, 24, 0, 24)
CloseHubBtn.Position = UDim2.new(1, -30, 0, 8)
CloseHubBtn.BackgroundColor3 = Theme.BgCard
CloseHubBtn.TextColor3 = Theme.TextWhite
CloseHubBtn.Text = "✕"
CloseHubBtn.Font = Enum.Font.GothamBold
CloseHubBtn.TextSize = 13
CloseHubBtn.ZIndex = 50
CloseHubBtn.AutoButtonColor = false
CloseHubBtn.Parent = MainFrame
ApplyCorner(CloseHubBtn, 6)
ApplyStroke(CloseHubBtn, Theme.Border, 1)
CloseHubBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false end)

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 24, 0, 24)
MinimizeBtn.Position = UDim2.new(1, -60, 0, 8)
MinimizeBtn.BackgroundColor3 = Theme.BgCard
MinimizeBtn.TextColor3 = Theme.TextWhite
MinimizeBtn.Text = "▼"
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 12
MinimizeBtn.ZIndex = 50
MinimizeBtn.AutoButtonColor = false
MinimizeBtn.Parent = MainFrame
ApplyCorner(MinimizeBtn, 6)
ApplyStroke(MinimizeBtn, Theme.Border, 1)

local FullscreenBtn = Instance.new("TextButton")
FullscreenBtn.Size = UDim2.new(0, 24, 0, 24)
FullscreenBtn.Position = UDim2.new(1, -90, 0, 8)
FullscreenBtn.BackgroundColor3 = Theme.BgCard
FullscreenBtn.TextColor3 = Theme.TextWhite
FullscreenBtn.Text = "⛶"
FullscreenBtn.Font = Enum.Font.GothamBold
FullscreenBtn.TextSize = 12
FullscreenBtn.ZIndex = 50
FullscreenBtn.AutoButtonColor = false
FullscreenBtn.Parent = MainFrame
ApplyCorner(FullscreenBtn, 6)
ApplyStroke(FullscreenBtn, Theme.Border, 1)

local isMinimized = false
local isFullscreen = false
local originalSize = UDim2.new(0, 680, 0, 440)

MinimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 680, 0, 52)}):Play()
        MinimizeBtn.Text = "▲"
    else
        TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Size = originalSize}):Play()
        MinimizeBtn.Text = "▼"
    end
end)

FullscreenBtn.MouseButton1Click:Connect(function()
    isFullscreen = not isFullscreen
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    if isFullscreen then
        originalSize = MainFrame.Size
        TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Size = UDim2.new(0, vp.X, 0, vp.Y)}):Play()
        FullscreenBtn.Text = "⛉"
    else
        TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Size = originalSize}):Play()
        FullscreenBtn.Text = "⛶"
    end
end)

local ResizeHandle = Instance.new("TextButton")
ResizeHandle.Size = UDim2.new(0, 30, 0, 30)
ResizeHandle.Position = UDim2.new(1, -34, 1, -34)
ResizeHandle.BackgroundColor3 = Theme.Accent
ResizeHandle.BackgroundTransparency = 0.15
ResizeHandle.Text = "↘"
ResizeHandle.TextColor3 = Color3.fromRGB(255, 255, 255)
ResizeHandle.Font = Enum.Font.GothamBold
ResizeHandle.TextSize = 16
ResizeHandle.ZIndex = 60
ResizeHandle.AutoButtonColor = false
ResizeHandle.Parent = MainFrame
ApplyCorner(ResizeHandle, 8)
ApplyStroke(ResizeHandle, Theme.AccentGlow, 1.5)

local resizing = false
local resizeStart = nil
local startScale = 1

ResizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        resizing = true
        resizeStart = input.Position
        startScale = userScale
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not resizing then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - resizeStart
        local change = (delta.X + delta.Y) / 400
        userScale = math.clamp(startScale + change, 0.4, 2.0)
        updateScale()
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        resizing = false
    end
end)

local Tabs = {}
local function AddTab(name, single)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = Theme.BgCard
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.ZIndex = 8
    btn.Parent = TabList
    ApplyCorner(btn, 6)
    local ind = Instance.new("Frame")
    ind.Size = UDim2.new(0, 3, 0, 16)
    ind.Position = UDim2.new(0, 4, 0.5, -8)
    ind.BackgroundColor3 = Theme.Accent
    ind.Visible = false
    ind.ZIndex = 9
    ind.Parent = btn
    ApplyCorner(ind, 2)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = Theme.TextMuted
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.ZIndex = 9
    lbl.Parent = btn
    local page = Instance.new("Frame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.ZIndex = 10
    page.Parent = ContentArea
    local function mkCol(x, w)
        local col = Instance.new("ScrollingFrame")
        col.Size = UDim2.new(w, 0, 1, 0)
        col.Position = UDim2.new(x, 0, 0, 0)
        col.BackgroundTransparency = 1
        col.ScrollBarThickness = 3
        col.ScrollBarImageColor3 = Theme.Accent
        col.ScrollingEnabled = true
        col.ScrollingDirection = Enum.ScrollingDirection.Y
        col.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
        col.Active = true
        col.ClipsDescendants = true
        col.ZIndex = 11
        col.Parent = page
        local l = Instance.new("UIListLayout")
        l.SortOrder = Enum.SortOrder.LayoutOrder
        l.Padding = UDim.new(0, 8)
        l.Parent = col
        l:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            col.CanvasSize = UDim2.new(0, 0, 0, l.AbsoluteContentSize.Y + 12)
        end)
        return col
    end
    table.insert(Tabs, {btn = btn, label = lbl, page = page, ind = ind})
    btn.MouseButton1Click:Connect(function()
        for _, t in ipairs(Tabs) do
            t.page.Visible = false
            t.btn.BackgroundTransparency = 1
            t.label.TextColor3 = Theme.TextMuted
            t.label.Font = Enum.Font.GothamMedium
            t.ind.Visible = false
        end
        page.Visible = true
        btn.BackgroundTransparency = 0
        lbl.TextColor3 = Theme.TextWhite
        lbl.Font = Enum.Font.GothamBold
        ind.Visible = true
    end)
    if single then return mkCol(0, 1) else return mkCol(0, 0.49), mkCol(0.51, 0.49) end
end

local function AddSection(col, title)
    local s = Instance.new("Frame")
    s.Size = UDim2.new(1, 0, 0, 40)
    s.BackgroundColor3 = Theme.BgCard
    s.BorderSizePixel = 0
    s.ZIndex = 12
    s.Parent = col
    ApplyCorner(s, 8)
    ApplyStroke(s, Theme.Border, 1)
    ApplyPadding(s, 6, 6, 12, 12)
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, 0, 0, 22)
    t.BackgroundTransparency = 1
    t.Text = string.upper(title)
    t.TextColor3 = Theme.AccentGlow
    t.Font = Enum.Font.GothamBold
    t.TextSize = 11
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.ZIndex = 13
    t.Parent = s
    local l = Instance.new("UIListLayout")
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Padding = UDim.new(0, 4)
    l.Parent = s
    l:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        s.Size = UDim2.new(1, 0, 0, l.AbsoluteContentSize.Y + 16)
    end)
    return s
end

local function AddToggle(sec, text, cb, init)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 36)
    f.BackgroundTransparency = 1
    f.ZIndex = 13
    f.Parent = sec
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -80, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Theme.TextWhite
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.ZIndex = 14
    lbl.Parent = f
    local tg = Instance.new("TextButton")
    tg.Size = UDim2.new(0, 44, 0, 22)
    tg.Position = UDim2.new(1, -46, 0.5, -11)
    tg.BackgroundColor3 = Theme.ToggleOff
    tg.Text = ""
    tg.AutoButtonColor = false
    tg.Active = true
    tg.ZIndex = 14
    tg.Parent = f
    ApplyCorner(tg, 11)
    local cir = Instance.new("Frame")
    cir.Size = UDim2.new(0, 18, 0, 18)
    cir.Position = UDim2.new(0, 2, 0.5, -9)
    cir.BackgroundColor3 = Theme.TextWhite
    cir.ZIndex = 15
    cir.Parent = tg
    ApplyCorner(cir, 100)
    local state = false
    local function upd(ns, fire)
        state = ns
        TweenService:Create(cir, TweenInfo.new(0.12), {Position = state and UDim2.new(0, 24, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)}):Play()
        TweenService:Create(tg, TweenInfo.new(0.12), {BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff}):Play()
        if fire ~= false and cb then cb(state) end
    end
    tg.MouseButton1Click:Connect(function() upd(not state) end)
    tg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then upd(not state) end
    end)
    if init then upd(true, false) end
    return {setState = upd, getState = function() return state end}
end

local function AddSlider(sec, text, mn, mx, def, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 46)
    f.BackgroundTransparency = 1
    f.ZIndex = 13
    f.Parent = sec
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 0, 18)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Theme.TextWhite
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 14
    lbl.Parent = f
    local vl = Instance.new("TextLabel")
    vl.Size = UDim2.new(0, 45, 0, 18)
    vl.Position = UDim2.new(1, -45, 0, 0)
    vl.BackgroundTransparency = 1
    vl.Text = tostring(def)
    vl.TextColor3 = Theme.AccentGlow
    vl.Font = Enum.Font.GothamBold
    vl.TextSize = 12
    vl.TextXAlignment = Enum.TextXAlignment.Right
    vl.ZIndex = 14
    vl.Parent = f
    local bg = Instance.new("TextButton")
    bg.Size = UDim2.new(1, 0, 0, 10)
    bg.Position = UDim2.new(0, 0, 0, 26)
    bg.BackgroundColor3 = Theme.ToggleOff
    bg.BorderSizePixel = 0
    bg.Text = ""
    bg.AutoButtonColor = false
    bg.Active = true
    bg.ZIndex = 14
    bg.Parent = f
    ApplyCorner(bg, 5)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(math.clamp((def - mn) / (mx - mn), 0, 1), 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.ZIndex = 15
    fill.Parent = bg
    ApplyCorner(fill, 5)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = UDim2.new(math.clamp((def - mn) / (mx - mn), 0, 1), 0, 0.5, -9)
    knob.BackgroundColor3 = Theme.TextWhite
    knob.ZIndex = 16
    knob.Parent = bg
    ApplyCorner(knob, 100)
    local drag = false
    local function upd()
        local mouse = UserInputService:GetMouseLocation()
        local m = mouse.X
        local sp = bg.AbsolutePosition.X
        local ss = bg.AbsoluteSize.X
        if ss <= 0 then return end
        local p = math.clamp((m - sp) / ss, 0, 1)
        fill.Size = UDim2.new(p, 0, 1, 0)
        knob.Position = UDim2.new(p, 0, 0.5, -9)
        local v = math.floor(mn + ((mx - mn) * p) + 0.5)
        vl.Text = tostring(v)
        if cb then cb(v) end
    end
    bg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            drag = true
            upd()
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not drag then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            upd()
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            drag = false
        end
    end)
end

local function AddButton(sec, text, special, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 36)
    f.BackgroundTransparency = 1
    f.ZIndex = 13
    f.Parent = sec
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 1, -4)
    b.Position = UDim2.new(0, 0, 0, 2)
    b.BackgroundColor3 = special and Theme.Accent or Theme.BgInput
    b.TextColor3 = Theme.TextWhite
    b.Text = text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.TextTruncate = Enum.TextTruncate.AtEnd
    b.AutoButtonColor = false
    b.Active = true
    b.ZIndex = 14
    b.Parent = f
    ApplyCorner(b, 6)
    ApplyStroke(b, special and Theme.AccentGlow or Theme.Border, 1)
    b.MouseButton1Click:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.08), {BackgroundColor3 = Theme.Border}):Play()
        task.wait(0.08)
        TweenService:Create(b, TweenInfo.new(0.08), {BackgroundColor3 = special and Theme.Accent or Theme.BgInput}):Play()
        if cb then cb() end
    end)
    return b
end

local function AddTextBox(sec, ph, h, cb)
    h = h or 34
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, h)
    f.BackgroundTransparency = 1
    f.ZIndex = 13
    f.Parent = sec
    local b = Instance.new("TextBox")
    b.Size = UDim2.new(1, 0, 1, -4)
    b.Position = UDim2.new(0, 0, 0, 2)
    b.BackgroundColor3 = Theme.BgInput
    b.TextColor3 = Theme.TextWhite
    b.PlaceholderColor3 = Theme.TextMuted
    b.PlaceholderText = ph
    b.Text = ""
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 12
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.ClearTextOnFocus = false
    b.ZIndex = 14
    if h > 36 then
        b.TextYAlignment = Enum.TextYAlignment.Top
        b.TextWrapped = true
        b.MultiLine = true
    else
        b.TextYAlignment = Enum.TextYAlignment.Center
    end
    b.Parent = f
    ApplyCorner(b, 6)
    ApplyStroke(b, Theme.Border, 1)
    ApplyPadding(b, 4, 4, 10, 10)
    b:GetPropertyChangedSignal("Text"):Connect(function()
        if cb then cb(b.Text) end
    end)
    return b
end

local function AddKeybind(sec, labelText, actionKey)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 36)
    f.BackgroundTransparency = 1
    f.ZIndex = 13
    f.Parent = sec
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -80, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Theme.TextWhite
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.ZIndex = 14
    lbl.Parent = f
    local kb = Instance.new("TextButton")
    kb.Size = UDim2.new(0, 75, 0, 24)
    kb.Position = UDim2.new(1, -75, 0.5, -12)
    kb.BackgroundColor3 = Theme.BgInput
    kb.TextColor3 = Theme.AccentGlow
    kb.Text = (keybinds[actionKey] and keybinds[actionKey] ~= Enum.KeyCode.Unknown) and keybinds[actionKey].Name or "None"
    kb.Font = Enum.Font.GothamBold
    kb.TextSize = 11
    kb.AutoButtonColor = false
    kb.Active = true
    kb.ZIndex = 14
    kb.Parent = f
    ApplyCorner(kb, 6)
    ApplyStroke(kb, Theme.Border, 1)
    keybindButtons[actionKey] = kb
    kb.MouseButton1Click:Connect(function()
        if awaitingKeybindAction then
            local prev = keybindButtons[awaitingKeybindAction]
            if prev then
                prev.Text = (keybinds[awaitingKeybindAction] and keybinds[awaitingKeybindAction] ~= Enum.KeyCode.Unknown) and keybinds[awaitingKeybindAction].Name or "None"
            end
        end
        awaitingKeybindAction = actionKey
        kb.Text = "..."
    end)
end

BHUB.AddTab = AddTab
BHUB.AddSection = AddSection
BHUB.AddToggle = AddToggle
BHUB.AddSlider = AddSlider
BHUB.AddButton = AddButton
BHUB.AddTextBox = AddTextBox
BHUB.AddKeybind = AddKeybind
BHUB.MainFrame = MainFrame
BHUB.UIScale = UIScale
BHUB.updateScale = updateScale
BHUB.getAwaitingKeybind = function() return awaitingKeybindAction end
BHUB.setAwaitingKeybind = function(v) awaitingKeybindAction = v end
BHUB.keybindButtons = keybindButtons

local MoveLeft, MoveRight = AddTab("Movement", false)
local FlingLeft, FlingRight = AddTab("Fling & Combat", false)
local VisLeft, VisRight = AddTab("Visuals & Misc", false)
local SetLeft, SetRight = AddTab("Settings & Binds", false)

local SpeedSec = AddSection(MoveLeft, "Speed & Dash")
AddToggle(SpeedSec, "Super Speed", function(s) Config.superSpeedEnabled = s end, Config.superSpeedEnabled)
AddSlider(SpeedSec, "Speed Multiplier", 1, 10, Config.speedMultiplier, function(v) Config.speedMultiplier = v end)
AddButton(SpeedSec, "Dash", false, function() if BHUB.performDash then BHUB.performDash() end end)
AddSlider(SpeedSec, "Dash Strength", 30, 300, Config.dashStrength, function(v) Config.dashStrength = v end)

local JumpSec = AddSection(MoveLeft, "Jumping")
AddToggle(JumpSec, "Bunny Hop", function(s) Config.bhopEnabled = s end, Config.bhopEnabled)
AddToggle(JumpSec, "Wallhop", function(s) Config.wallhopEnabled = s end, Config.wallhopEnabled)
AddSlider(JumpSec, "Wallhop Power", 20, 150, Config.wallhopVelocity, function(v) Config.wallhopVelocity = v end)
AddToggle(JumpSec, "Infinite Jump", function(s) Config.infiniteJumpEnabled = s end, Config.infiniteJumpEnabled)
AddSlider(JumpSec, "Inf Jump Boost", 10, 200, Config.infJumpBoost, function(v) Config.infJumpBoost = v end)
AddToggle(JumpSec, "Super Jump", function(s) Config.superJumpEnabled = s end, Config.superJumpEnabled)
AddSlider(JumpSec, "Jump Multiplier", 1, 10, Config.jumpPowerMultiplier, function(v) Config.jumpPowerMultiplier = v end)

local FlightSec = AddSection(MoveRight, "Flight & Physics")
AddToggle(FlightSec, "Fly (WASD + QE)", function(s) if BHUB.toggleFly then BHUB.toggleFly(s) end end, Config.flyEnabled)
AddSlider(FlightSec, "Fly Speed", 10, 200, Config.flySpeed, function(v) Config.flySpeed = v end)
AddToggle(FlightSec, "Air Walk", function(s) if BHUB.toggleAirWalk then BHUB.toggleAirWalk(s) end end, Config.airWalkEnabled)
AddToggle(FlightSec, "Spider Climb", function(s) if BHUB.toggleSpider then BHUB.toggleSpider(s) end end, Config.spiderEnabled)
AddToggle(FlightSec, "NoClip", function(s) if BHUB.toggleNoclip then BHUB.toggleNoclip(s) end end, Config.noclipEnabled)

local CharSec = AddSection(MoveRight, "Character")
AddToggle(CharSec, "Unlock Movement", function(s) if BHUB.toggleUnlockMovement then BHUB.toggleUnlockMovement(s) end end, Config.unlockMovementEnabled)
AddToggle(CharSec, "Tiny Character", function(s) if BHUB.applyTinyCharacter then BHUB.applyTinyCharacter(s) end end, Config.tinyCharEnabled)
AddSlider(CharSec, "Size (% of normal)", 5, 100, Config.tinyScalePercent, function(v)
    Config.tinyScalePercent = v
    if Config.tinyCharEnabled and BHUB.applyTinyCharacter then BHUB.applyTinyCharacter(true) end
end)
AddToggle(CharSec, "Custom Mass", function(s) if BHUB.applyCharacterMass then BHUB.applyCharacterMass(s) end end, Config.customMassEnabled)
AddSlider(CharSec, "Mass Multiplier", 1, 100, Config.massMultiplier, function(v)
    Config.massMultiplier = v
    if Config.customMassEnabled and BHUB.applyCharacterMass then BHUB.applyCharacterMass(true) end
end)

local WalkFlingSec = AddSection(FlingLeft, "Attack")
AddToggle(WalkFlingSec, "Walk Fling", function(s) if BHUB.toggleWalkFling then BHUB.toggleWalkFling(s) end end, Config.walkFlingEnabled)
AddToggle(WalkFlingSec, "Spinbot", function(s) if BHUB.toggleSpinbot then BHUB.toggleSpinbot(s) end end, Config.spinbotEnabled)
AddSlider(WalkFlingSec, "Spin Speed", 10, 200, Config.spinbotSpeed, function(v) Config.spinbotSpeed = v end)

local AimSec = AddSection(FlingLeft, "Aimbot")
AddToggle(AimSec, "Enable Aimbot", function(s) Config.aimbotEnabled = s end, Config.aimbotEnabled)
AddToggle(AimSec, "Target Bots", function(s) Config.aimbotTargetBots = s end, Config.aimbotTargetBots)
AddToggle(AimSec, "Show FOV Circle", function(s)
    Config.showFovEnabled = s
    if BHUB.FovCircle then
        BHUB.FovCircle.Size = UDim2.new(0, Config.fovRadius * 2, 0, Config.fovRadius * 2)
        BHUB.FovCircle.Visible = s
    end
end, Config.showFovEnabled)
AddSlider(AimSec, "FOV Radius", 10, 500, Config.fovRadius, function(v)
    Config.fovRadius = v
    if BHUB.FovCircle then BHUB.FovCircle.Size = UDim2.new(0, v * 2, 0, v * 2) end
end)
AddSlider(AimSec, "Smoothness", 1, 10, Config.aimbotSmoothness, function(v) Config.aimbotSmoothness = v end)

local ProtectSec = AddSection(FlingRight, "Protection")
AddToggle(ProtectSec, "Anti-Fling", function(s) if BHUB.toggleAntiFling then BHUB.toggleAntiFling(s) end end, Config.antiFlingEnabled)
AddToggle(ProtectSec, "Anti-Void", function(s) if BHUB.toggleAntiVoid then BHUB.toggleAntiVoid(s) end end, Config.antiVoidEnabled)
AddToggle(ProtectSec, "Anti-Ragdoll", function(s) if BHUB.toggleAntiRagdoll then BHUB.toggleAntiRagdoll(s) end end, Config.antiRagdollEnabled)
AddToggle(ProtectSec, "Auto-Hide (HP <= 40)", function(s) if BHUB.toggleAutoHideCombat then BHUB.toggleAutoHideCombat(s) end end, Config.autoHideCombatEnabled)

local VisSec = AddSection(VisLeft, "Visuals")
AddToggle(VisSec, "Player ESP", function(s) if BHUB.toggleEspWrapper then BHUB.toggleEspWrapper(s) end end, Config.espEnabled)
AddToggle(VisSec, "X-Ray", function(s) if BHUB.toggleXray then BHUB.toggleXray(s) end end, Config.xrayEnabled)
AddSlider(VisSec, "X-Ray Transparency", 1, 10, math.floor(Config.xrayTransparency * 10), function(v)
    Config.xrayTransparency = v / 10
    if Config.xrayEnabled and BHUB.toggleXray then BHUB.toggleXray(true) end
end)
AddToggle(VisSec, "Fullbright", function(s) if BHUB.toggleFullbright then BHUB.toggleFullbright(s) end end, Config.fullbrightEnabled)
AddToggle(VisSec, "3rd Person", function(s) if BHUB.toggleThirdPerson then BHUB.toggleThirdPerson(s) end end, Config.thirdPersonEnabled)

local MiscSec = AddSection(VisRight, "Misc")
AddToggle(MiscSec, "Click TP", function(s) Config.clickTpEnabled = s end, Config.clickTpEnabled)
AddToggle(MiscSec, "Unlock Mouse", function(s) if BHUB.toggleMouseUnlock then BHUB.toggleMouseUnlock(s) end end, Config.mouseUnlockEnabled)
AddButton(MiscSec, "Kill Character (Perma)", false, function() if BHUB.permaKillCharacter then BHUB.permaKillCharacter() end end)

local BindsMove = AddSection(SetLeft, "Movement Binds")
AddKeybind(BindsMove, "Bhop", "BhopToggle")
AddKeybind(BindsMove, "Wallhop", "WallhopToggle")
AddKeybind(BindsMove, "Fly", "FlyToggle")
AddKeybind(BindsMove, "Noclip", "NoclipToggle")
AddKeybind(BindsMove, "Speed", "SpeedToggle")
AddKeybind(BindsMove, "Dash", "DashKey")
AddKeybind(BindsMove, "AirWalk", "AirWalkToggle")
AddKeybind(BindsMove, "Spider", "SpiderToggle")
AddKeybind(BindsMove, "Inf Jump", "InfJumpToggle")
AddKeybind(BindsMove, "Super Jump", "SuperJumpToggle")

local BindsMisc = AddSection(SetRight, "Misc Binds")
AddKeybind(BindsMisc, "Open Menu", "ToggleMenu")
AddKeybind(BindsMisc, "Click TP", "ClickTP")
AddKeybind(BindsMisc, "Unlock Mouse", "UnlockMouse")
AddKeybind(BindsMisc, "Player ESP", "EspToggle")
AddKeybind(BindsMisc, "X-Ray", "XrayToggle")
AddKeybind(BindsMisc, "3rd Person", "ThirdPersonToggle")
AddKeybind(BindsMisc, "Spinbot", "SpinbotToggle")
AddKeybind(BindsMisc, "Walk Fling", "WalkFlingToggle")
AddKeybind(BindsMisc, "Anti-Fling", "AntiFlingToggle")
AddButton(BindsMisc, "Save Config Now", true, function()
    if BHUB.SaveConfig then BHUB.SaveConfig() end
end)

if Tabs[1] then
    Tabs[1].page.Visible = true
    Tabs[1].btn.BackgroundTransparency = 0
    Tabs[1].label.TextColor3 = Theme.TextWhite
    Tabs[1].label.Font = Enum.Font.GothamBold
    Tabs[1].ind.Visible = true
end
