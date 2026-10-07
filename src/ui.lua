--[[ ==========================================================================
     BALTIKA HUB  •  UI v3   (интерфейс переписан с нуля)
     --------------------------------------------------------------------------
     Что изменилось по сравнению с прошлой версией:

       • СВОЙ ДВИЖОК РАСКЛАДКИ. Все позиции и высоты считаются в Lua без
         AutomaticSize/AbsoluteContentSize. Карточки больше не наезжают друг
         на друга, скролл всегда правильный, ничего не обрезается.

       • СЕКЦИИ ПРИНИМАЮТ «ЧУЖИЕ» ЭЛЕМЕНТЫ. Терминал и список файлов из
         inject.lua имеют собственные Position/Size — секция сама ставит их
         ниже своих виджетов, без наложений.

       • ОКНО ВСЕГДА ВЛЕЗАЕТ В ЭКРАН. Размер считается от реальной рабочей
         области, позиция зажимается по границам, сторож раз в 0.4 с
         проверяет поворот/смену размера и перестраивает окно.

       • КОМПАКТНЫЙ РЕЖИМ ДЛЯ ТЕЛЕФОНОВ. Шторка-меню, один столбец, крупные
         кнопки, уведомления снизу. Оба столбца складываются друг под друга —
         ни одна настройка не пропадает.

       • Свёрнутое окно прячет всё, кроме верхней панели.

     Функционал и API для fun_main.lua / inject.lua сохранены 1:1:
       AddTab / AddSection / AddToggle / AddSlider / AddButton / AddTextBox /
       AddKeybind, MainFrame / Sidebar / ContentArea / UIScale / updateScale /
       getAwaitingKeybind / setAwaitingKeybind / keybindButtons /
       FovCircle / FovStroke / Notify / setMobileLayout / isMobileLayout
     ========================================================================== ]]

local BHUB = _G.BHUB
if not BHUB then
    warn("[BALTIKA] ui.lua: ядро не загружено (нужны config.lua и utils.lua)")
    return
end

-- вперёд объявленные вещи (заполняются ниже по файлу)
local Layout
local desktopSize = Vector2.new(760, 500)

local Config    = BHUB.Config
local keybinds  = BHUB.keybinds
local player    = BHUB.player
local Theme     = BHUB.Theme
local ScreenGui = BHUB.ScreenGui

local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")

-- вперёд объявленные вещи, которые заполняются ниже по файлу
local Tabs = {}          -- вкладки (заполняет часть со вкладками)
local selectedTab = 0
local refreshLayout      -- пересчёт раскладки (определяется в движке)
local selectTab          -- выбор вкладки
local tabRowH            -- высота строки вкладки
local mobileToggle       -- тумблер компактного режима

--=== ПАЛИТРА ================================================================
local P = {
    BgTop       = Color3.fromRGB(21, 21, 29),
    BgMain      = Color3.fromRGB(16, 16, 22),
    BgBottom    = Color3.fromRGB(11, 11, 16),
    BgSidebar   = Color3.fromRGB(13, 13, 18),
    BgCard      = Color3.fromRGB(23, 23, 31),
    BgCardHover = Color3.fromRGB(31, 31, 42),
    BgInput     = Color3.fromRGB(19, 19, 26),
    ToggleOff   = Color3.fromRGB(42, 42, 56),
    Border      = Color3.fromRGB(42, 42, 57),
    BorderSoft  = Color3.fromRGB(31, 31, 42),
    Divider     = Color3.fromRGB(28, 28, 38),
    TextWhite   = Color3.fromRGB(240, 241, 248),
    TextMuted   = Color3.fromRGB(140, 142, 164),
    TextDim     = Color3.fromRGB(96, 98, 120),
    Success     = Color3.fromRGB(64, 214, 143),
    Error       = Color3.fromRGB(255, 88, 96),
    Warning     = Color3.fromRGB(255, 186, 84),
}
for k, v in pairs(P) do Theme[k] = v end

local DEFAULT_ACCENT = Color3.fromRGB(124, 92, 255)

--===========================================================================
--  ХЕЛПЕРЫ
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
    s.Color = color or P.BorderSoft
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

local function vlist(obj, pad, halign, valign)
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Vertical
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Padding = UDim.new(0, pad or 0)
    l.HorizontalAlignment = halign or Enum.HorizontalAlignment.Center
    if valign then l.VerticalAlignment = valign end
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
    if not obj then return end
    local t = TweenService:Create(obj,
        TweenInfo.new(time or 0.16, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out), props)
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
--  ИКОНКИ (рисуются из примитивов — без эмодзи и текстовых символов)
--===========================================================================
local ICON_THICK = 1.6

local function iconPart(box, color, w, h, x, y, rot, radius)
    local p = new("Frame", {
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, x, 0.5, y),
        Size = UDim2.new(0, w, 0, h),
        Rotation = rot or 0,
    }, box)
    if radius then corner(p, radius) end
    return p
end

local function iconRing(box, color, w, h, thickness, x, y, radius)
    local f = new("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, x or 0, 0.5, y or 0),
        Size = UDim2.new(0, w, 0, h),
    }, box)
    corner(f, radius or math.max(w, h))
    local s = stroke(f, color, thickness or ICON_THICK)
    return f, s
end

-- Возвращает контейнер, список «красимых» частей и функцию перекраски.
local function drawIcon(parent, kind, size, color, zIndex)
    color = color or P.TextWhite
    local box = new("Frame", {
        Name = "Icon_" .. tostring(kind),
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, size, 0, size),
        ZIndex = zIndex or 12,
    }, parent)

    local S = size
    local paint = {}   -- {obj = ..., kind = "fill"|"stroke"}

    local function fill(w, h, x, y, rot, radius)
        local p = iconPart(box, color, w, h, x, y, rot, radius)
        table.insert(paint, { obj = p, kind = "fill" })
        return p
    end
    local function ring(w, h, thickness, x, y, radius)
        local f, s = iconRing(box, color, w, h, thickness, x, y, radius)
        table.insert(paint, { obj = s, kind = "stroke" })
        return f, s
    end

    if kind == "close" then
        fill(S * 0.54, ICON_THICK, 0, 0, 45, 1)
        fill(S * 0.54, ICON_THICK, 0, 0, -45, 1)
    elseif kind == "minimize" then
        fill(S * 0.5, ICON_THICK, 0, 0, 0, 1)
    elseif kind == "maximize" or kind == "restore" then
        -- «окно»: квадрат со скруглением (полный экран / обычный режим)
        ring(S * 0.52, S * 0.52, ICON_THICK, 0, 0, S * 0.14)
    elseif kind == "zoomOut" or kind == "zoomIn" then
        ring(S * 0.52, S * 0.52, ICON_THICK, -S * 0.07, -S * 0.07)
        fill(S * 0.24, ICON_THICK, -S * 0.07, -S * 0.07, 0, 1)
        if kind == "zoomIn" then
            fill(ICON_THICK, S * 0.24, -S * 0.07, -S * 0.07, 0, 1)
        end
        fill(S * 0.24, ICON_THICK + 0.4, S * 0.22, S * 0.22, 45, 1)
    elseif kind == "chevronDown" or kind == "chevronUp" then
        local dir = (kind == "chevronDown") and 1 or -1
        fill(S * 0.3, ICON_THICK, -S * 0.12, dir * S * 0.05, dir * 42, 1)
        fill(S * 0.3, ICON_THICK, S * 0.12, dir * S * 0.05, -dir * 42, 1)
    elseif kind == "folder" then
        fill(S * 0.32, ICON_THICK, -S * 0.14, -S * 0.14, 0, 1)
        fill(S * 0.62, S * 0.44, 0, S * 0.07, 0, 2)
    elseif kind == "back" then
        fill(S * 0.3, ICON_THICK, -S * 0.05, -S * 0.1, -45, 1)
        fill(S * 0.3, ICON_THICK, -S * 0.05, S * 0.1, 45, 1)
    elseif kind == "refresh" then
        -- кольцо и стрелка-наконечник (обновление списка)
        ring(S * 0.56, S * 0.56, ICON_THICK, 0, 0)
        fill(S * 0.22, S * 0.22, S * 0.2, -S * 0.2, 45, 1)
    elseif kind == "trash" then
        fill(S * 0.56, ICON_THICK, 0, -S * 0.22, 0, 1)
        fill(S * 0.2, ICON_THICK, 0, -S * 0.13, 0, 1)
        ring(S * 0.4, S * 0.42, ICON_THICK - 0.2, 0, S * 0.08, 1.5)
    elseif kind == "dot" then
        local d = fill(S * 0.5, S * 0.5, 0, 0, 0, 999)
        d.BackgroundTransparency = 0
    end

    local function setColor(c)
        for _, item in ipairs(paint) do
            if item.kind == "fill" then
                item.obj.BackgroundColor3 = c
            else
                item.obj.Color = c
            end
        end
    end

    return box, setColor
end

BHUB.DrawIcon = drawIcon


--===========================================================================
--  АКЦЕНТНЫЙ ЦВЕТ
--===========================================================================
local accentBindings = {}

local function bindAccent(fn)
    table.insert(accentBindings, fn)
    pcall(fn, Theme.Accent)
end

local appliedAccentPack = nil

local function setAccent(color, save)
    Theme.Accent     = color
    Theme.AccentGlow = lighten(color, 0.36)
    Theme.AccentDim  = darken(color, 0.45)
    Theme.AccentSoft = lighten(color, 0.74)
    Theme.ToggleOn   = color
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
--  ПАРАМЕТРЫ РАЗМЕТКИ (пересчитываются в applyResponsive)
--===========================================================================
local UI = {
    compact = false,
    scale   = 1,
    rowH    = 42,
    sliderH = 60,
    btnH    = 40,
    headerH = 34,
    gap     = 6,
    padIn   = 10,
    secGap  = 10,
    pagePad = 10,
    colGap  = 12,
    sideW   = 204,
    drawerW = 244,
    topH    = 46,
}

