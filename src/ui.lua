--[[ ==========================================================================
     BALTIKA HUB  •  UI v2   (полностью перерисованный интерфейс)
     --------------------------------------------------------------------------
       • современный вид: карточки, градиенты, акценты, плавные анимации
       • адаптация под мобилку: drawer-меню, крупные тапы, авто-масштаб,
         запас под полоску жестов снизу, одна колонка на телефоне
       • уведомления (тосты), сворачивание, ресайз, выбор акцентного цвета
       • настройки интерфейса сохраняются в конфиг (Config.ui*)
     --------------------------------------------------------------------------
       API для остальных модулей сохранён 1:1:
       AddTab / AddSection / AddToggle / AddSlider / AddButton /
       AddTextBox / AddKeybind + MainFrame, Sidebar, ContentArea, UIScale,
       updateScale, getAwaitingKeybind, setAwaitingKeybind, keybindButtons
     ========================================================================== ]]

local BHUB = _G.BHUB
if not BHUB then
    warn("[BALTIKA] ui.lua: ядро не загружено (нужны config.lua и utils.lua)")
    return
end

local Config    = BHUB.Config
local keybinds  = BHUB.keybinds
local player    = BHUB.player
local Theme     = BHUB.Theme
local ScreenGui = BHUB.ScreenGui

local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")

--===========================================================================
--  ПАЛИТРА
--===========================================================================
local P = {
    BgTop        = Color3.fromRGB(20, 20, 28),
    BgMain       = Color3.fromRGB(16, 16, 22),
    BgBottom     = Color3.fromRGB(11, 11, 16),
    BgSidebar    = Color3.fromRGB(13, 13, 18),
    BgSidebar2   = Color3.fromRGB(10, 10, 14),
    BgCard       = Color3.fromRGB(23, 23, 31),
    BgCardHover  = Color3.fromRGB(31, 31, 42),
    BgInput      = Color3.fromRGB(19, 19, 26),
    ToggleOff    = Color3.fromRGB(40, 40, 53),
    Border       = Color3.fromRGB(40, 40, 54),
    BorderSoft   = Color3.fromRGB(30, 30, 41),
    Divider      = Color3.fromRGB(27, 27, 36),
    TextWhite    = Color3.fromRGB(240, 241, 248),
    TextMuted    = Color3.fromRGB(136, 138, 160),
    TextDim      = Color3.fromRGB(92, 94, 116),
    Success      = Color3.fromRGB(64, 214, 143),
    Error        = Color3.fromRGB(255, 88, 96),
    Warning      = Color3.fromRGB(255, 186, 84),
}
for k, v in pairs(P) do Theme[k] = v end

local DEFAULT_ACCENT = Color3.fromRGB(124, 92, 255)

--===========================================================================
--  МЕЛКИЕ ХЕЛПЕРЫ
--===========================================================================
local function new(class, props, parent)
    local obj = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            obj[k] = v
        end
    end
    if parent then
        obj.Parent = parent
    end
    return obj
end

local function corner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = obj
    return c
end

local function stroke(obj, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or P.Border
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = obj
    return s
end

local function padding(obj, top, bottom, left, right)
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, top or 0)
    p.PaddingBottom = UDim.new(0, bottom or 0)
    p.PaddingLeft = UDim.new(0, left or 0)
    p.PaddingRight = UDim.new(0, right or 0)
    p.Parent = obj
    return p
end

local function vlist(obj, pad, halign)
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Vertical
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Padding = UDim.new(0, pad or 0)
    if halign then l.HorizontalAlignment = halign end
    l.Parent = obj
    return l
end

local function hlist(obj, pad, halign, valign)
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Horizontal
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Padding = UDim.new(0, pad or 0)
    l.HorizontalAlignment = halign or Enum.HorizontalAlignment.Left
    l.VerticalAlignment = valign or Enum.VerticalAlignment.Center
    l.Parent = obj
    return l
end

local function gradient(obj, c1, c2, rotation)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(c1, c2)
    g.Rotation = rotation or 90
    g.Parent = obj
    return g
end

local function tw(obj, time, props, style, dir)
    local t = TweenService:Create(obj,
        TweenInfo.new(time, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function lighten(c, a) return c:Lerp(Color3.new(1, 1, 1), a) end
local function darken(c, a) return c:Lerp(Color3.new(0, 0, 0), a) end

local function packColor(c)
    return math.floor(c.R * 255 + 0.5) * 65536 + math.floor(c.G * 255 + 0.5) * 256 + math.floor(c.B * 255 + 0.5)
end

local function unpackColor(n)
    n = tonumber(n) or 0
    return Color3.fromRGB(math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
end

local function hexColor(c)
    return string.format("#%02X%02X%02X",
        math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

--===========================================================================
--  АКЦЕНТНЫЙ ЦВЕТ (живая смена + подписка элементов)
--===========================================================================
local accentBindings = {}

local function bindAccent(fn)
    table.insert(accentBindings, fn)
    pcall(fn, Theme.Accent)
end

local appliedAccentPack = nil

local function setAccent(color, save)
    Theme.Accent      = color
    Theme.AccentGlow  = lighten(color, 0.34)
    Theme.AccentDim   = darken(color, 0.42)
    Theme.AccentSoft  = lighten(color, 0.75)
    Theme.ToggleOn    = color
    appliedAccentPack = packColor(color)
    if save then
        Config.uiAccent = appliedAccentPack
        if BHUB.SaveConfig then pcall(BHUB.SaveConfig) end
    end
    for _, fn in ipairs(accentBindings) do
        pcall(fn, color)
    end
end

--===========================================================================
--  УВЕДОМЛЕНИЯ (тосты)
--===========================================================================
local NotifyHolder = new("Frame", {
    Name = "Notifications",
    BackgroundTransparency = 1,
    Size = UDim2.new(0, 268, 0, 300),
    Position = UDim2.new(1, -14, 0, 12),
    ZIndex = 200,
}, ScreenGui)
vlist(NotifyHolder, 8, Enum.HorizontalAlignment.Right)

local notifyOrder = 0

local function Notify(message, kind, title)
    if type(message) ~= "string" then message = tostring(message) end

    local color = Theme.Accent
    if kind == "success" then color = P.Success
    elseif kind == "error" then color = P.Error
    elseif kind == "warn" then color = P.Warning end

    if not title then
        title = "BALTIKA HUB"
    end

    notifyOrder = notifyOrder + 1

    local holder = new("Frame", {
        Name = "Toast",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 56),
        LayoutOrder = notifyOrder,
        ZIndex = 201,
    }, NotifyHolder)

    local card = new("Frame", {
        Name = "Card",
        BackgroundColor3 = P.BgCard,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 34, 0, 0),
        ZIndex = 202,
    }, holder)
    corner(card, 12)
    local cardStroke = stroke(card, P.Border, 1, 1)

    local bar = new("Frame", {
        BackgroundColor3 = color,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 3, 1, -22),
        Position = UDim2.new(0, 11, 0, 11),
        ZIndex = 203,
    }, card)
    corner(bar, 2)

    local t1 = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -34, 0, 16),
        Position = UDim2.new(0, 22, 0, 10),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        Text = string.upper(title),
        TextColor3 = color,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
        ZIndex = 203,
    }, card)

    local t2 = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -34, 0, 16),
        Position = UDim2.new(0, 22, 0, 28),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        Text = message,
        TextColor3 = P.TextMuted,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextTransparency = 1,
        ZIndex = 203,
    }, card)

    -- появление
    tw(card, 0.28, { BackgroundTransparency = 0, Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Quint)
    tw(bar, 0.28, { BackgroundTransparency = 0 })
    tw(t1, 0.28, { TextTransparency = 0 })
    tw(t2, 0.28, { TextTransparency = 0 })
    tw(cardStroke, 0.28, { Transparency = 0 })

    -- авто-скрытие
    task.delay(3.6, function()
        if not holder.Parent then return end
        tw(card, 0.25, { BackgroundTransparency = 1, Position = UDim2.new(0, 34, 0, 0) })
        tw(bar, 0.25, { BackgroundTransparency = 1 })
        tw(t1, 0.25, { TextTransparency = 1 })
        tw(t2, 0.25, { TextTransparency = 1 })
        tw(cardStroke, 0.25, { Transparency = 1 })
        task.delay(0.3, function()
            if holder then holder:Destroy() end
        end)
    end)
end

-- начальный акцент из конфига
setAccent(unpackColor(tonumber(Config.uiAccent) or packColor(DEFAULT_ACCENT)), false)

BHUB.Notify = Notify
BHUB.SetAccent = setAccent
BHUB.bindAccent = bindAccent

--===========================================================================
--  FOV КРУГ (для аимбота)
--===========================================================================
local FovGui = new("ScreenGui", {
    Name = "BALTIKA_HUB_FOV",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 2,
})
pcall(function() FovGui.ScreenInsets = Enum.ScreenInsets.None end)
if syn and syn.protect_gui then pcall(syn.protect_gui, FovGui) end
FovGui.Parent = CoreGui

local FovCircle = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, (Config.fovRadius or 150) * 2, 0, (Config.fovRadius or 150) * 2),
    BackgroundTransparency = 1,
    Visible = false,
    ZIndex = 1,
}, FovGui)
corner(FovCircle, 9999)
local FovStroke = stroke(FovCircle, Color3.fromRGB(255, 255, 255), 1.5, 0.15)

