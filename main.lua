local BASE_URL = "https://raw.githubusercontent.com/topitopa339-art/BALTIKA-HUB-MM2/main/src/"

local function loadModule(name)
    local url = BASE_URL .. name
    local ok, code = pcall(function() return game:HttpGet(url) end)
    if not ok or not code or code == "" then
        warn("[BALTIKA HUB NEW] Failed to load: " .. name)
        return false
    end
    local fn, err = loadstring(code)
    if not fn then
        warn("[BALTIKA HUB NEW] Syntax error in " .. name .. ": " .. tostring(err))
        return false
    end
    local success, runtimeErr = pcall(fn)
    if not success then
        warn("[BALTIKA HUB NEW] Runtime error in " .. name .. ": " .. tostring(runtimeErr))
        return false
    end
    return true
end

loadModule("config.lua")
loadModule("utils.lua")
loadModule("fun_main.lua")
loadModule("ui.lua")
loadModule("inject.lua")

print("[BALTIKA HUB NEW] All modules loaded.")