local function applyCompactMetrics()
    if UI.compact then
        UI.rowH, UI.sliderH, UI.btnH, UI.headerH = 46, 64, 44, 36
        UI.gap, UI.secGap, UI.pagePad, UI.colGap = 6, 10, 8, 10
        UI.sideW, UI.drawerW, UI.topH = 0, 246, 48
    else
        UI.rowH, UI.sliderH, UI.btnH, UI.headerH = 42, 60, 40, 34
        UI.gap, UI.secGap, UI.pagePad, UI.colGap = 6, 10, 10, 12
        UI.sideW, UI.drawerW, UI.topH = 204, 244, 46
    end
end

--===========================================================================
--  УВЕДОМЛЕНИЯ
--===========================================================================
local NotifyHolder = new("Frame", {
    Name = "Notifications",
    BackgroundTransparency = 1,
    Size = UDim2.new(0, 268, 0, 320),
    Position = UDim2.new(1, -14, 0, 12),
    ZIndex = 200,
}, ScreenGui)
local notifyLayout = vlist(NotifyHolder, 8, Enum.HorizontalAlignment.Right)

local notifyOrder = 0

local function Notify(message, kind, title)
    if type(message) ~= "string" then message = tostring(message) end

    local color = Theme.Accent
    if kind == "success" then color = P.Success
    elseif kind == "error" then color = P.Error
    elseif kind == "warn" then color = P.Warning end

    notifyOrder = notifyOrder + 1

    local holder = new("Frame", {
        Name = "Toast",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 54),
        LayoutOrder = notifyOrder,
        ZIndex = 201,
    }, NotifyHolder)

    local card = new("Frame", {
        BackgroundColor3 = P.BgCard,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 30, 0, 0),
        ZIndex = 202,
    }, holder)
    corner(card, 12)
    local cardStroke = stroke(card, P.BorderSoft, 1, 1)

    local bar = new("Frame", {
        BackgroundColor3 = color,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 3, 1, -20),
        Position = UDim2.new(0, 10, 0, 10),
        ZIndex = 203,
    }, card)
    corner(bar, 2)

    local t1 = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -32, 0, 15),
        Position = UDim2.new(0, 20, 0, 9),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        Text = string.upper(title or "BALTIKA HUB"),
        TextColor3 = color,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
        ZIndex = 203,
    }, card)

    local t2 = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -32, 0, 15),
        Position = UDim2.new(0, 20, 0, 27),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        Text = message,
        TextColor3 = P.TextMuted,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextTransparency = 1,
        ZIndex = 203,
    }, card)

    tw(card, 0.26, { BackgroundTransparency = 0, Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Quint)
    tw(bar, 0.26, { BackgroundTransparency = 0 })
    tw(t1, 0.26, { TextTransparency = 0 })
    tw(t2, 0.26, { TextTransparency = 0 })
    tw(cardStroke, 0.26, { Transparency = 0 })

    task.delay(3.6, function()
        if not holder.Parent then return end
        tw(card, 0.22, { BackgroundTransparency = 1, Position = UDim2.new(0, 30, 0, 0) })
        tw(bar, 0.22, { BackgroundTransparency = 1 })
        tw(t1, 0.22, { TextTransparency = 1 })
        tw(t2, 0.22, { TextTransparency = 1 })
        tw(cardStroke, 0.22, { Transparency = 1 })
        task.delay(0.3, function()
            if holder and holder.Parent then holder:Destroy() end
        end)
    end)
end

BHUB.Notify = Notify

--===========================================================================
--  FOV КРУГ
--===========================================================================
local FovGui = new("ScreenGui", {
    Name = "BALTIKA_HUB_FOV",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 2,
})
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
stroke(FovInner, Color3.fromRGB(255, 255, 255), 1, 0.82)

bindAccent(function(c)
    FovStroke.Color = c
end)

BHUB.FovCircle = FovCircle
BHUB.FovStroke = FovStroke
BHUB.FovGui = FovGui

--===========================================================================
--  РАБОЧАЯ ОБЛАСТЬ ЭКРАНА
--===========================================================================
local function viewport()
    local ok, abs = pcall(function() return ScreenGui.AbsoluteSize end)
    if ok and abs and abs.X > 40 and abs.Y > 40 then
        return abs
    end
    local cam = workspace.CurrentCamera
    if cam and cam.ViewportSize and cam.ViewportSize.X > 40 then
        return cam.ViewportSize
    end
    return Vector2.new(1280, 720)
end

--===========================================================================
--  ОКНО
--===========================================================================
pcall(function() ScreenGui.DisplayOrder = 20 end)

local MainFrame = new("Frame", {
    Name = "BALTIKA_HUB",
    BackgroundColor3 = P.BgMain,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Active = true,
    AnchorPoint = Vector2.new(0, 0),
    Position = UDim2.new(0, 20, 0, 20),
    Size = UDim2.new(0, 740, 0, 486),
    ZIndex = 5,
    Visible = true,
}, ScreenGui)
corner(MainFrame, 14)
gradient(MainFrame, P.BgMain, P.BgBottom, 90)
local MainStroke = stroke(MainFrame, P.BorderSoft, 1.2)

local UIScale = new("UIScale", { Name = "AdaptiveScale", Scale = 1 }, MainFrame)

local minimized = false
local fullscreen = false

--===========================================================================
--  ВЕРХНЯЯ ПАНЕЛЬ
--===========================================================================
local TopBar = new("Frame", {
    Name = "TopBar",
    BackgroundColor3 = P.BgTop,
    BackgroundTransparency = 0.12,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, UI.topH),
    ZIndex = 6,
}, MainFrame)
gradient(TopBar, P.BgTop, P.BgMain, 90)

local TopDivider = new("Frame", {
    BackgroundColor3 = P.Divider,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, UI.topH - 1),
    Size = UDim2.new(1, 0, 0, 1),
    ZIndex = 7,
}, MainFrame)

local DragArea = new("Frame", {
    Name = "DragArea",
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -180, 1, 0),
    ZIndex = 8,
    Active = true,
}, TopBar)

local LogoMark = new("Frame", {
    Name = "Logo",
    BackgroundColor3 = Theme.Accent,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 14, 0.5, 0),
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
    Size = UDim2.new(0, 170, 1, 0),
    RichText = true,
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    Text = "BALTIKA <font color=\"" .. hexColor(Theme.Accent) .. "\">HUB</font>",
    TextColor3 = P.TextWhite,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 9,
}, TopBar)

-- бургер (компактный режим)
local MenuBtn = new("TextButton", {
    Name = "Menu",
    BackgroundColor3 = P.BgCardHover,
    BackgroundTransparency = 1,
    Text = "",
    AutoButtonColor = false,
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 8, 0.5, 0),
    Size = UDim2.new(0, 30, 0, 30),
    Visible = false,
    ZIndex = 9,
}, TopBar)
corner(MenuBtn, 9)
for i = -1, 1 do
    new("Frame", {
        BackgroundColor3 = P.TextWhite,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, i * 6),
        Size = UDim2.new(0, 14, 0, 2),
        ZIndex = 10,
    }, MenuBtn)
end

-- кнопки окна (иконки рисуются примитивами)
local BtnHolder = new("Frame", {
    BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -10, 0.5, 0),
    Size = UDim2.new(0, 110, 0, 30),
    ZIndex = 9,
}, TopBar)
hlist(BtnHolder, 4, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

local function chromeButton(kind, order, danger)
    local b = new("TextButton", {
        Name = "Chrome_" .. tostring(kind),
        BackgroundColor3 = P.BgCardHover,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.new(0, 28, 0, 28),
        LayoutOrder = order,
        ZIndex = 9,
    }, BtnHolder)
    corner(b, 8)

    local function buildIcon(iconKind)
        for _, ch in ipairs(b:GetChildren()) do
            if ch:IsA("Frame") and tostring(ch.Name):sub(1, 5) == "Icon_" then
                ch:Destroy()
            end
        end
        local _, setColor = drawIcon(b, iconKind, 15, P.TextMuted, 12)
        b.iconColor = setColor
    end

    buildIcon(kind)
    b.setIconKind = buildIcon

    b.MouseEnter:Connect(function()
        pcall(function()
            tw(b, 0.14, { BackgroundTransparency = 0.42 })
            if b.iconColor then b.iconColor(danger and P.Error or P.TextWhite) end
        end)
    end)
    b.MouseLeave:Connect(function()
        pcall(function()
            tw(b, 0.14, { BackgroundTransparency = 1 })
            if b.iconColor then b.iconColor(P.TextMuted) end
        end)
    end)
    return b
end

local MinimizeBtn   = chromeButton("minimize", 3, false)
local FullscreenBtn = chromeButton("maximize", 4, false)
local CloseBtn      = chromeButton("close", 5, true)

-- масштаб интерфейса прямо в шапке (работает всегда, даже если контент не собрался)
local ZoomHolder = new("Frame", {
    BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -128, 0.5, 0),
    Size = UDim2.new(0, 76, 0, 30),
    ZIndex = 9,
}, TopBar)
hlist(ZoomHolder, 4, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

local function zoomButton(kind, order, delta)
    local b = new("TextButton", {
        Name = "Zoom_" .. tostring(kind),
        BackgroundColor3 = P.BgCardHover,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.new(0, 28, 0, 28),
        LayoutOrder = order,
        ZIndex = 9,
    }, ZoomHolder)
    corner(b, 8)
    local _, setColor = drawIcon(b, kind, 15, P.TextMuted, 12)
    b.MouseEnter:Connect(function()
        pcall(function()
            tw(b, 0.14, { BackgroundTransparency = 0.42 })
            setColor(P.TextWhite)
        end)
    end)
    b.MouseLeave:Connect(function()
        pcall(function()
            tw(b, 0.14, { BackgroundTransparency = 1 })
            setColor(P.TextMuted)
        end)
    end)
    b.MouseButton1Click:Connect(function()
        pcall(function()
            if BHUB.zoomUI then BHUB.zoomUI(delta) end
        end)
    end)
    return b
end

local ZoomOutBtn = zoomButton("zoomOut", 1, -0.05)
local ZoomInBtn  = zoomButton("zoomIn", 2, 0.05)

--===========================================================================
--  САЙДБАР
--===========================================================================
local Sidebar = new("Frame", {
    Name = "Sidebar",
    BackgroundColor3 = P.BgSidebar,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, UI.topH),
    Size = UDim2.new(0, UI.sideW, 1, -UI.topH),
    ZIndex = 6,
}, MainFrame)
gradient(Sidebar, P.BgSidebar, darken(P.BgSidebar, 0.35), 90)