local FovInner = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(1, -6, 1, -6),
    BackgroundTransparency = 1,
    ZIndex = 2,
}, FovCircle)
corner(FovInner, 9999)
local FovStrokeInner = stroke(FovInner, Color3.fromRGB(255, 255, 255), 1, 0.82)

bindAccent(function(c)
    FovStroke.Color = c
    FovStrokeInner.Color = lighten(c, 0.4)
end)

BHUB.FovCircle = FovCircle
BHUB.FovStroke = FovStroke
BHUB.FovGui = FovGui
--===========================================================================
--  РАЗМЕРЫ / РЕЖИМ УСТРОЙСТВА
--===========================================================================
local TOPBAR_H         = 46
local SIDE_W_DESKTOP   = 202
local SIDE_W_MOBILE    = 236
local PAD              = 10
local GAP              = 12

local function detectMobile()
    local ok, res = pcall(function()
        return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
    end)
    return (ok and res) and true or false
end

local mobileMode
if Config.uiMobile == "on" then
    mobileMode = true
elseif Config.uiMobile == "off" then
    mobileMode = false
else
    mobileMode = detectMobile()
end

local sideW = mobileMode and SIDE_W_MOBILE or SIDE_W_DESKTOP

local userScale = 1
if type(Config.uiScale) == "number" then
    userScale = math.clamp(Config.uiScale / 100, 0.6, 1.5)
end

--===========================================================================
--  ГЛАВНОЕ ОКНО
--===========================================================================
pcall(function() ScreenGui.DisplayOrder = 20 end)

local MainFrame = new("Frame", {
    Name = "BALTIKA_HUB",
    BackgroundColor3 = P.BgMain,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Active = true,
    AnchorPoint = Vector2.new(0, 0),
    Position = UDim2.new(0, 40, 0, 40),
    Size = UDim2.new(0, 740, 0, 486),
    ZIndex = 5,
    Visible = true,
}, ScreenGui)
corner(MainFrame, 14)
gradient(MainFrame, P.BgMain, P.BgBottom, 90)
local MainStroke = stroke(MainFrame, P.BorderSoft, 1.2)

local UIScale = new("UIScale", { Name = "AdaptiveScale", Scale = 1 }, MainFrame)

local desktopSize = Vector2.new(740, 486)
local fullscreen   = false
local minimized    = false
local currentScale = 1

--===========================================================================
--  ГЕОМЕТРИЯ / МАСШТАБ
--===========================================================================
local function viewportPx()
    local ok, abs = pcall(function() return ScreenGui.AbsoluteSize end)
    if ok and abs and abs.X > 10 and abs.Y > 10 then
        return abs
    end
    local cam = workspace.CurrentCamera
    if cam then return cam.ViewportSize end
    return Vector2.new(1280, 720)
end

local function screenDesign()
    local s = currentScale > 0 and currentScale or 1
    local vp = viewportPx()
    return Vector2.new(vp.X / s, vp.Y / s)
end

local function clampToScreen(frame, margin)
    if not frame or not frame.Parent then return end
    margin = margin or 4
    local vp = viewportPx()
    local abs, size = frame.AbsolutePosition, frame.AbsoluteSize
    if size.X <= 1 or size.Y <= 1 then return end
    local nx = math.clamp(abs.X, margin, math.max(margin, vp.X - size.X - margin))
    local ny = math.clamp(abs.Y, margin, math.max(margin, vp.Y - size.Y - margin))
    if math.abs(nx - abs.X) < 0.5 and math.abs(ny - abs.Y) < 0.5 then return end
    local s = currentScale > 0 and currentScale or 1
    frame.Position = UDim2.new(0, frame.Position.X.Offset + (nx - abs.X) / s,
                               0, frame.Position.Y.Offset + (ny - abs.Y) / s)
end

local function computeWindowSize()
    local scr = screenDesign()
    if mobileMode then
        return UDim2.new(0, math.max(300, math.floor(scr.X) - 6), 0, math.max(220, math.floor(scr.Y) - 6))
    end
    local w, h
    if fullscreen then
        w, h = scr.X - 12, scr.Y - 12
    else
        w = math.min(desktopSize.X, math.max(560, scr.X - 24))
        h = math.min(desktopSize.Y, math.max(340, scr.Y - 24))
    end
    if minimized then
        w = math.min(w, 380)
        h = TOPBAR_H
    end
    return UDim2.new(0, math.floor(w), 0, math.floor(h))
end

local updateScale

local function applyModeSize(instant)
    local size = computeWindowSize()
    if instant then
        MainFrame.Size = size
    else
        tw(MainFrame, 0.22, { Size = size }, Enum.EasingStyle.Quint)
    end
    if mobileMode then
        MainFrame.Position = UDim2.new(0, 3, 0, 3)
    end
end

local updateNotifyHolder = function()
    if mobileMode then
        NotifyHolder.Size = UDim2.new(0, math.min(300, screenDesign().X - 24), 0, 300)
        NotifyHolder.Position = UDim2.new(0.5, 0, 0, 8)
        NotifyHolder.AnchorPoint = Vector2.new(0.5, 0)
    else
        NotifyHolder.Size = UDim2.new(0, 268, 0, 300)
        NotifyHolder.Position = UDim2.new(1, -14, 0, 12)
        NotifyHolder.AnchorPoint = Vector2.new(0, 0)
    end
end

--===========================================================================
--  ВЕРХНЯЯ ПАНЕЛЬ
--===========================================================================
local TopBar = new("Frame", {
    Name = "TopBar",
    BackgroundColor3 = P.BgTop,
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, TOPBAR_H),
    ZIndex = 6,
}, MainFrame)
gradient(TopBar, P.BgTop, P.BgMain, 90)

local TopDivider = new("Frame", {
    BackgroundColor3 = P.Divider,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, TOPBAR_H - 1),
    Size = UDim2.new(1, 0, 0, 1),
    ZIndex = 7,
}, MainFrame)

local DragArea = new("Frame", {
    Name = "DragArea",
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, -180, 1, 0),
    ZIndex = 8,
    Active = true,
}, TopBar)

-- логотип
local LogoMark = new("Frame", {
    Name = "Logo",
    BackgroundColor3 = Theme.Accent,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 14, 0.5, -11),
    Size = UDim2.new(0, 22, 0, 22),
    ZIndex = 9,
}, TopBar)
corner(LogoMark, 7)
local LogoGrad = gradient(LogoMark, lighten(Theme.Accent, 0.22), darken(Theme.Accent, 0.15), 45)
new("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 1, 0),
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    Text = "B",
    TextColor3 = Color3.new(1, 1, 1),
    ZIndex = 10,
}, LogoMark)

