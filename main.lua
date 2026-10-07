local URLS = {
    config    = "https://raw.githubusercontent.com/topitopa339-art/BALTIKA-HUB-MM2/main/src/config.lua",
    utils     = "https://raw.githubusercontent.com/topitopa339-art/BALTIKA-HUB-MM2/main/src/utils.lua",
    fun_main  = "https://raw.githubusercontent.com/topitopa339-art/BALTIKA-HUB-MM2/main/src/fun_main.lua",
    ui        = "https://raw.githubusercontent.com/topitopa339-art/BALTIKA-HUB-MM2/main/src/ui.lua",
    inject    = "https://raw.githubusercontent.com/topitopa339-art/BALTIKA-HUB-MM2/main/src/inject.lua",
}

local function fetch(url)
    if request then
        local ok, res = pcall(request, {Url = url, Method = "GET"})
        if ok and res and res.Body and res.Body ~= "" then
            return res.Body
        end
    end
    if http_request then
        local ok, res = pcall(http_request, {Url = url, Method = "GET"})
        if ok and res and res.Body and res.Body ~= "" then
            return res.Body
        end
    end
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if ok and res and res ~= "" then return res end
    return nil
end

local function loadModule(name, url)
    print("[BALTIKA] Loading: " .. name)
    local code = fetch(url)
    if not code then
        warn("[BALTIKA] FAILED to fetch: " .. url)
        return false
    end
    print("[BALTIKA] Got " .. #code .. " bytes for " .. name)
    local fn, err = loadstring(code)
    if not fn then
        warn("[BALTIKA] Syntax error in " .. name .. ": " .. tostring(err))
        return false
    end
    local ok, runtimeErr = pcall(fn)
    if not ok then
        warn("[BALTIKA] Runtime error in " .. name .. ": " .. tostring(runtimeErr))
        return false
    end
    print("[BALTIKA] OK: " .. name)
    return true
end

loadModule("config", URLS.config)
loadModule("utils", URLS.utils)
loadModule("fun_main", URLS.fun_main)
loadModule("ui", URLS.ui)
loadModule("inject", URLS.inject)

print("[BALTIKA HUB NEW] All modules loaded.")