local SideDivider = new("Frame", {
    BackgroundColor3 = P.Divider,
    BorderSizePixel = 0,
    Position = UDim2.new(0, UI.sideW - 1, 0, UI.topH),
    Size = UDim2.new(0, 1, 1, -UI.topH),
    ZIndex = 7,
}, MainFrame)

-- карточка профиля
local ProfileCard = new("Frame", {
    Name = "Profile",
    BackgroundColor3 = P.BgCard,
    BackgroundTransparency = 0.3,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 10, 0, 10),
    Size = UDim2.new(1, -20, 0, 54),
    ZIndex = 8,
}, Sidebar)
corner(ProfileCard, 11)
stroke(ProfileCard, P.BorderSoft, 1)
gradient(ProfileCard, P.BgCard, P.BgSidebar, 90)

local AvatarHolder = new("Frame", {
    BackgroundColor3 = P.BgInput,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 10, 0.5, 0),
    Size = UDim2.new(0, 34, 0, 34),
    ZIndex = 9,
}, ProfileCard)
corner(AvatarHolder, 999)
new("TextLabel", {
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
    Position = UDim2.new(0, 54, 0, 11),
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
    Position = UDim2.new(0, 54, 0, 28),
    Size = UDim2.new(1, -64, 0, 14),
    Font = Enum.Font.GothamMedium,
    TextSize = 10,
    Text = "@" .. tostring(player.Name),
    TextColor3 = P.TextMuted,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 9,
}, ProfileCard)

local TabList = new("ScrollingFrame", {
    Name = "TabList",
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 8, 0, 74),
    Size = UDim2.new(1, -16, 1, -74 - 78),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = Theme.Accent,
    ScrollBarImageTransparency = 0.5,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
    Active = true,
    ZIndex = 8,
}, Sidebar)
vlist(TabList, 4, Enum.HorizontalAlignment.Center)

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

local VersionLabel = new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 10, 1, -34),
    Size = UDim2.new(1, -20, 0, 24),
    Font = Enum.Font.GothamMedium,
    TextSize = 10,
    Text = "BALTIKA HUB  •  MM2",
    TextColor3 = P.TextDim,
    ZIndex = 8,
}, Sidebar)

--===========================================================================
--  ОБЛАСТЬ КОНТЕНТА
--===========================================================================
local ContentArea = new("Frame", {
    Name = "Content",
    BackgroundTransparency = 1,
    Position = UDim2.new(0, UI.sideW, 0, UI.topH),
    Size = UDim2.new(1, -UI.sideW, 1, -UI.topH),
    ZIndex = 5,
}, MainFrame)

--===========================================================================
--  ШТОРКА (компактный режим)
--===========================================================================
local DrawerOverlay = new("Frame", {
    Name = "DrawerOverlay",
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0.55,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, UI.topH),
    Size = UDim2.new(1, 0, 1, -UI.topH),
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
local function setDrawer(open, instant)
    open = open and true or false
    if not UI.compact then
        drawerOpen = false
        DrawerOverlay.Visible = false
        Sidebar.Position = UDim2.new(0, 0, 0, UI.topH)
        return
    end
    drawerOpen = open
    DrawerOverlay.Visible = open
    local target = open and UDim2.new(0, 0, 0, UI.topH) or UDim2.new(0, -(UI.drawerW + 8), 0, UI.topH)
    if instant then
        Sidebar.Position = target
    else
        tw(Sidebar, 0.22, { Position = target }, Enum.EasingStyle.Quint)
    end
end

OverlayBtn.MouseButton1Click:Connect(function() setDrawer(false) end)

--===========================================================================
--  МИНИ-КНОПКА
--===========================================================================
local MiniIcon = new("TextButton", {
    Name = "MiniIcon",
    BackgroundColor3 = P.BgCard,
    Text = "",
    AutoButtonColor = false,
    AnchorPoint = Vector2.new(0, 0),
    Position = UDim2.new(0, 12, 0, 12),
    Size = UDim2.new(0, 134, 0, 40),
    Visible = false,
    ZIndex = 100,
}, ScreenGui)
corner(MiniIcon, 12)
local MiniStroke = stroke(MiniIcon, Theme.Accent, 1.2, 0.35)
local MiniDot = new("Frame", {
    BackgroundColor3 = Theme.Accent,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 12, 0.5, 0),
    Size = UDim2.new(0, 9, 0, 9),
    ZIndex = 101,
}, MiniIcon)
corner(MiniDot, 999)
new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 28, 0, 0),
    Size = UDim2.new(1, -36, 1, 0),
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    Text = "BALTIKA HUB",
    TextColor3 = P.TextWhite,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 101,
}, MiniIcon)

-- всё, что красится акцентом, обновляется одной подпиской
bindAccent(function(c)
    MiniStroke.Color = c
    MiniDot.BackgroundColor3 = c
    LogoMark.BackgroundColor3 = c
    LogoGrad.Color = ColorSequence.new(lighten(c, 0.22), darken(c, 0.15))
    MainStroke.Color = darken(c, 0.72)
    LinkBtn.TextColor3 = lighten(c, 0.4)
    LinkStroke.Color = darken(c, 0.55)
    Brand.Text = "BALTIKA <font color=\"" .. hexColor(c) .. "\">HUB</font>"
end)

--===========================================================================
--  ПЕРЕТАСКИВАНИЕ / ЗАЖИМ В ЭКРАН
--===========================================================================
-- рабочая область внутри гуя (без верхней панели Roblox)
local function guiOrigin()
    local ox, oy = 0, 0
    pcall(function()
        local ap = ScreenGui.AbsolutePosition
        if ap then ox, oy = ap.X, ap.Y end
    end)
    return ox, oy
end

local function clampFrame(frame, margin)
    if not frame or not frame.Parent then return end
    margin = margin or 4
    local vp = viewport()
    local abs, size = frame.AbsolutePosition, frame.AbsoluteSize
    if size.X < 4 or size.Y < 4 then return end
    local ox, oy = guiOrigin()
    -- координаты приводим к системе гуя: иначе окно уезжает под топбар
    local rx, ry = abs.X - ox, abs.Y - oy
    local nx = math.clamp(rx, margin, math.max(margin, vp.X - size.X - margin))
    local ny = math.clamp(ry, margin, math.max(margin, vp.Y - size.Y - margin))
    if math.abs(nx - rx) < 0.5 and math.abs(ny - ry) < 0.5 then return end
    local s = UI.scale > 0 and UI.scale or 1
    local pos = frame.Position
    frame.Position = UDim2.new(0, pos.X.Offset + (nx - rx) / s, 0, pos.Y.Offset + (ny - ry) / s)
end

local function makeDraggable(frame, handle, canMove)
    local dragging, dragStart, startPos, moved = false, nil, nil, false
    handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        if canMove and not canMove() then return end
        dragging = true
        moved = false
        dragStart = input.Position
        startPos = frame.Position
        if input.Changed and input.Changed.Connect then
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
        if math.abs(delta.X) + math.abs(delta.Y) > 4 then moved = true end
        local s = UI.scale > 0 and UI.scale or 1
        frame.Position = UDim2.new(0, startPos.X.Offset + delta.X / s, 0, startPos.Y.Offset + delta.Y / s)
        clampFrame(frame, 4)
    end)
    return function() return moved end
end

-- окно таскается в любом режиме: раньше в компакт-режиме перетаскивание отключалось,
-- из-за чего на телефоне окно казалось «мёртвым»
makeDraggable(MainFrame, DragArea)
local miniMoved = makeDraggable(MiniIcon, MiniIcon)

--===========================================================================
--  РЕСАЙЗ ОКНА (только широкий экран)
--===========================================================================
local ResizeHandle = new("TextButton", {
    Name = "Resize",
    BackgroundColor3 = P.BgCardHover,
    BackgroundTransparency = 0.35,
    Text = "",
    AutoButtonColor = false,
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -3, 1, -3),
    Size = UDim2.new(0, 30, 0, 30),
    Visible = false,
    ZIndex = 30,
}, MainFrame)
corner(ResizeHandle, 10)
for i = 0, 2 do
    for j = 0, 2 do
        if i + j >= 2 then
            new("Frame", {
                BackgroundColor3 = P.TextDim,
                BorderSizePixel = 0,
                Position = UDim2.new(0, 8 + i * 5, 0, 8 + j * 5),
                Size = UDim2.new(0, 2, 0, 2),
                ZIndex = 31,
            }, ResizeHandle)
        end
    end
end