local Brand = new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 42, 0, 0),
    Size = UDim2.new(0, 180, 1, 0),
    RichText = true,
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    Text = "BALTIKA <font color=\"" .. hexColor(Theme.Accent) .. "\">HUB</font>",
    TextColor3 = P.TextWhite,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 9,
}, TopBar)

local BrandBadge = new("Frame", {
    BackgroundColor3 = Theme.Accent,
    BackgroundTransparency = 0.84,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 148, 0.5, -7),
    Size = UDim2.new(0, 30, 0, 15),
    ZIndex = 9,
}, TopBar)
corner(BrandBadge, 8)
new("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 1, 0),
    Font = Enum.Font.GothamBold,
    TextSize = 8,
    Text = "NEW",
    TextColor3 = Theme.AccentSoft,
    ZIndex = 10,
}, BrandBadge)

-- кнопка-бургер (мобилка)
local MenuBtn = new("TextButton", {
    Name = "Menu",
    BackgroundColor3 = P.BgCardHover,
    BackgroundTransparency = 1,
    Text = "",
    AutoButtonColor = false,
    Position = UDim2.new(0, 8, 0.5, -14),
    Size = UDim2.new(0, 28, 0, 28),
    Visible = false,
    ZIndex = 9,
}, TopBar)
corner(MenuBtn, 8)
for i = -1, 1 do
    new("Frame", {
        BackgroundColor3 = P.TextWhite,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, i * 6),
        Size = UDim2.new(0, 13, 0, 2),
        ZIndex = 10,
    }, MenuBtn)
end

-- правая группа кнопок окна
local BtnHolder = new("Frame", {
    BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -10, 0.5, 0),
    Size = UDim2.new(0, 130, 0, 28),
    ZIndex = 9,
}, TopBar)
hlist(BtnHolder, 6, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

local function chromeButton(glyph, order, danger)
    local b = new("TextButton", {
        BackgroundColor3 = danger and P.Error or P.BgCardHover,
        BackgroundTransparency = 1,
        Text = glyph,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = P.TextMuted,
        AutoButtonColor = false,
        Size = UDim2.new(0, 28, 0, 28),
        LayoutOrder = order,
        ZIndex = 9,
    }, BtnHolder)
    corner(b, 8)
    b.MouseEnter:Connect(function()
        tw(b, 0.15, { BackgroundTransparency = 0.45, TextColor3 = danger and P.Error or P.TextWhite })
    end)
    b.MouseLeave:Connect(function()
        tw(b, 0.15, { BackgroundTransparency = 1, TextColor3 = P.TextMuted })
    end)
    return b
end

local MinimizeBtn = chromeButton("▼", 1, false)
local FullscreenBtn = chromeButton("⛶", 2, false)
local CloseBtn = chromeButton("✕", 3, true)

--===========================================================================
--  САЙДБАР
--===========================================================================
local Sidebar = new("Frame", {
    Name = "Sidebar",
    BackgroundColor3 = P.BgSidebar,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, TOPBAR_H),
    Size = UDim2.new(0, sideW, 1, -TOPBAR_H),
    ZIndex = 6,
}, MainFrame)
gradient(Sidebar, P.BgSidebar, P.BgSidebar2, 90)

local SideDivider = new("Frame", {
    BackgroundColor3 = P.Divider,
    BorderSizePixel = 0,
    Position = UDim2.new(0, sideW - 1, 0, TOPBAR_H),
    Size = UDim2.new(0, 1, 1, -TOPBAR_H),
    ZIndex = 7,
}, MainFrame)

-- карточка профиля
local ProfileCard = new("Frame", {
    Name = "Profile",
    BackgroundColor3 = P.BgCard,
    BackgroundTransparency = 0.35,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 10, 0, 10),
    Size = UDim2.new(1, -20, 0, 56),
    ZIndex = 8,
}, Sidebar)
corner(ProfileCard, 11)
stroke(ProfileCard, P.BorderSoft, 1)
gradient(ProfileCard, P.BgCard, P.BgSidebar, 90)

local AvatarHolder = new("Frame", {
    BackgroundColor3 = P.BgInput,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 10, 0.5, -17),
    Size = UDim2.new(0, 34, 0, 34),
    ZIndex = 9,
}, ProfileCard)
corner(AvatarHolder, 999)

local AvatarLetter = new("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 1, 0),
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    Text = string.sub(player.Name or "?", 1, 1):upper(),
    TextColor3 = P.TextMuted,
    ZIndex = 10,
}, AvatarHolder)

local Avatar = new("ImageLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 1, 0),
    Image = "",
    ZIndex = 11,
}, AvatarHolder)
corner(Avatar, 999)
pcall(function()
    Avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(player.UserId) .. "&w=150&h=150"
end)

local OnlineDot = new("Frame", {
    Name = "OnlineDot",
    BackgroundColor3 = P.Success,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, 1, 1, 1),
    Size = UDim2.new(0, 10, 0, 10),
    ZIndex = 12,
}, AvatarHolder)
corner(OnlineDot, 999)
stroke(OnlineDot, P.BgCard, 2)

local ProfileName = new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 54, 0, 12),
    Size = UDim2.new(1, -64, 0, 16),
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    Text = player.DisplayName or player.Name,
    TextColor3 = P.TextWhite,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 9,
}, ProfileCard)

local ProfileSub = new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 54, 0, 29),
    Size = UDim2.new(1, -64, 0, 14),
    Font = Enum.Font.GothamMedium,
    TextSize = 10,
    Text = "@" .. tostring(player.Name),
    TextColor3 = P.TextMuted,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 9,
}, ProfileCard)

-- список вкладок
local TabList = new("ScrollingFrame", {
    Name = "TabList",
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 8, 0, 78),
    Size = UDim2.new(1, -16, 1, -78 - 78),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticCanvasSize.Y,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = Theme.Accent,
    ScrollBarImageTransparency = 0.4,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
    Active = true,
    ZIndex = 8,
}, Sidebar)
vlist(TabList, 4, Enum.HorizontalAlignment.Center)

-- подвал сайдбара
local LinkBtn = new("TextButton", {
    BackgroundColor3 = P.BgCard,
    BackgroundTransparency = 0.4,
    Text = "t.me/BALTIKA_HUB",
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    TextColor3 = Theme.AccentGlow,
    AutoButtonColor = false,
    Position = UDim2.new(0, 10, 1, -70),
    Size = UDim2.new(1, -20, 0, 32),
    ZIndex = 8,
}, Sidebar)
corner(LinkBtn, 9)
local LinkStroke = stroke(LinkBtn, P.BorderSoft, 1)
bindAccent(function(c)
    LinkBtn.TextColor3 = lighten(c, 0.4)
    LinkStroke.Color = darken(c, 0.55)
end)

local VersionLabel = new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 10, 1, -34),
    Size = UDim2.new(1, -20, 0, 24),
    Font = Enum.Font.GothamMedium,
    TextSize = 10,
    Text = "BALTIKA HUB  •  v2.0  •  MM2",
    TextColor3 = P.TextDim,
    ZIndex = 8,
}, Sidebar)

--===========================================================================
--  ОБЛАСТЬ КОНТЕНТА / СТРАНИЦЫ
--===========================================================================
local ContentArea = new("Frame", {
    Name = "Content",
    BackgroundTransparency = 1,
    Position = UDim2.new(0, sideW, 0, TOPBAR_H),
    Size = UDim2.new(1, -sideW, 1, -TOPBAR_H),
    ZIndex = 5,
}, MainFrame)

local Tabs = {}
local selectedTab = 0

local updatePageCanvas

local function newColumn(page, index)
    local col = new("Frame", {
        Name = "Column" .. index,
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = index == 1 and UDim2.new(0.5, -(PAD + GAP / 2), 0, 0) or UDim2.new(0.5, -(PAD + GAP / 2), 0, 0),
        Position = index == 1 and UDim2.new(0, PAD, 0, PAD) or UDim2.new(0.5, GAP / 2, 0, PAD),
        ZIndex = 7,
    }, page)
    vlist(col, 10)
    col:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        updatePageCanvas(page)
    end)
    return col
