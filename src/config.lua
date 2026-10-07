local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
while not player do task.wait(0.1); player = Players.LocalPlayer end

local BHUB_ROOT = "BALTIKA HUB"
local BHUB_GAME = BHUB_ROOT .. "/MM2"
local BHUB_SCRIPT = BHUB_GAME .. "/BALTIKA HUB NEW"
local BHUB_SCRIPTS_DIR = BHUB_SCRIPT .. "/Scripts"
local BHUB_CONFIG_PATH = BHUB_SCRIPT .. "/BHUB_NEW.json"

pcall(function()
    if makefolder then
        if isfolder and not isfolder(BHUB_ROOT) then makefolder(BHUB_ROOT) end
        if isfolder and not isfolder(BHUB_GAME) then makefolder(BHUB_GAME) end
        if isfolder and not isfolder(BHUB_SCRIPT) then makefolder(BHUB_SCRIPT) end
        if isfolder and not isfolder(BHUB_SCRIPTS_DIR) then makefolder(BHUB_SCRIPTS_DIR) end
    end
end)

if CoreGui:FindFirstChild("BALTIKA_HUB_NEW") then
    CoreGui:FindFirstChild("BALTIKA_HUB_NEW"):Destroy()
end
if CoreGui:FindFirstChild("BALTIKA_HUB_FOV") then
    CoreGui:FindFirstChild("BALTIKA_HUB_FOV"):Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end
ScreenGui.Parent = CoreGui
ScreenGui.Name = "BALTIKA_HUB_NEW"
ScreenGui.ResetOnSpawn = false

local Config = {
    superSpeedEnabled = false,
    speedMultiplier = 2,
    wasSpeedEnabled = false,
    superJumpEnabled = false,
    jumpPowerMultiplier = 3,
    wasJumpEnabled = false,
    infiniteJumpEnabled = false,
    infJumpBoost = 50,
    dashStrength = 100,
    isDashing = false,
    bhopEnabled = false,
    wallhopEnabled = false,
    wallhopVelocity = 50,
    flyEnabled = false,
    flySpeed = 50,
    noclipEnabled = false,
    airWalkEnabled = false,
    spiderEnabled = false,
    unlockMovementEnabled = false,
    tinyCharEnabled = false,
    tinyVisualsEnabled = true,
    tinyScalePercent = 25,
    customMassEnabled = false,
    massMultiplier = 10,
    walkFlingEnabled = false,
    antiFlingEnabled = false,
    antiVoidEnabled = false,
    antiRagdollEnabled = false,
    autoHideCombatEnabled = false,
    isHidingUnderground = false,
    aimbotEnabled = false,
    showFovEnabled = false,
    fovRadius = 150,
    aimbotSmoothness = 5,
    aimbotTargetBots = false,
    espEnabled = false,
    xrayEnabled = false,
    xrayTransparency = 0.5,
    fullbrightEnabled = false,
    thirdPersonEnabled = false,
    spinbotEnabled = false,
    spinbotSpeed = 50,
    clickTpEnabled = false,
    mouseUnlockEnabled = false,
    -- оформление интерфейса (см. src/ui.lua)
    uiAccent = 8150271, -- акцентный цвет, упакованный RGB (по умолчанию violet 124,92,255)
    uiScale = 100,      -- масштаб интерфейса в %
    uiMobile = "auto"   -- "auto" | "on" | "off" (компактная мобильная раскладка)
}

local Conns = {
    fly = nil,
    noclip = nil,
    airWalk = nil,
    spider = nil,
    xray = nil,
    thirdPerson = nil,
    spinbot = nil,
    mouseUnlock = nil,
    walkFling = nil,
    antiFling = nil,
    antiVoid = nil,
    antiRagdoll = nil,
    autoHide = nil,
    unlockMovement = nil,
    esp = {}
}

local keybinds = {
    ToggleMenu = Enum.KeyCode.RightAlt,
    UnlockMouse = Enum.KeyCode.G,
    ClickTP = Enum.KeyCode.Unknown,
    DashKey = Enum.KeyCode.Q,
    BhopToggle = Enum.KeyCode.Unknown,
    WallhopToggle = Enum.KeyCode.Unknown,
    InfJumpToggle = Enum.KeyCode.Unknown,
    SuperJumpToggle = Enum.KeyCode.Unknown,
    SpeedToggle = Enum.KeyCode.Unknown,
    FlyToggle = Enum.KeyCode.Unknown,
    AirWalkToggle = Enum.KeyCode.Unknown,
    SpiderToggle = Enum.KeyCode.Unknown,
    NoclipToggle = Enum.KeyCode.Unknown,
    EspToggle = Enum.KeyCode.Unknown,
    XrayToggle = Enum.KeyCode.Unknown,
    ThirdPersonToggle = Enum.KeyCode.Unknown,
    SpinbotToggle = Enum.KeyCode.Unknown,
    WalkFlingToggle = Enum.KeyCode.Unknown,
    AntiFlingToggle = Enum.KeyCode.Unknown
}

local function SafeJsonEncode(t)
    if not HttpService or not HttpService.JSONEncode then return nil end
    local ok, res = pcall(function() return HttpService:JSONEncode(t) end)
    return ok and res or nil
end

local function SafeJsonDecode(s)
    if not HttpService or not HttpService.JSONDecode then return nil end
    local ok, res = pcall(function() return HttpService:JSONDecode(s) end)
    return ok and res or nil
end

local function SaveConfig()
    if not writefile then return end
    local data = { Config = {}, Keybinds = {} }
    for k, v in pairs(Config) do
        if type(v) == "boolean" or type(v) == "number" or type(v) == "string" then
            data.Config[k] = v
        end
    end
    for k, v in pairs(keybinds) do
        if typeof(v) == "EnumItem" then
            data.Keybinds[k] = v.Name
        end
    end
    local encoded = SafeJsonEncode(data)
    if encoded then
        pcall(function() writefile(BHUB_CONFIG_PATH, encoded) end)
    end
end

local function LoadConfig()
    if not readfile or not isfile then return end
    local exists = false
    pcall(function() exists = isfile(BHUB_CONFIG_PATH) end)
    if not exists then return end
    local raw
    pcall(function() raw = readfile(BHUB_CONFIG_PATH) end)
    if not raw or raw == "" then return end
    local data = SafeJsonDecode(raw)
    if type(data) ~= "table" then return end
    if type(data.Config) == "table" then
        for k, v in pairs(data.Config) do
            if Config[k] ~= nil and type(Config[k]) == type(v) then
                Config[k] = v
            end
        end
    end
    if type(data.Keybinds) == "table" then
        for k, v in pairs(data.Keybinds) do
            if keybinds[k] ~= nil and type(v) == "string" then
                local ok, key = pcall(function() return Enum.KeyCode[v] end)
                if ok and key then keybinds[k] = key end
            end
        end
    end
end

_G.BHUB = {
    Config = Config,
    Conns = Conns,
    keybinds = keybinds,
    ScreenGui = ScreenGui,
    player = player,
    Players = Players,
    BHUB_CONFIG_PATH = BHUB_CONFIG_PATH,
    BHUB_SCRIPTS_DIR = BHUB_SCRIPTS_DIR,
    SaveConfig = SaveConfig,
    LoadConfig = LoadConfig
}