-- ресайз окна за правый нижний угол
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
    local s = UI.scale > 0 and UI.scale or 1
    local vp = viewport()
    local w = math.clamp(resizeBase.X + delta.X / s, 620, math.max(620, vp.X / s - 8))
    local h = math.clamp(resizeBase.Y + delta.Y / s, 380, math.max(380, vp.Y / s - 8))
    MainFrame.Size = UDim2.new(0, math.floor(w), 0, math.floor(h))
    desktopSize = Vector2.new(math.floor(w), math.floor(h))
    Layout.markDirty()
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        if resizing then
            resizing = false
            Layout.markDirty()
        end
    end
end)

--===========================================================================
--  АДАПТАЦИЯ (масштаб, режим, размер окна)
--===========================================================================
local userScale = 1
if type(Config.uiScale) == "number" then
    userScale = math.clamp(Config.uiScale / 100, 0.85, 1.45)
end

local lastVp = Vector2.new(0, 0)

local function detectTouch()
    local ok, res = pcall(function()
        return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
    end)
    return (ok and res) and true or false
end

local function autoCompact(vp)
    if vp.X < 1000 or vp.Y < 600 then return true end
    if detectTouch() and vp.X < 1400 then return true end
    return false
end

local function applyNotifyPlacement()
    if UI.compact then
        NotifyHolder.AnchorPoint = Vector2.new(0.5, 1)
        NotifyHolder.Position = UDim2.new(0.5, 0, 1, -14)
        NotifyHolder.Size = UDim2.new(0, math.min(320, viewport().X - 28), 0, 320)
        notifyLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    else
        NotifyHolder.AnchorPoint = Vector2.new(0, 0)
        NotifyHolder.Position = UDim2.new(1, -14, 0, 12)
        NotifyHolder.Size = UDim2.new(0, 268, 0, 320)
        notifyLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    end
end

local applyMinimized

local function applyResponsive(force)
    local vp = viewport()
    if not force and math.abs(vp.X - lastVp.X) < 1 and math.abs(vp.Y - lastVp.Y) < 1 then
        return
    end
    lastVp = vp

    local wantCompact
    if Config.uiMobile == "on" then
        wantCompact = true
    elseif Config.uiMobile == "off" then
        wantCompact = false
    else
        wantCompact = autoCompact(vp)
    end
    UI.compact = wantCompact
    applyCompactMetrics()

    -- масштаб
    local base
    if UI.compact then
        -- крупнее для пальцев: строка ~46 px на экране
        base = math.clamp(math.min(vp.X / 760, vp.Y / 420), 0.95, 1.2)
    else
        base = math.clamp(math.min(vp.X / 1200, vp.Y / 780), 0.75, 1.15)
    end
    UI.scale = base * userScale
    UIScale.Scale = UI.scale

    -- размер и позиция окна
    local maxW = math.max(240, math.floor(vp.X / UI.scale) - 8)
    local maxH = math.max(220, math.floor(vp.Y / UI.scale) - 8)
    local w, h
    if UI.compact then
        w = maxW
        h = minimized and UI.topH or maxH
        MainFrame.Position = UDim2.new(0, 4, 0, 4)
    else
        if fullscreen then
            w, h = maxW, maxH
        else
            w = math.min(desktopSize.X, maxW)
            h = math.min(desktopSize.Y, maxH)
        end
        w = math.max(math.min(620, maxW), w)
        h = math.max(math.min(380, maxH), h)
        if minimized then
            w = math.min(w, 420)
            h = UI.topH
        end
    end
    MainFrame.Size = UDim2.new(0, math.floor(w), 0, math.floor(h))

    -- верхняя панель и каркас
    TopBar.Size = UDim2.new(1, 0, 0, UI.topH)
    TopDivider.Position = UDim2.new(0, 0, 0, UI.topH - 1)
    MenuBtn.Visible = UI.compact
    FullscreenBtn.Visible = (not UI.compact) and (not minimized)
    LogoMark.Visible = not UI.compact
    Brand.Position = UI.compact and UDim2.new(0, 46, 0, 0) or UDim2.new(0, 42, 0, 0)
    -- окно таскается всегда: в компакт-режиме зона между бургером и кнопками
    if UI.compact then
        DragArea.Position = UDim2.new(0, 44, 0, 0)
        DragArea.Size = UDim2.new(1, -258, 1, 0)
    else
        DragArea.Position = UDim2.new(0, 0, 0, 0)
        DragArea.Size = UDim2.new(1, -200, 1, 0)
    end

    Sidebar.Size = UDim2.new(0, UI.compact and UI.drawerW or UI.sideW, 1, -UI.topH)
    SideDivider.Position = UDim2.new(0, UI.sideW - 1, 0, UI.topH)
    TabList.Size = UDim2.new(1, -16, 1, -74 - 78)

    if UI.compact then
        ContentArea.Position = UDim2.new(0, 0, 0, UI.topH)
        ContentArea.Size = UDim2.new(1, 0, 1, -UI.topH)
    else
        ContentArea.Position = UDim2.new(0, UI.sideW, 0, UI.topH)
        ContentArea.Size = UDim2.new(1, -UI.sideW, 1, -UI.topH)
    end

    DrawerOverlay.Position = UDim2.new(0, 0, 0, UI.topH)
    DrawerOverlay.Size = UDim2.new(1, 0, 1, -UI.topH)
    ResizeHandle.Visible = (not UI.compact) and (not minimized)

    for _, t in ipairs(Tabs) do
        t.btn.Size = UDim2.new(1, -14, 0, tabRowH())
    end

    ZoomHolder.Position = UI.compact and UDim2.new(1, -112, 0.5, 0) or UDim2.new(1, -124, 0.5, 0)

    applyNotifyPlacement()
    applyMinimized()
    setDrawer(UI.compact and drawerOpen or false, true)
    if refreshLayout then refreshLayout() end
    clampFrame(MainFrame, 4)
end

--===========================================================================
--  СВЁРНУТО / РАЗВЁРНУТО / ЗАКРЫТО
--===========================================================================
applyMinimized = function()
    Sidebar.Visible = not minimized
    ContentArea.Visible = not minimized
    SideDivider.Visible = (not minimized) and (not UI.compact)
    ResizeHandle.Visible = (not minimized) and (not UI.compact)
    DrawerOverlay.Visible = (not minimized) and UI.compact and drawerOpen
    if MinimizeBtn.setIconKind then
        MinimizeBtn.setIconKind(minimized and "restore" or "minimize")
    end
end

MinimizeBtn.MouseButton1Click:Connect(function()
    pcall(function()
        minimized = not minimized
        applyResponsive(true)
    end)
end)

FullscreenBtn.MouseButton1Click:Connect(function()
    pcall(function()
        fullscreen = not fullscreen
        if FullscreenBtn.iconColor then
            FullscreenBtn.iconColor(fullscreen and Theme.AccentGlow or P.TextMuted)
        end
        applyResponsive(true)
    end)
end)

CloseBtn.MouseButton1Click:Connect(function()
    pcall(function() MainFrame.Visible = false end)
end)

MainFrame:GetPropertyChangedSignal("Visible"):Connect(function()
    MiniIcon.Visible = not MainFrame.Visible
    if MiniIcon.Visible then clampFrame(MiniIcon, 8) end
end)

local function openWindow()
    MiniIcon.Visible = false
    MainFrame.Visible = true
    applyResponsive(true)
    Layout.markDirty()
    refreshLayout()
end

MiniIcon.MouseButton1Click:Connect(function()
    pcall(function()
        if miniMoved() then return end
        openWindow()
    end)
end)

MenuBtn.MouseButton1Click:Connect(function()
    pcall(function()
        setDrawer(not drawerOpen)
        applyMinimized()
    end)
end)

LinkBtn.MouseButton1Click:Connect(function()
    local link = "https://t.me/BALTIKA_HUB"
    if setclipboard then pcall(setclipboard, link) end
    Notify("Ссылка скопирована: " .. link, "info", "Socials")
end)
LinkBtn.MouseEnter:Connect(function() tw(LinkBtn, 0.14, { BackgroundTransparency = 0.15 }) end)
LinkBtn.MouseLeave:Connect(function() tw(LinkBtn, 0.14, { BackgroundTransparency = 0.4 }) end)


--===========================================================================
--  МАСШТАБ (работает всегда, независимо от вкладок)
--===========================================================================
BHUB.zoomUI = function(delta, silent)
    userScale = math.clamp((userScale or 1) + (delta or 0), 0.85, 1.45)
    Config.uiScale = math.floor(userScale * 100 + 0.5)
    lastVp = Vector2.new(0, 0)
    applyResponsive(true)
    if BHUB.onScaleChanged then pcall(BHUB.onScaleChanged, Config.uiScale) end
    if not silent then
        Notify("Масштаб интерфейса: " .. tostring(Config.uiScale) .. "%", "info", "Интерфейс")
    end
    if BHUB.SaveConfig then pcall(BHUB.SaveConfig) end
end

BHUB.setScale = function(percent)
    local target = math.clamp((tonumber(percent) or 100) / 100, 0.85, 1.45)
    BHUB.zoomUI(target - (userScale or 1), true)
end

BHUB.updateScale = function() applyResponsive(true) end
BHUB.isMobileLayout = function() return UI.compact end
BHUB.setMobileLayout = function(flag, save)
    flag = flag and true or false
    Config.uiMobile = flag and "on" or "off"
    if save and BHUB.SaveConfig then pcall(BHUB.SaveConfig) end
    lastVp = Vector2.new(0, 0)
    applyResponsive(true)
    if mobileToggle then mobileToggle.setState(UI.compact, false) end