end

updatePageCanvas = function(page)
    local cols = page._cols
    if not cols then return end
    local h = 0
    local s = currentScale > 0 and currentScale or 1
    for _, col in ipairs(cols) do
        if col and col.Visible then
            h = math.max(h, col.AbsoluteSize.Y / s)
        end
    end
    page.CanvasSize = UDim2.new(0, 0, 0, math.ceil(h) + PAD + (mobileMode and 26 or 8))
end

local function newPage()
    local page = new("ScrollingFrame", {
        Name = "Page",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.Accent,
        ScrollBarImageTransparency = 0.45,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
        Active = true,
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 6,
    }, ContentArea)
    bindAccent(function(c)
        page.ScrollBarImageColor3 = c
    end)
    return page
end

-- одна колонка, если места мало (телефон, узкое окно)
local function pagesUseSingleColumn()
    local contentW
    if mobileMode then
        contentW = screenDesign().X
    else
        contentW = MainFrame.Size.X.Offset - sideW
    end
    return contentW < 430
end

-- пересчёт раскладки колонок страницы
local function applyPageLayout(page)
    local cols = page._cols
    if not cols then return end
    local left = cols[1]
    local right = cols[2]
    if pagesUseSingleColumn() then
        left.Position = UDim2.new(0, 14, 0, 12)
        left.Size = UDim2.new(1, -28, 0, 0)
        if right then
            right.Visible = false
        end
    else
        left.Position = UDim2.new(0, PAD, 0, PAD)
        left.Size = UDim2.new(0.5, -(PAD + GAP / 2), 0, 0)
        if right then
            right.Visible = true
            right.Position = UDim2.new(0.5, GAP / 2, 0, PAD)
            right.Size = UDim2.new(0.5, -(PAD + GAP / 2), 0, 0)
        end
    end
    updatePageCanvas(page)
end

local function relayoutAllPages()
    for _, t in ipairs(Tabs) do
        applyPageLayout(t.page)
    end
end

--===========================================================================
--  ВКЛАДКИ
--===========================================================================
local setDrawer = nil

local function tabRowHeight()
    return mobileMode and 44 or 38
end

local function styleTab(t, isActive, instant)
    t.isActive = isActive
    local tr = instant and 0.01 or 0.2
    tw(t.active, tr, { BackgroundTransparency = isActive and 0.88 or 1 })
    t.label.Font = isActive and Enum.Font.GothamBold or Enum.Font.GothamMedium
    tw(t.label, tr, { TextColor3 = isActive and P.TextWhite or P.TextMuted })
    tw(t.iconBg, tr, { BackgroundColor3 = isActive and Theme.Accent or P.BgCard })
    tw(t.iconText, tr, { TextColor3 = isActive and Color3.new(1, 1, 1) or P.TextDim })
    t.iconGrad.Enabled = isActive
end

local function selectTab(index)
    if index == selectedTab then
        if mobileMode then setDrawer(false) end
        return
    end
    selectedTab = index
    for i, t in ipairs(Tabs) do
        local isActive = (i == index)
        t.page.Visible = isActive
        styleTab(t, isActive)
        if isActive then
            updatePageCanvas(t.page)
        end
    end
    if mobileMode then setDrawer(false) end
end

local function AddTab(name, single)
    local row = new("TextButton", {
        Name = "Tab_" .. tostring(name),
        BackgroundColor3 = P.BgCardHover,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.new(1, -14, 0, tabRowHeight()),
        LayoutOrder = #Tabs + 1,
        ZIndex = 9,
    }, TabList)
    corner(row, 10)

    local active = new("Frame", {
        Name = "Active",
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 9,
    }, row)
    corner(active, 10)

    local iconBg = new("Frame", {
        BackgroundColor3 = P.BgCard,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 8, 0.5, -13),
        Size = UDim2.new(0, 26, 0, 26),
        ZIndex = 10,
    }, row)
    corner(iconBg, 8)
    local iconGrad = gradient(iconBg, lighten(Theme.Accent, 0.25), Theme.Accent, 45)
    iconGrad.Enabled = false

    local iconText = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        Text = string.sub(tostring(name), 1, 1):upper(),
        TextColor3 = P.TextDim,
        ZIndex = 11,
    }, iconBg)

    local label = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 42, 0, 0),
        Size = UDim2.new(1, -50, 1, 0),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        Text = tostring(name),
        TextColor3 = P.TextMuted,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 10,
    }, row)

    local page = newPage()
    local col1 = newColumn(page, 1)
    local col2 = nil
    if not single then
        col2 = newColumn(page, 2)
    end
    page._cols = { col1, col2 }

    local t = {
        btn = row, label = label, page = page, active = active,
        iconBg = iconBg, iconText = iconText, iconGrad = iconGrad,
        cols = page._cols, isActive = false,
    }
    table.insert(Tabs, t)

    bindAccent(function(c)
        t.active.BackgroundColor3 = c
        t.iconGrad.Color = ColorSequence.new(lighten(c, 0.25), c)
        if t.isActive then
            t.iconBg.BackgroundColor3 = c
        end
    end)

    row.MouseEnter:Connect(function()
        if not t.isActive then
            tw(row, 0.15, { BackgroundTransparency = 0.7 })
        end
    end)
    row.MouseLeave:Connect(function()
        if not t.isActive then
            tw(row, 0.15, { BackgroundTransparency = 1 })
        end
    end)
    row.MouseButton1Click:Connect(function()
        selectTab(table.find(Tabs, t))
    end)

    applyPageLayout(page)

    if single then
        return col1
    end
    return col1, col2
end

--===========================================================================
--  DRAWER (мобильное меню)
--===========================================================================
local DrawerOverlay = new("Frame", {
    Name = "DrawerOverlay",
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0.55,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, TOPBAR_H),
    Size = UDim2.new(1, 0, 1, -TOPBAR_H),
    Visible = false,
    ZIndex = 35,
}, MainFrame)
local OverlayBtn = new("TextButton", {
    BackgroundTransparency = 1,
    Text = "",
    Size = UDim2.new(1, 0, 1, 0),
    ZIndex = 36,
}, DrawerOverlay)

local drawerOpen = false
setDrawer = function(open, instant)
    open = open and true or false
    if not mobileMode then
        drawerOpen = false
        DrawerOverlay.Visible = false
        Sidebar.Position = UDim2.new(0, 0, 0, TOPBAR_H)
        return
    end
    drawerOpen = open
    DrawerOverlay.Visible = open
    local target = open and UDim2.new(0, 0, 0, TOPBAR_H) or UDim2.new(0, -(sideW + 6), 0, TOPBAR_H)
    if instant then
        Sidebar.Position = target
    else
        tw(Sidebar, 0.24, { Position = target }, Enum.EasingStyle.Quint)
    end
end

OverlayBtn.MouseButton1Click:Connect(function()
    setDrawer(false)
end)

--===========================================================================
--  МИНИ-КНОПКА (когда окно закрыто)
--===========================================================================
local MiniIcon = new("TextButton", {
    Name = "MiniIcon",
    BackgroundColor3 = P.BgCard,
    Text = "",
    AutoButtonColor = false,
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 16, 0.5, 0),
    Size = UDim2.new(0, 138, 0, 40),
    Visible = false,
    ZIndex = 100,
}, ScreenGui)
corner(MiniIcon, 12)
local MiniStroke = stroke(MiniIcon, Theme.Accent, 1.2, 0.35)
new("Frame", {
    BackgroundColor3 = Theme.Accent,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 12, 0.5, -5),
    Size = UDim2.new(0, 10, 0, 10),
    ZIndex = 101,
}, MiniIcon)
corner(MiniIcon:FindFirstChildWhichIsA("Frame"), 999)
new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 30, 0, 0),
    Size = UDim2.new(1, -38, 1, 0),
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    Text = "BALTIKA HUB",
    TextColor3 = P.TextWhite,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 101,
}, MiniIcon)