end
--===========================================================================
--  ДВИЖОК РАСКЛАДКИ
--  Все размеры считаются в Lua: секции складываются в столбцы, столбцы — в
--  страницу. Никаких AutomaticSize — значит нет «наезжающих» карточек.
--===========================================================================
Layout = { pages = {}, dirty = true }

function Layout.markDirty()
    Layout.dirty = true
end

local function contentWidth()
    return MainFrame.Size.X.Offset - UI.sideW
end

-- высота одной секции: единый поток — свои виджеты и «чужие» элементы
-- в порядке добавления, поэтому наложений быть не может
local function stackSection(sec)
    -- 0) шапка под текущий режим
    if sec.hasHeader then
        sec.headerH = UI.headerH
        sec.header.Size = UDim2.new(1, 0, 0, sec.headerH)
        sec.divider.Position = UDim2.new(0, UI.padIn, 0, sec.headerH)
    end
    sec.contentTop = sec.headerH + (sec.hasHeader and 6 or 4)

    -- 1) высоты своих виджетов под текущий режим
    for _, item in ipairs(sec.items) do
        if item.widget and item.relayout then pcall(item.relayout, item) end
    end

    if not sec.open then
        return sec.headerH
    end

    -- 2) раскладываем всё содержимое сверху вниз
    local y = sec.contentTop
    local first = true
    for _, item in ipairs(sec.items) do
        local frame = item.frame
        if frame.Parent == sec.frame then
            if not first then y = y + UI.gap end
            first = false
            local h
            if item.widget then
                h = item.height
                frame.Size = UDim2.new(1, -UI.padIn * 2, 0, h)
            else
                h = frame.Size.Y.Offset
            end
            frame.Position = UDim2.new(item.xScale or 0, item.xOffset or UI.padIn, 0, y)
            y = y + h
        end
    end

    sec.contentBottom = y
    return math.ceil(y + sec.padBottom)
end

local function stackColumn(col, x, y, w)
    col.Position = UDim2.new(0, x, 0, y)
    col.Size = UDim2.new(0, w, 0, 0)
    local cy = 0
    for _, sec in ipairs(col.__sections) do
        local h = stackSection(sec)
        sec.frame.Size = UDim2.new(1, 0, 0, h)
        sec.frame.Position = UDim2.new(0, 0, 0, cy)
        cy = cy + h + UI.secGap
    end
    local h = math.max(0, cy - UI.secGap)
    col.Size = UDim2.new(0, w, 0, h)
    return h
end

refreshLayout = function()
    Layout.dirty = false
    local contentW = contentWidth()
    -- одна колонка на телефонах; на широких (планшет/ландшафт) — две
    local single = contentW < 520 or (UI.compact and contentW < 660)
    local pagePad, colGap = UI.pagePad, UI.colGap

    for _, page in ipairs(Layout.pages) do
        local cols = page.__cols
        local colW
        if single then
            colW = contentW - pagePad * 2
        else
            colW = (contentW - pagePad * 2 - colGap) / 2
        end
        colW = math.max(120, colW)

        local y = pagePad
        local maxY = pagePad
        if single then
            -- оба столбца друг под другом: ничего не теряется
            for _, col in ipairs(cols) do
                if #col.__sections > 0 then
                    y = y + stackColumn(col, pagePad, y, colW) + UI.secGap
                else
                    col.Position = UDim2.new(0, pagePad, 0, y)
                    col.Size = UDim2.new(0, colW, 0, 0)
                end
            end
            maxY = y
        else
            for i, col in ipairs(cols) do
                local x = pagePad + (i - 1) * (colW + colGap)
                local h = stackColumn(col, x, pagePad, colW)
                maxY = math.max(maxY, pagePad + h + pagePad)
            end
        end
        page.CanvasSize = UDim2.new(0, 0, 0, math.ceil(maxY))
    end
end

--===========================================================================
--  СТРАНИЦЫ И СТОЛБЦЫ
--===========================================================================
local function newPage()
    local page = new("ScrollingFrame", {
        Name = "Page",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Accent,
        ScrollBarImageTransparency = 0.45,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
        Active = true,
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 6,
    }, ContentArea)
    page.__cols = {}
    bindAccent(function(c) page.ScrollBarImageColor3 = c end)
    table.insert(Layout.pages, page)
    return page
end

local function newColumn(page)
    local col = new("Frame", {
        Name = "Column" .. tostring(#page.__cols + 1),
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 0, 0),
        ZIndex = 7,
    }, page)
    col.__sections = {}
    table.insert(page.__cols, col)
    return col
end

--===========================================================================
--  СЕКЦИИ
--===========================================================================
local function newSection(column, title)
    local sec = {
        open = true,
        items = {},      -- всё содержимое в порядке добавления
        widgets = {},    -- только «свои» виджеты (для relayout)
        headerH = UI.headerH,
        padBottom = 8,
        contentTop = UI.headerH + 6,
        contentBottom = UI.headerH + 6,
    }

    local frame = new("Frame", {
        Name = "Section_" .. tostring(title),
        BackgroundColor3 = P.BgCard,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, UI.headerH),
        ZIndex = 8,
    }, column)
    frame.__bhub = true
    corner(frame, 12)
    stroke(frame, P.BorderSoft, 1)
    sec.frame = frame

    local header = new("Frame", {
        Name = "Header",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, UI.headerH),
        ZIndex = 9,
    }, frame)
    header.__bhub = true
    sec.header = header

    local dot = new("Frame", {
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, UI.padIn, 0.5, 0),
        Size = UDim2.new(0, 7, 0, 7),
        ZIndex = 10,
    }, header)
    corner(dot, 999)

    local titleLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, UI.padIn + 14, 0, 0),
        Size = UDim2.new(1, -80, 1, 0),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        Text = string.upper(tostring(title)),
        TextColor3 = P.TextWhite,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 10,
    }, header)

    local chevronBox = new("Frame", {
        Name = "Chevron",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -UI.padIn, 0.5, 0),
        Size = UDim2.new(0, 18, 0, 18),
        ZIndex = 10,
    }, header)

    local function drawChevron(isOpen)
        for _, ch in ipairs(chevronBox:GetChildren()) do
            ch:Destroy()
        end
        drawIcon(chevronBox, isOpen and "chevronUp" or "chevronDown", 14,
            isOpen and P.TextDim or Theme.AccentGlow, 11)
    end
    drawChevron(true)

    local divider = new("Frame", {
        Name = "Divider",
        BackgroundColor3 = P.Divider,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, UI.padIn, 0, UI.headerH),
        Size = UDim2.new(1, -UI.padIn * 2, 0, 1),
        ZIndex = 9,
    }, frame)
    divider.__bhub = true
    sec.divider = divider

    local hit = new("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 11,
    }, header)
    hit.__bhub = true

    local function setOpen(value)
        sec.open = value and true or false
        drawChevron(sec.open)
        divider.Visible = sec.open
        for _, item in ipairs(sec.items) do
            if item.frame.Parent == frame and item.widget then item.frame.Visible = sec.open end
        end
        for _, ch in ipairs(frame:GetChildren()) do
            if ch.__bhubForeign then
                if sec.open then
                    ch.Visible = ch.__bhubWasVisible ~= false
                else
                    ch.__bhubWasVisible = ch.Visible
                    ch.Visible = false
                end
            end
        end
        Layout.markDirty()
    end

    hit.MouseButton1Click:Connect(function() setOpen(not sec.open) end)
    bindAccent(function(c) dot.BackgroundColor3 = c end)

    -- «чужие» элементы (из inject.lua): встают в общий поток секции
    frame.ChildAdded:Connect(function(child)
        if child.__bhub or not child:IsA("GuiObject") then return end
        child.__bhubForeign = true
        child.__bhubWasVisible = child.Visible
        if not sec.open then child.Visible = false end

        local item = {
            frame = child,
            widget = false,
            xScale = child.Position.X.Scale,
            xOffset = child.Position.X.Offset,
        }
        table.insert(sec.items, item)

        -- сразу ставим ниже текущего содержимого (до ближайшего пересчёта)
        local y = sec.contentBottom + ((sec.contentBottom > sec.contentTop) and UI.gap or 0)
        child.Position = UDim2.new(item.xScale, item.xOffset, 0, y)
        sec.contentBottom = y + child.Size.Y.Offset

        pcall(function()
            child:GetPropertyChangedSignal("Size"):Connect(function() Layout.markDirty() end)
        end)
        Layout.markDirty()
    end)

    sec.hasHeader = (tostring(title) ~= "")
    sec.setOpen = setOpen
    sec.frame.__section = sec
    table.insert(column.__sections, sec)
    Layout.markDirty()
    return sec
end

-- добавление виджета в секцию
local function sectionAdd(sec, frame, height, relayout)
    frame.__bhub = true
    frame.Visible = sec.open

    local item = {
        frame = frame,
        widget = true,
        height = height,
        relayout = relayout,
        xScale = 0,
        xOffset = UI.padIn,
    }

    local y = sec.contentBottom + ((sec.contentBottom > sec.contentTop) and UI.gap or 0)
    frame.Position = UDim2.new(0, UI.padIn, 0, y)
    frame.Size = UDim2.new(1, -UI.padIn * 2, 0, height)
    frame.Parent = sec.frame
    sec.contentBottom = y + height

    table.insert(sec.items, item)
    table.insert(sec.widgets, item)
    Layout.markDirty()
    return item
end

local function asSection(parent)
    if parent and parent.__section then return parent.__section end
    local col = parent
    if not (col and col.__sections) then
        col = Layout.pages[1] and Layout.pages[1].__cols[1]
    end
    warn("[BALTIKA] виджет добавлен не в секцию — создаю временную")
    local sec = newSection(col, "")
    sec.header.Visible = false
    sec.divider.Visible = false
    sec.headerH = 8
    return sec
end

--===========================================================================
--  ТУМБЛЕР
--===========================================================================
local function makeToggle(parent, text, cb, init)
    local sec = asSection(parent)

    local row = new("TextButton", {
        Name = "Toggle_" .. tostring(text),
        BackgroundColor3 = P.BgCardHover,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 9,
    })
    corner(row, 10)

    local label = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -72, 1, 0),
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
        Size = UDim2.new(0, 44, 0, 24),
        ZIndex = 10,
    }, row)
    corner(pill, 999)
    local pillStroke = stroke(pill, Theme.Accent, 1, 1)

    local knob = new("Frame", {
        BackgroundColor3 = P.TextWhite,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.new(0, 18, 0, 18),
        ZIndex = 11,
    }, pill)
    corner(knob, 999)

    local state = false
    local function render(instant)
        local t = instant and 0.01 or 0.16
        tw(knob, t, { Position = state and UDim2.new(0, 23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
        tw(pill, t, { BackgroundColor3 = state and Theme.Accent or P.ToggleOff })
        tw(pillStroke, t, { Transparency = state and 0 or 1 })
    end

    local function setState(value, fire)
        state = value and true or false
        render()
        if fire ~= false and cb then
            local ok, err = pcall(cb, state)
            if not ok then warn("[BALTIKA] toggle error: " .. tostring(err)) end
        end
    end

    row.MouseButton1Click:Connect(function() setState(not state) end)
    row.MouseEnter:Connect(function() tw(row, 0.14, { BackgroundTransparency = 0.55 }) end)
    row.MouseLeave:Connect(function() tw(row, 0.14, { BackgroundTransparency = 1 }) end)

    bindAccent(function(c)
        pillStroke.Color = c
        if state then pill.BackgroundColor3 = c end
    end)

    sectionAdd(sec, row, UI.rowH, function(w) w.height = UI.rowH end)
    if init then setState(true, false) end
    return { setState = setState, getState = function() return state end }
end

--===========================================================================
--  СЛАЙДЕР
--===========================================================================
local function makeSlider(parent, text, mn, mx, def, cb)
    local sec = asSection(parent)
    mn = tonumber(mn) or 0
    mx = tonumber(mx) or 100
    if mx <= mn then mx = mn + 1 end
    def = math.clamp(tonumber(def) or mn, mn, mx)

    local row = new("Frame", {
        Name = "Slider_" .. tostring(text),
        BackgroundTransparency = 1,
        ZIndex = 9,
    })

    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 6),
        Size = UDim2.new(1, -84, 0, 16),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        Text = tostring(text),
        TextColor3 = P.TextWhite,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 10,
    }, row)

    local chip = new("Frame", {
        BackgroundColor3 = P.BgInput,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, 3),
        Size = UDim2.new(0, 54, 0, 21),
        ZIndex = 10,
    }, row)
    corner(chip, 7)
    local chipStroke = stroke(chip, P.BorderSoft, 1)

    local valueLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        Text = tostring(def),
        TextColor3 = Theme.AccentGlow,
        ZIndex = 11,
    }, chip)

    local track = new("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Position = UDim2.new(0, 18, 0, 32),
        Size = UDim2.new(1, -36, 0, 22),
        ZIndex = 11,
    }, row)

    local bar = new("Frame", {
        BackgroundColor3 = P.ToggleOff,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
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

    local knob = new("Frame", {
        BackgroundColor3 = P.TextWhite,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 15, 0, 15),
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
        valueLabel.Text = tostring(rounded)
        if fire ~= false and cb and rounded ~= lastFired then
            lastFired = rounded
            local ok, err = pcall(cb, rounded)
            if not ok then warn("[BALTIKA] slider error: " .. tostring(err)) end
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
            tw(knob, 0.1, { Size = UDim2.new(0, 19, 0, 19) })
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
            tw(knob, 0.12, { Size = UDim2.new(0, 15, 0, 15) })
        end
    end)

    bindAccent(function(c)
        fill.BackgroundColor3 = c
        fillGrad.Color = ColorSequence.new(lighten(c, 0.18), c)
        knobStroke.Color = c
        valueLabel.TextColor3 = lighten(c, 0.4)
        chipStroke.Color = darken(c, 0.62)
    end)

    sectionAdd(sec, row, UI.sliderH, function(w)
        w.height = UI.sliderH
        local trackH = UI.compact and 30 or 22
        track.Size = UDim2.new(1, -36, 0, trackH)
        track.Position = UDim2.new(0, 18, 0, UI.sliderH - trackH - 6)
    end)

    setValue(value, false)
    return { setValue = setValue, getValue = function() return value end, frame = row }
end

--===========================================================================
--  КНОПКА
--===========================================================================
local function makeButton(parent, text, special, cb)
    local sec = asSection(parent)

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
        ZIndex = 10,
    })
    corner(btn, 10)
    local btnStroke = stroke(btn, P.BorderSoft, 1)

    local hover = new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 9,
    }, btn)
    corner(hover, 10)

    if special then
        btn.BackgroundTransparency = 1
        btn.TextColor3 = Color3.new(1, 1, 1)
        local bg = new("Frame", {
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 8,
        }, btn)
        corner(bg, 10)
        local bgGrad = gradient(bg, lighten(Theme.Accent, 0.14), darken(Theme.Accent, 0.3), 15)
        bindAccent(function(c)
            bg.BackgroundColor3 = c
            bgGrad.Color = ColorSequence.new(lighten(c, 0.14), darken(c, 0.3))
            btnStroke.Color = lighten(c, 0.2)
            btnStroke.Transparency = 0.4
        end)
    end

    local scale = new("UIScale", { Scale = 1 }, btn)

    btn.MouseEnter:Connect(function() tw(hover, 0.14, { BackgroundTransparency = special and 0.86 or 0.94 }) end)
    btn.MouseLeave:Connect(function() tw(hover, 0.14, { BackgroundTransparency = 1 }) end)
    btn.MouseButton1Down:Connect(function() tw(scale, 0.08, { Scale = 0.98 }) end)
    btn.MouseButton1Up:Connect(function() tw(scale, 0.12, { Scale = 1 }) end)
    btn.MouseButton1Click:Connect(function()
        tw(scale, 0.12, { Scale = 1 })
        if cb then
            local ok, err = pcall(cb)
            if not ok then warn("[BALTIKA] button error: " .. tostring(err)) end
        end
    end)

    sectionAdd(sec, btn, UI.btnH, function(w) w.height = UI.btnH end)
    return btn
end

--===========================================================================
--  ТЕКСТОВОЕ ПОЛЕ
--===========================================================================
local function makeTextBox(parent, placeholder, height, cb)
    local sec = asSection(parent)
    height = tonumber(height) or 38
    local multiline = height >= 60

    local box = new("TextBox", {
        Name = "TextBox",
        BackgroundColor3 = P.BgInput,
        BorderSizePixel = 0,
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
    })
    corner(box, 10)
    padding(box, 6, 6, 10, 10)
    local boxStroke = stroke(box, P.BorderSoft, 1)

    box.Focused:Connect(function()
        tw(boxStroke, 0.15, { Color = Theme.Accent, Transparency = 0.1 })
        tw(box, 0.15, { BackgroundColor3 = P.BgBottom })
    end)
    box.FocusLost:Connect(function()
        tw(boxStroke, 0.15, { Color = P.BorderSoft, Transparency = 0 })
        tw(box, 0.15, { BackgroundColor3 = P.BgInput })
    end)
    bindAccent(function(c)
        if box:IsFocused() then boxStroke.Color = c end
    end)

    if cb then
        box:GetPropertyChangedSignal("Text"):Connect(function()
            local ok, err = pcall(cb, box.Text)
            if not ok then warn("[BALTIKA] textbox error: " .. tostring(err)) end
        end)
    end

    sectionAdd(sec, box, height)
    return box
end

--===========================================================================
--  КЕЙБИНД
--===========================================================================
local keybindButtons = {}
local keybindMeta = {}
local awaitingKeybindAction = nil

local function makeKeybind(parent, labelText, actionKey)
    local sec = asSection(parent)

    local row = new("Frame", {
        Name = "Keybind_" .. tostring(labelText),
        BackgroundTransparency = 1,
        ZIndex = 9,
    })

    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -128, 1, 0),
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
        Size = UDim2.new(0, 104, 0, 28),
        ZIndex = 10,
    }, row)
    corner(pill, 9)
    local pillStroke = stroke(pill, P.BorderSoft, 1)

    keybindButtons[actionKey] = pill
    keybindMeta[actionKey] = { pill = pill, stroke = pillStroke, lastText = nil }

    pill.MouseEnter:Connect(function()
        if awaitingKeybindAction ~= actionKey then
            tw(pillStroke, 0.14, { Color = Theme.Accent, Transparency = 0.45 })
        end
    end)
    pill.MouseLeave:Connect(function()
        if awaitingKeybindAction ~= actionKey then
            tw(pillStroke, 0.14, { Color = P.BorderSoft, Transparency = 0 })
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
        Notify("Нажмите клавишу для бинда (Esc — сбросить)", "info", "Бинд")
    end)

    bindAccent(function()
        if keybindMeta[actionKey] then keybindMeta[actionKey].lastText = nil end
    end)

    sectionAdd(sec, row, UI.rowH, function(w)
        w.height = UI.rowH
        pill.Size = UDim2.new(0, UI.compact and 116 or 104, 0, UI.compact and 30 or 28)
    end)

    return { button = pill }
end