bindAccent(function(c)
    MiniStroke.Color = c
    local dot = MiniIcon:FindFirstChildWhichIsA("Frame")
    if dot and dot:IsA("Frame") then dot.BackgroundColor3 = c end
    local grad = LogoMark:FindFirstChildOfClass("UIGradient")
    if grad then grad.Color = ColorSequence.new(lighten(c, 0.22), darken(c, 0.15)) end
    LogoMark.BackgroundColor3 = c
    LogoGrad.Color = ColorSequence.new(lighten(c, 0.22), darken(c, 0.15))
    Brand.Text = "BALTIKA <font color=\"" .. hexColor(c) .. "\">HUB</font>"
    BrandBadge.BackgroundColor3 = c
    local badgeLabel = BrandBadge:FindFirstChildOfClass("TextLabel")
    if badgeLabel then badgeLabel.TextColor3 = lighten(c, 0.62) end
    MainStroke.Color = darken(c, 0.72)
end)

--===========================================================================
--  ПЕРЕТАСКИВАНИЕ
--===========================================================================
local function makeDraggable(frame, handle, onMoved)
    local dragging, dragStart, startPos, moved = false, nil, nil, false
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = false
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - dragStart
        if math.abs(delta.X) + math.abs(delta.Y) > 3 then moved = true end
        local s = currentScale > 0 and currentScale or 1
        frame.Position = UDim2.new(0, startPos.X.Offset + delta.X / s, 0, startPos.Y.Offset + delta.Y / s)
        clampToScreen(frame, 4)
        if onMoved then onMoved() end
    end)
    return function() return moved end
end

makeDraggable(MainFrame, DragArea)

--===========================================================================
--  СВОРАЧИВАНИЕ / ФУЛЛСКРИН / ЗАКРЫТИЕ / РЕСАЙЗ
--===========================================================================
local function setMinimized(value)
    minimized = value and true or false
    MinimizeBtn.Text = minimized and "▲" or "▼"
    FullscreenBtn.Visible = (not minimized) and (not mobileMode)
    if mobileMode then setDrawer(false, true) end
    applyModeSize(false)
    clampToScreen(MainFrame, 4)
end

MinimizeBtn.MouseButton1Click:Connect(function()
    setMinimized(not minimized)
end)

FullscreenBtn.MouseButton1Click:Connect(function()
    fullscreen = not fullscreen
    FullscreenBtn.TextColor3 = fullscreen and Theme.AccentGlow or P.TextMuted
    applyModeSize(false)
    clampToScreen(MainFrame, 4)
end)

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

-- если окно открыли/закрыли извне (кейбиндом, например) — мини-кнопка догоняет
MainFrame:GetPropertyChangedSignal("Visible"):Connect(function()
    MiniIcon.Visible = not MainFrame.Visible
    if MiniIcon.Visible then
        clampToScreen(MiniIcon, 8)
    end
end)

local function openWindow()
    MiniIcon.Visible = false
    MainFrame.Visible = true
    applyModeSize(true)
    if mobileMode then
        MainFrame.Position = UDim2.new(0, 3, 0, 3)
    else
        clampToScreen(MainFrame, 4)
    end
    updateScale()
end

local miniMoved = makeDraggable(MiniIcon, MiniIcon)
MiniIcon.MouseButton1Click:Connect(function()
    if miniMoved() then return end
    openWindow()
end)

MenuBtn.MouseButton1Click:Connect(function()
    setDrawer(not drawerOpen)
end)

-- ресайз окна мышкой (только десктоп)
local ResizeHandle = new("TextButton", {
    Name = "Resize",
    BackgroundColor3 = Theme.Accent,
    BackgroundTransparency = 0.88,
    Text = "",
    AutoButtonColor = false,
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -4, 1, -4),
    Size = UDim2.new(0, 26, 0, 26),
    Visible = not mobileMode,
    ZIndex = 30,
}, MainFrame)
corner(ResizeHandle, 8)
for i = 0, 2 do
    for j = 0, 2 do
        if i + j >= 2 then
            new("Frame", {
                BackgroundColor3 = Theme.AccentGlow,
                BorderSizePixel = 0,
                Position = UDim2.new(0, 6 + i * 6, 0, 6 + j * 6),
                Size = UDim2.new(0, 3, 0, 3),
                ZIndex = 31,
            }, ResizeHandle)
        end
    end
end
bindAccent(function(c)
    ResizeHandle.BackgroundColor3 = c
    for _, d in ipairs(ResizeHandle:GetChildren()) do
        if d:IsA("Frame") then d.BackgroundColor3 = lighten(c, 0.4) end
    end
end)

local resizing, resizeStart, resizeBase = false, nil, nil
ResizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        resizing = true
        resizeStart = input.Position
        resizeBase = Vector2.new(MainFrame.Size.X.Offset, MainFrame.Size.Y.Offset)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if not resizing then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local delta = input.Position - resizeStart
    local s = currentScale > 0 and currentScale or 1
    local scr = screenDesign()
    local w = math.clamp(resizeBase.X + delta.X / s, 560, scr.X - 20)
    local h = math.clamp(resizeBase.Y + delta.Y / s, 340, scr.Y - 20)
    MainFrame.Size = UDim2.new(0, math.floor(w), 0, math.floor(h))
    desktopSize = Vector2.new(math.floor(w), math.floor(h))
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        if resizing then
            resizing = false
            relayoutAllPages()
        end
    end
end)
--===========================================================================
--  ПЕРЕСЧЁТ МАСШТАБА
--===========================================================================
updateScale = function()
    local vp = viewportPx()
    local base
    if mobileMode then
        base = math.clamp(math.min(vp.X / 430, vp.Y / 840) * 1.25, 0.8, 1.32)
    else
        base = math.clamp(math.min(vp.X / 1180, vp.Y / 760), 0.72, 1.12)
    end
    currentScale = base * userScale
    UIScale.Scale = currentScale
    applyModeSize(true)
    updateNotifyHolder()
    if MiniIcon and MiniIcon.Visible then
        clampToScreen(MiniIcon, 8)
    end
    if MainFrame.Visible and not mobileMode then
        clampToScreen(MainFrame, 4)
    end
end

--===========================================================================
--  ПЕРЕКЛЮЧЕНИЕ РЕЖИМА (десктоп <-> мобилка)
--===========================================================================
local function setMobileLayout(flag, save)
    flag = flag and true or false
    mobileMode = flag
    sideW = flag and SIDE_W_MOBILE or SIDE_W_DESKTOP

    Sidebar.Size = UDim2.new(0, sideW, 1, -TOPBAR_H)
    Sidebar.ZIndex = flag and 40 or 6
    SideDivider.Position = UDim2.new(0, sideW - 1, 0, TOPBAR_H)
    SideDivider.Visible = not flag

    MenuBtn.Visible = flag
    FullscreenBtn.Visible = (not flag) and (not minimized)
    ResizeHandle.Visible = not flag

    LogoMark.Position = flag and UDim2.new(0, 44, 0.5, -11) or UDim2.new(0, 14, 0.5, -11)
    Brand.Position = flag and UDim2.new(0, 72, 0, 0) or UDim2.new(0, 42, 0, 0)
    BrandBadge.Position = flag and UDim2.new(0, 178, 0.5, -7) or UDim2.new(0, 148, 0.5, -7)
    DragArea.Size = flag and UDim2.new(0, 0, 0, 0) or UDim2.new(1, -180, 1, 0)

    if flag then
        ContentArea.Position = UDim2.new(0, 0, 0, TOPBAR_H)
        ContentArea.Size = UDim2.new(1, 0, 1, -TOPBAR_H)
    else
        ContentArea.Position = UDim2.new(0, sideW, 0, TOPBAR_H)
        ContentArea.Size = UDim2.new(1, -sideW, 1, -TOPBAR_H)
    end

    -- сначала масштаб/размер окна: раскладка колонок зависит от доступной ширины
    updateScale()

    for _, t in ipairs(Tabs) do
        t.btn.Size = UDim2.new(1, -14, 0, tabRowHeight())
        applyPageLayout(t.page)
    end

    setDrawer(false, true)

    if save then
        Config.uiMobile = flag and "on" or "off"
        if BHUB.SaveConfig then pcall(BHUB.SaveConfig) end
    end