--===========================================================================
--  ЗАЩИТА ОТ ПАДЕНИЙ (fail-soft)
--  Если один конструктор виджета упадёт (нестандартный клиент, чужой элемент,
--  нехватка памяти) — остальное окно продолжает работать: вкладки, кнопки
--  окна, масштаб и перетаскивание. Раньше ошибка в середине файла оставляла
--  интерфейс полностью «мёртвым».
--===========================================================================
local function noopWidget()
    local stub = {}
    return setmetatable(stub, {
        __index = function(self, key)
            local f = function() end
            rawset(self, key, f)
            return f
        end,
    })
end

local function guardWidget(label, fn, ...)
    local ok, res = pcall(fn, ...)
    if ok and res ~= nil then return res end
    warn("[BALTIKA] " .. label .. " не создан: " .. tostring(res))
    return noopWidget()
end

AddToggle = function(parent, text, cb, init)
    return guardWidget("тумблер «" .. tostring(text) .. "»", makeToggle, parent, text, cb, init)
end

AddSlider = function(parent, text, mn, mx, def, cb)
    return guardWidget("слайдер «" .. tostring(text) .. "»", makeSlider, parent, text, mn, mx, def, cb)
end

AddButton = function(parent, text, special, cb)
    return guardWidget("кнопка «" .. tostring(text) .. "»", makeButton, parent, text, special, cb)
end

AddTextBox = function(parent, placeholder, height, cb)
    return guardWidget("поле «" .. tostring(placeholder) .. "»", makeTextBox, parent, placeholder, height, cb)
end

AddKeybind = function(parent, labelText, actionKey)
    return guardWidget("биндинг «" .. tostring(labelText) .. "»", makeKeybind, parent, labelText, actionKey)
end
--===========================================================================
--  ВКЛАДКИ
--===========================================================================
tabRowH = function() return UI.compact and 46 or 38 end

local function styleTab(t, isActive, instant)
    t.isActive = isActive
    local tr = instant and 0.01 or 0.18
    tw(t.active, tr, { BackgroundTransparency = isActive and 0.88 or 1 })
    t.label.Font = isActive and Enum.Font.GothamBold or Enum.Font.GothamMedium
    tw(t.label, tr, { TextColor3 = isActive and P.TextWhite or P.TextMuted })
    tw(t.iconBg, tr, { BackgroundColor3 = isActive and Theme.Accent or P.BgCard })
    tw(t.iconText, tr, { TextColor3 = isActive and Color3.new(1, 1, 1) or P.TextDim })
    t.iconGrad.Enabled = isActive
end

selectTab = function(index)
    if index == selectedTab then
        if UI.compact then setDrawer(false) end
        return
    end
    if not Tabs[index] then return end
    selectedTab = index
    for i, t in ipairs(Tabs) do
        local isActive = (i == index)
        t.page.Visible = isActive
        styleTab(t, isActive)
    end
    Layout.markDirty()
    refreshLayout()
    if UI.compact then setDrawer(false) end
end

local function makeTab(name, single)
    local row = new("TextButton", {
        Name = "Tab_" .. tostring(name),
        BackgroundColor3 = P.BgCardHover,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.new(1, -14, 0, tabRowH()),
        LayoutOrder = #Tabs + 1,
        ZIndex = 9,
    }, TabList)
    corner(row, 10)

    local active = new("Frame", {
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 9,
    }, row)
    corner(active, 10)

    local iconBg = new("Frame", {
        BackgroundColor3 = P.BgCard,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 7, 0.5, 0),
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
        Position = UDim2.new(0, 41, 0, 0),
        Size = UDim2.new(1, -49, 1, 0),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        Text = tostring(name),
        TextColor3 = P.TextMuted,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 10,
    }, row)

    local page = newPage()
    local col1 = newColumn(page)
    local col2 = nil
    if not single then
        col2 = newColumn(page)
    end

    local t = {
        btn = row, label = label, page = page, active = active,
        iconBg = iconBg, iconText = iconText, iconGrad = iconGrad,
        cols = page.__cols, isActive = false,
    }
    table.insert(Tabs, t)

    bindAccent(function(c)
        t.active.BackgroundColor3 = c
        t.iconGrad.Color = ColorSequence.new(lighten(c, 0.25), c)
        if t.isActive then t.iconBg.BackgroundColor3 = c end
    end)

    row.MouseEnter:Connect(function()
        if not t.isActive then tw(row, 0.14, { BackgroundTransparency = 0.7 }) end
    end)
    row.MouseLeave:Connect(function()
        if not t.isActive then tw(row, 0.14, { BackgroundTransparency = 1 }) end
    end)
    row.MouseButton1Click:Connect(function()
        selectTab(table.find(Tabs, t) or 1)
    end)

    if single then
        return col1
    end
    return col1, col2
end

--===========================================================================
--  ЭКСПОРТ API
--===========================================================================
local function AddTab(name, single)
    local ok, left, right = pcall(makeTab, name, single)
    if ok then return left, right end
    warn("[BALTIKA] вкладка «" .. tostring(name) .. "» не создана: " .. tostring(left))
    return nil, nil
end

BHUB.AddTab = AddTab
BHUB.AddSection = function(parent, title)
    local col = parent
    if not col or not col.__sections then
        -- на всякий случай: если передали страницу или что-то другое
        if col and col.__cols then col = col.__cols[1]
        elseif Layout.pages[1] then col = Layout.pages[1].__cols[1] end
    end
    local ok, sec = pcall(newSection, col, title)
    if not ok or not sec then
        warn("[BALTIKA] секция «" .. tostring(title) .. "» не создана: " .. tostring(sec))
        return nil
    end
    return sec.frame
end
BHUB.AddToggle = AddToggle
BHUB.AddSlider = AddSlider
BHUB.AddButton = AddButton
BHUB.AddTextBox = AddTextBox
BHUB.AddKeybind = AddKeybind
BHUB.MainFrame = MainFrame
BHUB.Sidebar = Sidebar
BHUB.ContentArea = ContentArea
BHUB.UIScale = UIScale
BHUB.MiniIcon = MiniIcon
BHUB.DrawerOverlay = DrawerOverlay
BHUB.keybindButtons = keybindButtons
BHUB.getAwaitingKeybind = function() return awaitingKeybindAction end
BHUB.setAwaitingKeybind = function(v)
    awaitingKeybindAction = v
    if v == nil then
        for _, meta in pairs(keybindMeta) do
            tw(meta.stroke, 0.14, { Color = P.BorderSoft, Transparency = 0 })
        end
    end
end
BHUB.selectTab = function(index) selectTab(index) end
BHUB.refreshLayout = function()
    Layout.markDirty()
    refreshLayout()
end

-- определяем режим ДО создания вкладок, чтобы виджеты получили верные размеры
applyResponsive(true)

--===========================================================================
--  ВКЛАДКИ (контент)
--===========================================================================
local MoveLeft, MoveRight = AddTab("Movement", false)
local FlingLeft, FlingRight = AddTab("Fling & Combat", false)
local VisLeft, VisRight = AddTab("Visuals & Misc", false)
local SetLeft, SetRight = AddTab("Settings & Binds", false)

--===========================================================================
--  ИНТЕРФЕЙС
--===========================================================================
local UiSec = BHUB.AddSection(SetLeft, "Interface")

mobileToggle = AddToggle(UiSec, "Компактный режим (телефон)", function(v)
    BHUB.setMobileLayout(v, true)
    Notify(v and "Компактная раскладка включена" or "Обычная раскладка включена", "info", "Интерфейс")
end, UI.compact)

AddButton(UiSec, "Определить устройство автоматически", false, function()
    Config.uiMobile = "auto"
    if BHUB.SaveConfig then pcall(BHUB.SaveConfig) end
    lastVp = Vector2.new(0, 0)
    applyResponsive(true)
    if mobileToggle then mobileToggle.setState(UI.compact, false) end
    Notify(UI.compact and "Определено: телефон" or "Определено: ПК", "info", "Интерфейс")
end)

local scaleSlider = AddSlider(UiSec, "Масштаб интерфейса, %", 85, 145,
    math.floor((userScale or 1) * 100 + 0.5), function(v)
        BHUB.setScale(v)
    end)

BHUB.onScaleChanged = function(percent)
    if scaleSlider and scaleSlider.setValue then scaleSlider.setValue(percent, false) end
end

AddButton(UiSec, "Сбросить размер и позицию окна", false, function()
    if UI.compact then
        Notify("В компактном режиме окно занимает весь экран", "info", "Интерфейс")
        return
    end
    desktopSize = Vector2.new(760, 500)
    fullscreen = false
    if FullscreenBtn.iconColor then FullscreenBtn.iconColor(P.TextMuted) end
    applyResponsive(true)
    local vp = viewport()
    MainFrame.Position = UDim2.new(0,
        math.max(4, math.floor((vp.X / UI.scale - MainFrame.Size.X.Offset) / 2)), 0,
        math.max(4, math.floor((vp.Y / UI.scale - MainFrame.Size.Y.Offset) / 2)))
    clampFrame(MainFrame, 4)
end)