end

BHUB.setMobileLayout = setMobileLayout
BHUB.isMobileLayout = function() return mobileMode end
BHUB.selectTab = selectTab
BHUB.updateScale = updateScale
BHUB.MainFrame = MainFrame
BHUB.Sidebar = Sidebar
BHUB.ContentArea = ContentArea
BHUB.UIScale = UIScale
BHUB.MiniIcon = MiniIcon
BHUB.DrawerOverlay = DrawerOverlay

--===========================================================================
--  СЕКЦИЯ (карточка с заголовком)
--===========================================================================
local function AddSection(parent, title)
    local sec = new("Frame", {
        Name = "Section_" .. tostring(title),
        BackgroundColor3 = P.BgCard,
        BackgroundTransparency = 0.12,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 8,
    }, parent)
    corner(sec, 13)
    stroke(sec, P.BorderSoft, 1)

    local lay = vlist(sec, 6, Enum.HorizontalAlignment.Center)

    local header = new("Frame", {
        Name = "Header",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -8, 0, 34),
        LayoutOrder = -100,
        ZIndex = 9,
    }, sec)

    local dot = new("Frame", {
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 10, 0.5, -4),
        Size = UDim2.new(0, 8, 0, 8),
        ZIndex = 10,
    }, header)
    corner(dot, 999)

    local titleLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 26, 0, 0),
        Size = UDim2.new(1, -70, 1, 0),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        Text = string.upper(tostring(title)),
        TextColor3 = P.TextWhite,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 10,
    }, header)

    local chevron = new("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.new(0, 16, 0, 16),
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        Text = "−",
        TextColor3 = P.TextDim,
        ZIndex = 10,
    }, header)

    local hit = new("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 11,
    }, header)

    local open = true
    local function setOpen(value)
        open = value and true or false
        chevron.Text = open and "−" or "+"
        chevron.TextColor3 = open and P.TextDim or Theme.AccentGlow
        for _, ch in ipairs(sec:GetChildren()) do
            if ch ~= header and ch:IsA("GuiObject") then
                ch.Visible = open
            end
        end
    end

    sec.ChildAdded:Connect(function(ch)
        if ch ~= header and ch:IsA("GuiObject") and not open then
            ch.Visible = false
        end
    end)

    hit.MouseButton1Click:Connect(function()
        setOpen(not open)
    end)

    -- нижний отступ карточки
    new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -8, 0, 6),
        LayoutOrder = 900,
        ZIndex = 8,
    }, sec)

    bindAccent(function(c)
        dot.BackgroundColor3 = c
    end)

    sec._setOpen = setOpen
    return sec
end

--===========================================================================
--  ТУМБЛЕР
--===========================================================================
local function AddToggle(parent, text, cb, init)
    local row = new("TextButton", {
        Name = "Toggle_" .. tostring(text),
        BackgroundColor3 = P.BgCardHover,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.new(1, -8, 0, 40),
        ZIndex = 9,
    }, parent)
    corner(row, 10)

    local label = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -92, 1, 0),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        Text = tostring(text),
        TextColor3 = P.TextWhite,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 10,
    }, row)

    local pill = new("Frame", {
        BackgroundColor3 = P.ToggleOff,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.new(0, 46, 0, 26),
        ZIndex = 10,
    }, row)
    corner(pill, 999)
    local pillStroke = stroke(pill, Theme.Accent, 1, 1)

    local knob = new("Frame", {
        BackgroundColor3 = P.TextWhite,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 13, 0.5, 0),
        Size = UDim2.new(0, 20, 0, 20),
        ZIndex = 11,
    }, pill)
    corner(knob, 999)

    local state = false
    local function render(instant)
        local time = instant and 0.01 or 0.18
        tw(knob, time, { Position = state and UDim2.new(0, 33, 0.5, 0) or UDim2.new(0, 13, 0.5, 0) })
        tw(pill, time, { BackgroundColor3 = state and Theme.Accent or P.ToggleOff })
        tw(pillStroke, time, { Transparency = state and 0 or 1 })
        tw(label, time, { TextColor3 = state and P.TextWhite or lighten(P.TextWhite, -0.18) })
    end

    local function setState(value, fire)
        state = value and true or false
        render()
        if fire ~= false and cb then cb(state) end
    end

    row.MouseButton1Click:Connect(function()
        setState(not state)
    end)
    row.MouseEnter:Connect(function()
        tw(row, 0.15, { BackgroundTransparency = 0.55 })
    end)
    row.MouseLeave:Connect(function()
        tw(row, 0.15, { BackgroundTransparency = 1 })
    end)

    bindAccent(function(c)
        pillStroke.Color = c
        if state then
            pill.BackgroundColor3 = c
        end
    end)

    if init then
        setState(true, false)
    end

    return {
        setState = setState,
        getState = function() return state end,
    }
end

--===========================================================================
--  СЛАЙДЕР
--===========================================================================
local function AddSlider(parent, text, mn, mx, def, cb)
    mn = tonumber(mn) or 0
    mx = tonumber(mx) or 100
    if mx <= mn then mx = mn + 1 end
    def = math.clamp(tonumber(def) or mn, mn, mx)

    local row = new("Frame", {
        Name = "Slider_" .. tostring(text),
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -8, 0, 56),
        ZIndex = 9,
    }, parent)

    local label = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 8),
        Size = UDim2.new(1, -108, 0, 16),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        Text = tostring(text),
        TextColor3 = P.TextWhite,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 10,
    }, row)

    local valuePill = new("Frame", {
        BackgroundColor3 = P.BgInput,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, 5),
        Size = UDim2.new(0, 54, 0, 21),
        ZIndex = 10,
    }, row)
    corner(valuePill, 7)
    local valueStroke = stroke(valuePill, P.BorderSoft, 1)

    local valueLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        Text = tostring(def),
        TextColor3 = Theme.AccentGlow,
        ZIndex = 11,
    }, valuePill)

    local track = new("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Position = UDim2.new(0, 10, 0, 32),
        Size = UDim2.new(1, -20, 0, 18),
        ZIndex = 11,
    }, row)

    local bar = new("Frame", {
        BackgroundColor3 = P.ToggleOff,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0.5, -3),
        Size = UDim2.new(1, 0, 0, 6),
        ZIndex = 11,
    }, track)
    corner(bar, 3)

    local fill = new("Frame", {
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 1, 0),
        ZIndex = 12,
    }, bar)
    corner(fill, 3)
    local fillGrad = gradient(fill, lighten(Theme.Accent, 0.18), Theme.Accent, 0)

    local glow = new("Frame", {
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 0.94,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 26, 0, 26),
        ZIndex = 13,
    }, track)
    corner(glow, 999)

    local knob = new("Frame", {
        BackgroundColor3 = P.TextWhite,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 16, 0, 16),
        ZIndex = 14,
    }, track)
    corner(knob, 999)
    local knobStroke = stroke(knob, Theme.Accent, 2)

    local value = math.floor(def + 0.5)
    local lastFired = nil
    local dragging = false

    local function setValue(v, fire)
        v = math.clamp(tonumber(v) or mn, mn, mx)
        local rounded = math.floor(v + 0.5)
        local p = (rounded - mn) / (mx - mn)
        value = rounded
        fill.Size = UDim2.new(p, 0, 1, 0)
        knob.Position = UDim2.new(p, 0, 0.5, 0)
        glow.Position = UDim2.new(p, 0, 0.5, 0)
        valueLabel.Text = tostring(rounded)
        if fire ~= false and cb and rounded ~= lastFired then
            lastFired = rounded
            cb(rounded)
        end
    end

    local function valueFromX(x)
        local absX = bar.AbsolutePosition.X
        local w = bar.AbsoluteSize.X
        if w <= 0 then return end
        local p = math.clamp((x - absX) / w, 0, 1)
        setValue(mn + (mx - mn) * p)
    end

    local function pointerX(input)
        if input and (input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseMovement) then
            return input.Position.X
        end
        return UserInputService:GetMouseLocation().X
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            valueFromX(pointerX(input))
            tw(knob, 0.1, { Size = UDim2.new(0, 20, 0, 20) })
            tw(glow, 0.1, { BackgroundTransparency = 0.82 })
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        valueFromX(pointerX(input))
    end)
    UserInputService.InputEnded:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            tw(knob, 0.14, { Size = UDim2.new(0, 16, 0, 16) })
            tw(glow, 0.14, { BackgroundTransparency = 0.94 })
        end
    end)
    track.MouseEnter:Connect(function()
        if not dragging then tw(glow, 0.15, { BackgroundTransparency = 0.88 }) end
    end)
    track.MouseLeave:Connect(function()
        if not dragging then tw(glow, 0.15, { BackgroundTransparency = 0.94 }) end
    end)

    bindAccent(function(c)
        fill.BackgroundColor3 = c
        fillGrad.Color = ColorSequence.new(lighten(c, 0.18), c)
        glow.BackgroundColor3 = c
        knobStroke.Color = c
        valueLabel.TextColor3 = lighten(c, 0.4)
        valueStroke.Color = darken(c, 0.55)
    end)

    setValue(value, false)

    return {
        setValue = setValue,
        getValue = function() return value end,
        frame = row,
    }