local AccentSec = BHUB.AddSection(SetLeft, "Accent color")
local swatchRow = new("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, UI.padIn, 0, 0),
    Size = UDim2.new(1, -UI.padIn * 2, 0, 38),
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
    sw.MouseButton1Click:Connect(function()
        setAccent(color, true)
        refreshAccentSwatches()
        Notify("Акцент обновлён", "success", "Интерфейс")
    end)
end

refreshAccentSwatches = function()
    for _, item in ipairs(swatches) do
        item.ring.Transparency = (packColor(item.color) == appliedAccentPack) and 0 or 1
    end
end
refreshAccentSwatches()

--===========================================================================
--  MOVEMENT
--===========================================================================
local SpeedSec = BHUB.AddSection(MoveLeft, "Speed & Dash")
AddToggle(SpeedSec, "Super Speed", function(s) Config.superSpeedEnabled = s end, Config.superSpeedEnabled)
AddSlider(SpeedSec, "Speed Multiplier", 1, 10, Config.speedMultiplier, function(v) Config.speedMultiplier = v end)
AddButton(SpeedSec, "Dash", false, function() if BHUB.performDash then BHUB.performDash() end end)
AddSlider(SpeedSec, "Dash Strength", 30, 300, Config.dashStrength, function(v) Config.dashStrength = v end)

local JumpSec = BHUB.AddSection(MoveLeft, "Jumping")
AddToggle(JumpSec, "Bunny Hop", function(s) Config.bhopEnabled = s end, Config.bhopEnabled)
AddToggle(JumpSec, "Wallhop", function(s) Config.wallhopEnabled = s end, Config.wallhopEnabled)
AddSlider(JumpSec, "Wallhop Power", 20, 150, Config.wallhopVelocity, function(v) Config.wallhopVelocity = v end)
AddToggle(JumpSec, "Infinite Jump", function(s) Config.infiniteJumpEnabled = s end, Config.infiniteJumpEnabled)
AddSlider(JumpSec, "Inf Jump Boost", 10, 200, Config.infJumpBoost, function(v) Config.infJumpBoost = v end)
AddToggle(JumpSec, "Super Jump", function(s) Config.superJumpEnabled = s end, Config.superJumpEnabled)
AddSlider(JumpSec, "Jump Multiplier", 1, 10, Config.jumpPowerMultiplier, function(v) Config.jumpPowerMultiplier = v end)

local FlightSec = BHUB.AddSection(MoveRight, "Flight & Physics")
AddToggle(FlightSec, "Fly (WASD + QE)", function(s) if BHUB.toggleFly then BHUB.toggleFly(s) end end, Config.flyEnabled)
AddSlider(FlightSec, "Fly Speed", 10, 200, Config.flySpeed, function(v) Config.flySpeed = v end)
AddToggle(FlightSec, "Air Walk", function(s) if BHUB.toggleAirWalk then BHUB.toggleAirWalk(s) end end, Config.airWalkEnabled)
AddToggle(FlightSec, "Spider Climb", function(s) if BHUB.toggleSpider then BHUB.toggleSpider(s) end end, Config.spiderEnabled)
AddToggle(FlightSec, "NoClip", function(s) if BHUB.toggleNoclip then BHUB.toggleNoclip(s) end end, Config.noclipEnabled)

local CharSec = BHUB.AddSection(MoveRight, "Character")
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
local WalkFlingSec = BHUB.AddSection(FlingLeft, "Attack")
AddToggle(WalkFlingSec, "Walk Fling", function(s) if BHUB.toggleWalkFling then BHUB.toggleWalkFling(s) end end, Config.walkFlingEnabled)
AddToggle(WalkFlingSec, "Spinbot", function(s) if BHUB.toggleSpinbot then BHUB.toggleSpinbot(s) end end, Config.spinbotEnabled)
AddSlider(WalkFlingSec, "Spin Speed", 10, 200, Config.spinbotSpeed, function(v) Config.spinbotSpeed = v end)

local AimSec = BHUB.AddSection(FlingLeft, "Aimbot")
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

local ProtectSec = BHUB.AddSection(FlingRight, "Protection")
AddToggle(ProtectSec, "Anti-Fling", function(s) if BHUB.toggleAntiFling then BHUB.toggleAntiFling(s) end end, Config.antiFlingEnabled)
AddToggle(ProtectSec, "Anti-Void", function(s) if BHUB.toggleAntiVoid then BHUB.toggleAntiVoid(s) end end, Config.antiVoidEnabled)
AddToggle(ProtectSec, "Anti-Ragdoll", function(s) if BHUB.toggleAntiRagdoll then BHUB.toggleAntiRagdoll(s) end end, Config.antiRagdollEnabled)
AddToggle(ProtectSec, "Auto-Hide (HP <= 40)", function(s) if BHUB.toggleAutoHideCombat then BHUB.toggleAutoHideCombat(s) end end, Config.autoHideCombatEnabled)

--===========================================================================
--  VISUALS & MISC
--===========================================================================
local VisSec = BHUB.AddSection(VisLeft, "Visuals")
AddToggle(VisSec, "Player ESP", function(s) if BHUB.toggleEspWrapper then BHUB.toggleEspWrapper(s) end end, Config.espEnabled)
AddToggle(VisSec, "X-Ray", function(s) if BHUB.toggleXray then BHUB.toggleXray(s) end end, Config.xrayEnabled)
AddSlider(VisSec, "X-Ray Transparency", 1, 10, math.floor(Config.xrayTransparency * 10), function(v)
    Config.xrayTransparency = v / 10
    if Config.xrayEnabled and BHUB.toggleXray then BHUB.toggleXray(true) end
end)
AddToggle(VisSec, "Fullbright", function(s) if BHUB.toggleFullbright then BHUB.toggleFullbright(s) end end, Config.fullbrightEnabled)
AddToggle(VisSec, "3rd Person", function(s) if BHUB.toggleThirdPerson then BHUB.toggleThirdPerson(s) end end, Config.thirdPersonEnabled)

local MiscSec = BHUB.AddSection(VisRight, "Misc")
AddToggle(MiscSec, "Click TP", function(s) Config.clickTpEnabled = s end, Config.clickTpEnabled)
AddToggle(MiscSec, "Unlock Mouse", function(s) if BHUB.toggleMouseUnlock then BHUB.toggleMouseUnlock(s) end end, Config.mouseUnlockEnabled)
AddButton(MiscSec, "Kill Character (Perma)", false, function()
    if BHUB.permaKillCharacter then BHUB.permaKillCharacter() end
end)

--===========================================================================
--  БИНДЫ
--===========================================================================
local BindsMove = BHUB.AddSection(SetLeft, "Movement Binds")
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

local BindsMisc = BHUB.AddSection(SetRight, "Misc Binds")
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
    Notify("Конфиг сохранён", "success", "BALTIKA HUB")
end)

--===========================================================================
--  СИНХРОНИЗАЦИЯ БИНДОВ
--===========================================================================
local function refreshKeybindPills()
    local awaiting = awaitingKeybindAction
    for action, pill in pairs(keybindButtons) do
        local meta = keybindMeta[action]
        if meta then
            local key = keybinds[action]
            local name = (key and key ~= Enum.KeyCode.Unknown) and key.Name or "None"
            local waiting = (awaiting == action)
            local wantText = waiting and "..." or name
            if meta.lastText ~= wantText or meta.lastWaiting ~= waiting then
                meta.lastText = wantText
                meta.lastWaiting = waiting
                pill.Text = wantText
                if waiting then
                    pill.BackgroundColor3 = Theme.Accent
                    pill.TextColor3 = Color3.new(1, 1, 1)
                    tw(meta.stroke, 0.14, { Color = Theme.AccentGlow, Transparency = 0 })
                else
                    pill.BackgroundColor3 = P.BgInput
                    pill.TextColor3 = lighten(Theme.Accent, 0.4)
                    tw(meta.stroke, 0.14, { Color = P.BorderSoft, Transparency = 0 })
                end
            end
        end
    end
end

task.spawn(function()
    while true do
        task.wait(0.2)
        if not MainFrame.Parent then break end
        pcall(refreshKeybindPills)
    end
end)

--===========================================================================
--  СТОРОЖ: поворот экрана, смена размера, докладка
--===========================================================================
task.spawn(function()
    while true do
        task.wait(0.4)
        if not MainFrame or not MainFrame.Parent then break end
        pcall(function()
            local vp = viewport()
            if math.abs(vp.X - lastVp.X) > 1 or math.abs(vp.Y - lastVp.Y) > 1 then
                applyResponsive(true)
            end
            if Layout.dirty then refreshLayout() end
            clampFrame(MainFrame, 4)
            if MiniIcon.Visible then clampFrame(MiniIcon, 8) end
        end)
    end
end)

task.spawn(function()
    while true do
        task.wait(0.6)
        if not MainFrame or not MainFrame.Parent then break end
        pcall(function()
            local sc = tonumber(Config.uiScale)
            if sc and math.abs(sc - userScale * 100) > 0.5 then
                userScale = math.clamp(sc / 100, 0.85, 1.45)
                applyResponsive(true)
            end
            local ac = tonumber(Config.uiAccent)
            if ac and ac ~= appliedAccentPack then
                setAccent(unpackColor(ac), false)
                refreshAccentSwatches()
            end
            if Config.uiMobile == "on" or Config.uiMobile == "off" then
                local want = (Config.uiMobile == "on")
                if want ~= UI.compact then
                    lastVp = Vector2.new(0, 0)
                    applyResponsive(true)
                    if mobileToggle then mobileToggle.setState(UI.compact, false) end
                end
            end
        end)
    end
end)

--===========================================================================
--  СТАРТ
--===========================================================================
setAccent(unpackColor(tonumber(Config.uiAccent) or packColor(DEFAULT_ACCENT)), false)
applyResponsive(true)
selectTab(1)
Layout.markDirty()
refreshLayout()

if not UI.compact then
    local vp = viewport()
    MainFrame.Position = UDim2.new(0,
        math.max(8, math.floor((vp.X / UI.scale - MainFrame.Size.X.Offset) / 2)), 0,
        math.max(8, math.floor((vp.Y / UI.scale - MainFrame.Size.Y.Offset) / 2)))
    clampFrame(MainFrame, 4)
end

Notify(UI.compact and "Загружено • мобильная раскладка" or "Загружено • раскладка для ПК", "success", "BALTIKA HUB")
print("[BALTIKA] Интерфейс готов (" .. (UI.compact and "телефон" or "ПК") ..
    ", масштаб " .. tostring(math.floor(UI.scale * 100)) .. "%)")