end

--===========================================================================
--  КНОПКА
--===========================================================================
local function AddButton(parent, text, special, cb)
    local btn = new("TextButton", {
        Name = "Button_" .. tostring(text),
        BackgroundColor3 = P.BgInput,
        BorderSizePixel = 0,
        Text = tostring(text),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = P.TextWhite,
        TextTruncate = Enum.TextTruncate.AtEnd,
        AutoButtonColor = false,
        Size = UDim2.new(1, -8, 0, 40),
        ZIndex = 10,
    }, parent)
    corner(btn, 10)

    local btnStroke = stroke(btn, P.BorderSoft, 1)

    local hover = new("Frame", {
        Name = "Hover",
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 9,
    }, btn)
    corner(hover, 10)

    if special then
        btn.BackgroundTransparency = 1
        local bg = new("Frame", {
            Name = "Bg",
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 8,
        }, btn)
        corner(bg, 10)
        local bgGrad = gradient(bg, lighten(Theme.Accent, 0.12), darken(Theme.Accent, 0.28), 15)
        bindAccent(function(c)
            bg.BackgroundColor3 = c
            bgGrad.Color = ColorSequence.new(lighten(c, 0.12), darken(c, 0.28))
            btnStroke.Color = lighten(c, 0.25)
            btnStroke.Transparency = 0.35
        end)
    else
        bindAccent(function(c)
            btnStroke.Color = P.BorderSoft
        end)
    end

    local scale = new("UIScale", { Scale = 1 }, btn)

    btn.MouseEnter:Connect(function()
        tw(hover, 0.15, { BackgroundTransparency = special and 0.86 or 0.94 })
        if not special then
            tw(btnStroke, 0.15, { Color = P.Border })
        end
    end)
    btn.MouseLeave:Connect(function()
        tw(hover, 0.15, { BackgroundTransparency = 1 })
        if not special then
            tw(btnStroke, 0.15, { Color = P.BorderSoft })
        end
    end)
    btn.MouseButton1Down:Connect(function()
        tw(scale, 0.08, { Scale = 0.98 })
    end)
    btn.MouseButton1Up:Connect(function()
        tw(scale, 0.12, { Scale = 1 })
    end)
    btn.MouseButton1Click:Connect(function()
        tw(scale, 0.12, { Scale = 1 })
        if cb then
            local ok, err = pcall(cb)
            if not ok then
                warn("[BALTIKA] button error: " .. tostring(err))
            end
        end
    end)

    return btn
end

--===========================================================================
--  ТЕКСТОВОЕ ПОЛЕ
--===========================================================================
local function AddTextBox(parent, placeholder, height, cb)
    height = tonumber(height) or 38
    local multiline = height >= 60

    local box = new("TextBox", {
        Name = "TextBox",
        BackgroundColor3 = P.BgInput,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -8, 0, height),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        Text = "",
        TextColor3 = P.TextWhite,
        PlaceholderText = tostring(placeholder or ""),
        PlaceholderColor3 = P.TextDim,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
        MultiLine = multiline,
        TextWrapped = multiline,
        ZIndex = 10,
    }, parent)
    corner(box, 10)
    padding(box, 6, 6, 10, 10)
    local boxStroke = stroke(box, P.BorderSoft, 1)

    box.Focused:Connect(function()
        tw(boxStroke, 0.16, { Color = Theme.Accent, Transparency = 0.15 })
        tw(box, 0.16, { BackgroundColor3 = P.BgBottom })
    end)
    box.FocusLost:Connect(function()
        tw(boxStroke, 0.16, { Color = P.BorderSoft, Transparency = 0 })
        tw(box, 0.16, { BackgroundColor3 = P.BgInput })
    end)
    bindAccent(function(c)
        if box:IsFocused() then
            boxStroke.Color = c
        end
    end)

    if cb then
        box:GetPropertyChangedSignal("Text"):Connect(function()
            local ok, err = pcall(cb, box.Text)
            if not ok then
                warn("[BALTIKA] textbox error: " .. tostring(err))
            end
        end)
    end

    return box
end

--===========================================================================
--  КЕЙБИНД
--===========================================================================
local keybindButtons = {}
local keybindMeta = {}
local awaitingKeybindAction = nil

local function AddKeybind(parent, labelText, actionKey)
    local row = new("Frame", {
        Name = "Keybind_" .. tostring(labelText),
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -8, 0, 40),
        ZIndex = 9,
    }, parent)

    local label = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -122, 1, 0),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        Text = tostring(labelText),
        TextColor3 = P.TextWhite,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 10,
    }, row)

    local pill = new("TextButton", {
        BackgroundColor3 = P.BgInput,
        Text = "None",
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = Theme.AccentGlow,
        AutoButtonColor = false,
        TextTruncate = Enum.TextTruncate.AtEnd,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.new(0, 100, 0, 28),
        ZIndex = 10,
    }, row)
    corner(pill, 8)
    local pillStroke = stroke(pill, P.BorderSoft, 1)

    keybindButtons[actionKey] = pill
    keybindMeta[actionKey] = { pill = pill, stroke = pillStroke }

    pill.MouseEnter:Connect(function()
        if BHUB.getAwaitingKeybind() ~= actionKey then
            tw(pillStroke, 0.15, { Color = Theme.Accent, Transparency = 0.4 })
        end
    end)
    pill.MouseLeave:Connect(function()
        if BHUB.getAwaitingKeybind() ~= actionKey then
            tw(pillStroke, 0.15, { Color = P.BorderSoft, Transparency = 0 })
        end
    end)
    pill.MouseButton1Click:Connect(function()
        if awaitingKeybindAction == actionKey then
            awaitingKeybindAction = nil
            if BHUB.setAwaitingKeybind then BHUB.setAwaitingKeybind(nil) end
            return
        end
        awaitingKeybindAction = actionKey
        if BHUB.setAwaitingKeybind then BHUB.setAwaitingKeybind(actionKey) end
    end)

    bindAccent(function(c)
        local meta = keybindMeta[actionKey]
        if meta then
            meta.lastText = nil
        end
    end)

    return {
        button = pill,
        label = label,
    }
end
--===========================================================================
--  ЭКСПОРТ API (для inject.lua и остальных модулей)
--===========================================================================
BHUB.AddTab = AddTab
BHUB.AddSection = AddSection
BHUB.AddToggle = AddToggle
BHUB.AddSlider = AddSlider
BHUB.AddButton = AddButton
BHUB.AddTextBox = AddTextBox
BHUB.AddKeybind = AddKeybind
BHUB.keybindButtons = keybindButtons
BHUB.getAwaitingKeybind = function() return awaitingKeybindAction end
BHUB.setAwaitingKeybind = function(v)
    awaitingKeybindAction = v
    if v == nil then
        for _, meta in pairs(keybindMeta) do
            tw(meta.stroke, 0.15, { Color = P.BorderSoft, Transparency = 0 })
        end
    end
end

--===========================================================================
--  ВКЛАДКИ
--===========================================================================
local MoveLeft, MoveRight = AddTab("Movement", false)
local FlingLeft, FlingRight = AddTab("Fling & Combat", false)
local VisLeft, VisRight = AddTab("Visuals & Misc", false)
local SetLeft, SetRight = AddTab("Settings & Binds", false)

--===========================================================================
--  ИНТЕРФЕЙС (настройки UI)
--===========================================================================
local UiSec = AddSection(SetLeft, "Interface")

local mobileToggle = AddToggle(UiSec, "Compact mobile layout", function(v)
    setMobileLayout(v, true)
    Notify(v and "Mobile layout enabled" or "Desktop layout enabled", "info", "Interface")
end, mobileMode)

AddButton(UiSec, "Auto-detect device", false, function()
    local detected = detectMobile()
    if detected == mobileMode then
        Notify("Already fits this device", "info", "Interface")
    end
    mobileToggle.setState(detected)
end)

AddSlider(UiSec, "Interface scale, %", 60, 140, math.floor(userScale * 100 + 0.5), function(v)
    userScale = math.clamp(v / 100, 0.6, 1.4)
    Config.uiScale = v
    updateScale()
end)

AddButton(UiSec, "Center window on screen", false, function()
    local scr = screenDesign()
    local w, h = MainFrame.Size.X.Offset, MainFrame.Size.Y.Offset
    MainFrame.Position = UDim2.new(0, math.max(4, math.floor((scr.X - w) / 2)),
                                   0, math.max(4, math.floor((scr.Y - h) / 2)))
    clampToScreen(MainFrame, 4)
end)

local AccentSec = AddSection(SetLeft, "Accent color")
local swatchRow = new("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -8, 0, 36),
    ZIndex = 9,
}, AccentSec)
hlist(swatchRow, 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)

local ACCENTS = {
    Color3.fromRGB(124, 92, 255),
    Color3.fromRGB(56, 162, 255),
    Color3.fromRGB(48, 209, 152),
    Color3.fromRGB(255, 92, 148),
    Color3.fromRGB(255, 174, 60),
    Color3.fromRGB(255, 88, 96),
}
local swatches = {}
local refreshAccentSwatches = function() end

for i, color in ipairs(ACCENTS) do
    local sw = new("TextButton", {
        BackgroundColor3 = color,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.new(0, 28, 0, 28),
        LayoutOrder = i,
        ZIndex = 10,
    }, swatchRow)
    corner(sw, 999)
    local ring = stroke(sw, Color3.new(1, 1, 1), 2, 1)
    table.insert(swatches, { btn = sw, color = color, ring = ring })

    sw.MouseEnter:Connect(function()
        tw(sw, 0.15, { Size = UDim2.new(0, 30, 0, 30) })
    end)
    sw.MouseLeave:Connect(function()
        tw(sw, 0.15, { Size = UDim2.new(0, 28, 0, 28) })
    end)
    sw.MouseButton1Click:Connect(function()
        setAccent(color, true)
        refreshAccentSwatches()
        Notify("Accent updated", "success", "Interface")
    end)
end

refreshAccentSwatches = function()
    for _, item in ipairs(swatches) do
        local isActive = packColor(item.color) == appliedAccentPack
        item.ring.Transparency = isActive and 0 or 1
    end
end
refreshAccentSwatches()

--===========================================================================
--  MOVEMENT
--===========================================================================
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

--===========================================================================
--  FLING & COMBAT
--===========================================================================
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

--===========================================================================
--  VISUALS & MISC
--===========================================================================
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
AddButton(MiscSec, "Kill Character (Perma)", false, function()
    if BHUB.permaKillCharacter then BHUB.permaKillCharacter() end
end)

--===========================================================================
--  БИНДЫ
--===========================================================================
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
    if BHUB.SaveConfig then pcall(BHUB.SaveConfig) end
    Notify("Config saved to file", "success", "BALTIKA HUB")
end)

--===========================================================================
--  СИНХРОНИЗАЦИЯ КЕЙБИНДОВ
--===========================================================================
local function refreshKeybindPills()
    local awaiting = awaitingKeybindAction
    for action, pill in pairs(keybindButtons) do
        local meta = keybindMeta[action]
        if meta then
            local key = keybinds[action]
            local name = (key and key ~= Enum.KeyCode.Unknown) and key.Name or "None"
            local waiting = (awaiting == action)
            local wantText = waiting and "press key" or name
            if meta.lastText ~= wantText or meta.lastWaiting ~= waiting then
                meta.lastText = wantText
                meta.lastWaiting = waiting
                pill.Text = wantText
                if waiting then
                    pill.BackgroundColor3 = Theme.Accent
                    pill.TextColor3 = Color3.new(1, 1, 1)
                    tw(meta.stroke, 0.15, { Color = Theme.AccentGlow, Transparency = 0 })
                else
                    pill.BackgroundColor3 = P.BgInput
                    pill.TextColor3 = lighten(Theme.Accent, 0.4)
                    tw(meta.stroke, 0.15, { Color = P.BorderSoft, Transparency = 0 })
                end
            end
        end
    end
end

task.spawn(function()
    while true do
        task.wait(0.2)
        pcall(refreshKeybindPills)
    end
end)

--===========================================================================
--  СТАРТОВОЕ СОСТОЯНИЕ
--===========================================================================
selectTab(1)

-- применяем выбранный режим (важно для мобилок: бургер, drawer, одна колонка)
setMobileLayout(mobileMode, false)

if mobileMode then
    MainFrame.Position = UDim2.new(0, 3, 0, 3)
else
    local scr = screenDesign()
    MainFrame.Position = UDim2.new(0, math.max(8, math.floor((scr.X - MainFrame.Size.X.Offset) / 2)),
                                   0, math.max(8, math.floor((scr.Y - MainFrame.Size.Y.Offset) / 2)))
    clampToScreen(MainFrame, 4)
end
setDrawer(false, true)

pcall(function()
    ScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        updateScale()
    end)
end)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    task.wait(0.1)
    pcall(updateScale)
end)
if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        pcall(updateScale)
    end)
end

-- подхватываем значения, если конфиг загрузился позже
task.spawn(function()
    while true do
        task.wait(0.5)
        if not MainFrame or not MainFrame.Parent then break end

        local sc = tonumber(Config.uiScale)
        if sc and math.abs(sc - userScale * 100) > 0.5 then
            userScale = math.clamp(sc / 100, 0.6, 1.4)
            updateScale()
        end

        local ac = tonumber(Config.uiAccent)
        if ac and ac ~= appliedAccentPack then
            setAccent(unpackColor(ac), false)
            refreshAccentSwatches()
        end

        if (Config.uiMobile == "on" or Config.uiMobile == "off") then
            local want = (Config.uiMobile == "on")
            if want ~= mobileMode then
                setMobileLayout(want, false)
                if mobileToggle then mobileToggle.setState(want, false) end
            end
        end
    end
end)

LinkBtn.MouseButton1Click:Connect(function()
    local link = "https://t.me/BALTIKA_HUB"
    if setclipboard then pcall(setclipboard, link) end
    Notify("Link copied: " .. link, "info", "Socials")
end)

LinkBtn.MouseEnter:Connect(function()
    tw(LinkBtn, 0.15, { BackgroundTransparency = 0.15 })
end)
LinkBtn.MouseLeave:Connect(function()
    tw(LinkBtn, 0.15, { BackgroundTransparency = 0.4 })
end)

Notify(mobileMode and "Loaded • mobile layout" or "Loaded • desktop layout", "success", "BALTIKA HUB")
print("[BALTIKA HUB NEW] UI v2 ready (" .. (mobileMode and "mobile" or "desktop") .. ", scale " ..
    tostring(math.floor(currentScale * 100)) .. "%)")
