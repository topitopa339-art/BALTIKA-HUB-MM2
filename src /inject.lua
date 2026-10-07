local BHUB = _G.BHUB
local Config = BHUB.Config
local Conns = BHUB.Conns
local keybinds = BHUB.keybinds
local player = BHUB.player
local Players = BHUB.Players
local Theme = BHUB.Theme
local ScreenGui = BHUB.ScreenGui
local AddTab = BHUB.AddTab
local AddSection = BHUB.AddSection
local AddToggle = BHUB.AddToggle
local AddSlider = BHUB.AddSlider
local AddButton = BHUB.AddButton
local AddTextBox = BHUB.AddTextBox
local AddKeybind = BHUB.AddKeybind
local MakeSmoothDraggable = BHUB.MakeSmoothDraggable
local ApplyCorner = BHUB.ApplyCorner
local ApplyStroke = BHUB.ApplyStroke
local ApplyPadding = BHUB.ApplyPadding
local SaveConfig = BHUB.SaveConfig
local LoadConfig = BHUB.LoadConfig
local BHUB_SCRIPTS_DIR = BHUB.BHUB_SCRIPTS_DIR

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local anyItemQuery = ""
local injectorFileName = ""
local injectorFileCode = ""

local ScriptsLeft, ScriptsRight = AddTab("Scripts & Exec", false)
local InjLeft, InjRight = AddTab("Injector & Dex", false)

local InjLaunchSec = AddSection(ScriptsLeft, "Quick Launch")
AddButton(InjLaunchSec, "Infinite Yield", true, function()
    pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))() end)
end)
AddButton(InjLaunchSec, "F3X Tools", true, function()
    pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/infyiff/backup/main/f3x.lua"))() end)
end)

local ExtraSec = AddSection(ScriptsRight, "Explorer")
AddButton(ExtraSec, "Old Dex", true, function()
    pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/infyiff/backup/main/dex.lua"))() end)
end)
AddButton(ExtraSec, "Dex++", false, function()
    pcall(function() loadstring(game:HttpGet("https://github.com/AZYsGithub/DexPlusPlus/releases/latest/download/out.lua"))() end)
end)

local EditorSec = AddSection(InjLeft, "Code Editor")
local nameInputBox = AddTextBox(EditorSec, "Script name...", 34, function(text) injectorFileName = text end)
local codeInputBox = AddTextBox(EditorSec, "Paste script code here...", 70, function(text) injectorFileCode = text end)

local ConsoleSec = AddSection(InjLeft, "Terminal")
local terminalFrame = Instance.new("ScrollingFrame")
terminalFrame.Size = UDim2.new(1, -20, 0, 75)
terminalFrame.Position = UDim2.new(0, 10, 0, 5)
terminalFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
terminalFrame.BorderSizePixel = 0
terminalFrame.ScrollBarThickness = 3
terminalFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
terminalFrame.ZIndex = 14
terminalFrame.Parent = ConsoleSec
ApplyCorner(terminalFrame, 4)
ApplyStroke(terminalFrame, Theme.Border, 1)

local terminalLayout = Instance.new("UIListLayout")
terminalLayout.SortOrder = Enum.SortOrder.LayoutOrder
terminalLayout.Padding = UDim.new(0, 2)
terminalLayout.Parent = terminalFrame

local function logToConsole(text, color)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -12, 0, 16)
    lbl.Position = UDim2.new(0, 6, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.RobotoMono
    lbl.TextSize = 10
    lbl.TextColor3 = color or Theme.TextWhite
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Center
    lbl.TextTruncate = Enum.TextTruncate.None
    lbl.Text = os.date("[%X] ") .. tostring(text)
    lbl.ZIndex = 15
    lbl.Parent = terminalFrame
    terminalFrame.CanvasSize = UDim2.new(0, 0, 0, terminalLayout.AbsoluteContentSize.Y + 8)
    terminalFrame.CanvasPosition = Vector2.new(0, terminalFrame.CanvasSize.Y.Offset)
end

logToConsole("Mini-Injector ready.", Theme.AccentGlow)

local function executeCodeSafely(sourceCode, scriptName)
    logToConsole("Compiling: " .. (scriptName or "raw") .. "...", Theme.TextMuted)
    local func, compileErr = loadstring(sourceCode)
    if not func then
        logToConsole("[SYNTAX ERROR]: " .. tostring(compileErr), Theme.Error)
        return false
    end
    logToConsole("Running...", Theme.Warning)
    task.spawn(function()
        local success, runtimeErr = xpcall(func, function(err) return tostring(err) .. "\n" .. debug.traceback() end)
        if not success then
            logToConsole("[RUNTIME ERROR]:", Theme.Error)
            for _, line in ipairs(string.split(tostring(runtimeErr), "\n")) do
                if line ~= "" then logToConsole(line, Theme.Error) end
            end
        else
            logToConsole("[OK] Finished.", Theme.Success)
        end
    end)
    return true
end

local function SaveCurrentScript()
    if injectorFileName == "" or injectorFileCode == "" then
        logToConsole("Error: name or code empty!", Theme.Warning)
        return
    end
    if writefile then
        pcall(function() writefile(BHUB_SCRIPTS_DIR .. "/" .. injectorFileName .. ".lua", injectorFileCode) end)
        logToConsole("Saved: " .. injectorFileName .. ".lua", Theme.Success)
        if refreshSavedScriptsList then refreshSavedScriptsList() end
    end
end

AddButton(EditorSec, "Save to file (.lua)", true, SaveCurrentScript)
AddButton(EditorSec, "Run code (Raw)", false, function()
    if injectorFileCode == "" then logToConsole("Editor is empty.", Theme.Warning); return end
    executeCodeSafely(injectorFileCode, "Editor_Code")
end)

local GrabSec = AddSection(InjLeft, "Items & Tools")
AddTextBox(GrabSec, "Part / model / tool name...", 34, function(text) anyItemQuery = text end)
AddButton(GrabSec, "Create Tool from object", true, function()
    if anyItemQuery == "" then return end
    local backpack = player:FindFirstChildOfClass("Backpack")
    local char = player.Character
    if not backpack or not char then return end
    local foundInstance = nil
    local query = anyItemQuery:lower()
    for _, container in ipairs({ReplicatedStorage, game:GetService("Lighting"), workspace}) do
        if container and not foundInstance then
            pcall(function()
                for _, obj in ipairs(container:GetDescendants()) do
                    if obj and obj.Name and obj.Name:lower():find(query) and not obj:IsDescendantOf(char) then
                        foundInstance = obj
                        break
                    end
                end
            end)
        end
        if foundInstance then break end
    end
    if not foundInstance then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                pcall(function()
                    for _, obj in ipairs(p.Character:GetDescendants()) do
                        if obj and obj.Name and obj.Name:lower():find(query) then
                            foundInstance = obj
                            break
                        end
                    end
                end)
            end
            if foundInstance then break end
        end
    end
    if not foundInstance then return end
    pcall(function()
        if foundInstance:IsA("Tool") then
            local copy = foundInstance:Clone()
            copy.Parent = backpack
            return
        end
        local newTool = Instance.new("Tool")
        newTool.Name = foundInstance.Name
        newTool.RequiresHandle = true
        local clonedItem = foundInstance:Clone()
        if clonedItem:IsA("BasePart") then
            clonedItem.Name = "Handle"
            clonedItem.CanCollide = false
            clonedItem.Anchored = false
            clonedItem.Parent = newTool
        else
            local dummyHandle = Instance.new("Part")
            dummyHandle.Name = "Handle"
            dummyHandle.Size = Vector3.new(1, 1, 1)
            dummyHandle.Transparency = 1
            dummyHandle.CanCollide = false
            dummyHandle.Anchored = false
            dummyHandle.Parent = newTool
            clonedItem.Parent = newTool
        end
        newTool.Parent = backpack
    end)
end)

local SavedListSec = AddSection(InjLeft, "Saved files (.lua)")
local fileListFrame = Instance.new("ScrollingFrame")
fileListFrame.Size = UDim2.new(1, -20, 0, 75)
fileListFrame.Position = UDim2.new(0, 10, 0, 5)
fileListFrame.BackgroundTransparency = 1
fileListFrame.ScrollBarThickness = 2
fileListFrame.ZIndex = 14
fileListFrame.Parent = SavedListSec

local fileLayout = Instance.new("UIListLayout")
fileLayout.SortOrder = Enum.SortOrder.LayoutOrder
fileLayout.Padding = UDim.new(0, 4)
fileLayout.Parent = fileListFrame

function refreshSavedScriptsList()
    for _, child in ipairs(fileListFrame:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    if listfiles and isfolder and isfolder(BHUB_SCRIPTS_DIR) then
        local files = listfiles(BHUB_SCRIPTS_DIR)
        for _, path in ipairs(files) do
            local clean = path:match("([^/\\]+)%.lua$") or path:match("([^/\\]+)$")
            if clean then
                local tagBtn = Instance.new("TextButton")
                tagBtn.Size = UDim2.new(1, -6, 0, 24)
                tagBtn.BackgroundColor3 = Theme.BgInput
                tagBtn.TextColor3 = Theme.AccentGlow
                tagBtn.Text = "📁 " .. clean
                tagBtn.Font = Enum.Font.GothamMedium
                tagBtn.TextSize = 11
                tagBtn.TextXAlignment = Enum.TextXAlignment.Left
                tagBtn.TextTruncate = Enum.TextTruncate.AtEnd
                tagBtn.ZIndex = 15
                ApplyPadding(tagBtn, 0, 0, 8, 8)
                tagBtn.Parent = fileListFrame
                ApplyCorner(tagBtn, 4)
                ApplyStroke(tagBtn, Theme.Border, 1)
                tagBtn.MouseButton1Click:Connect(function()
                    injectorFileName = clean
                    nameInputBox.Text = clean
                    if readfile and isfile and isfile(BHUB_SCRIPTS_DIR .. "/" .. clean .. ".lua") then
                        local content = readfile(BHUB_SCRIPTS_DIR .. "/" .. clean .. ".lua")
                        if content then
                            codeInputBox.Text = content
                            injectorFileCode = content
                            logToConsole("Loaded: " .. clean, Theme.TextMuted)
                        end
                    end
                end)
            end
        end
        fileLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            fileListFrame.CanvasSize = UDim2.new(0, 0, 0, fileLayout.AbsoluteContentSize.Y + 5)
        end)
    end
end

AddButton(SavedListSec, "Run selected file", true, function()
    if injectorFileName == "" then logToConsole("No file selected.", Theme.Warning); return end
    if readfile and isfile and isfile(BHUB_SCRIPTS_DIR .. "/" .. injectorFileName .. ".lua") then
        local ok, code = pcall(function() return readfile(BHUB_SCRIPTS_DIR .. "/" .. injectorFileName .. ".lua") end)
        if ok and code then executeCodeSafely(code, injectorFileName) else logToConsole("Read error.", Theme.Error) end
    else
        logToConsole("File not found: " .. injectorFileName .. ".lua", Theme.Error)
    end
end)

AddButton(SavedListSec, "Copy file code", false, function()
    if injectorFileName == "" then return end
    if readfile and isfile and isfile(BHUB_SCRIPTS_DIR .. "/" .. injectorFileName .. ".lua") then
        local ok, code = pcall(function() return readfile(BHUB_SCRIPTS_DIR .. "/" .. injectorFileName .. ".lua") end)
        if ok and code then
            if setclipboard then setclipboard(code) end
            logToConsole("Copied to clipboard.", Theme.AccentGlow)
        end
    end
end)

AddButton(SavedListSec, "Delete file", false, function()
    if injectorFileName == "" then return end
    if delfile and isfile and isfile(BHUB_SCRIPTS_DIR .. "/" .. injectorFileName .. ".lua") then
        pcall(function() delfile(BHUB_SCRIPTS_DIR .. "/" .. injectorFileName .. ".lua") end)
        logToConsole("Deleted: " .. injectorFileName .. ".lua", Theme.Warning)
        nameInputBox.Text = ""
        codeInputBox.Text = ""
        injectorFileCode = ""
        refreshSavedScriptsList()
    end
end)

AddButton(SavedListSec, "Refresh file list", false, function() refreshSavedScriptsList() end)

task.spawn(function() task.wait(0.5); refreshSavedScriptsList() end)

local ExplorerSec = AddSection(InjRight, "Scanner & Explorer")

local navBar = Instance.new("Frame")
navBar.Size = UDim2.new(1, 0, 0, 30)
navBar.BackgroundTransparency = 1
navBar.Parent = ExplorerSec

local backBtn = Instance.new("TextButton")
backBtn.Size = UDim2.new(0, 30, 1, 0)
backBtn.BackgroundColor3 = Theme.BgInput
backBtn.Text = "<"
backBtn.TextColor3 = Theme.AccentGlow
backBtn.Font = Enum.Font.GothamBold
backBtn.TextSize = 14
backBtn.Parent = navBar
ApplyCorner(backBtn, 6)
ApplyStroke(backBtn)

local pathLabel = Instance.new("TextLabel")
pathLabel.Size = UDim2.new(1, -75, 1, 0)
pathLabel.Position = UDim2.new(0, 35, 0, 0)
pathLabel.BackgroundColor3 = Theme.BgInput
pathLabel.Text = "game"
pathLabel.TextColor3 = Theme.TextWhite
pathLabel.Font = Enum.Font.GothamMedium
pathLabel.TextSize = 12
pathLabel.TextTruncate = Enum.TextTruncate.AtEnd
pathLabel.Parent = navBar
ApplyCorner(pathLabel, 6)
ApplyStroke(pathLabel)
ApplyPadding(pathLabel, 0, 0, 8, 8)

local dexRefreshBtn = Instance.new("TextButton")
dexRefreshBtn.Size = UDim2.new(0, 35, 1, 0)
dexRefreshBtn.Position = UDim2.new(1, -35, 0, 0)
dexRefreshBtn.BackgroundColor3 = Theme.BgInput
dexRefreshBtn.Text = "↻"
dexRefreshBtn.TextColor3 = Theme.TextWhite
dexRefreshBtn.Font = Enum.Font.GothamBold
dexRefreshBtn.TextSize = 16
dexRefreshBtn.Parent = navBar
ApplyCorner(dexRefreshBtn, 6)
ApplyStroke(dexRefreshBtn)

local selectedDexNode = nil
local dexSelectedLabel = AddButton(ExplorerSec, "Selected: Nothing", false, function() end)

local scanAllBtn = AddButton(ExplorerSec, "Scan all (back to game)", true, function() end)
local deleteSelectedBtn = AddButton(ExplorerSec, "Delete selected", false, function() end)

local expListWindow = Instance.new("Frame")
expListWindow.Size = UDim2.new(1, 0, 0, 220)
expListWindow.BackgroundColor3 = Theme.BgInput
expListWindow.BackgroundTransparency = 0.5
expListWindow.Parent = ExplorerSec
ApplyCorner(expListWindow, 6)
ApplyStroke(expListWindow, Theme.Border, 1)

local expList = Instance.new("ScrollingFrame")
expList.Size = UDim2.new(1, 0, 1, 0)
expList.BackgroundTransparency = 1
expList.ScrollBarThickness = 4
expList.Parent = expListWindow
ApplyPadding(expList, 4, 4, 4, 4)

local expLayout = Instance.new("UIListLayout")
expLayout.SortOrder = Enum.SortOrder.Name
expLayout.Padding = UDim.new(0, 4)
expLayout.Parent = expList
expLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    expList.CanvasSize = UDim2.new(0, 0, 0, expLayout.AbsoluteContentSize.Y + 10)
end)

local currentNavNode = game

local function getSafeChildren(node)
    if node == game then
        return {Workspace, Players, game:GetService("Lighting"), ReplicatedStorage, game:GetService("ReplicatedFirst"), game:GetService("StarterGui"), game:GetService("StarterPack"), game:GetService("StarterPlayer")}
    end
    local ok, children = pcall(function() return node:GetChildren() end)
    if ok then return children else return {} end
end

local function loadDirectory(node)
    currentNavNode = node
    pathLabel.Text = node == game and "game" or node.Name
    for _, child in ipairs(expList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    local children = getSafeChildren(node)
    for _, child in ipairs(children) do
        local row = Instance.new("Frame")
        row.Name = child.Name
        row.Size = UDim2.new(1, 0, 0, 28)
        row.BackgroundColor3 = Theme.BgCard
        row.Parent = expList
        ApplyCorner(row, 6)
        ApplyStroke(row)

        local enterBtn = Instance.new("TextButton")
        enterBtn.Size = UDim2.new(1, -35, 1, 0)
        enterBtn.BackgroundTransparency = 1
        enterBtn.Text = string.format("  [%s] %s", child.ClassName, child.Name)
        enterBtn.TextColor3 = Theme.TextWhite
        enterBtn.Font = Enum.Font.GothamMedium
        enterBtn.TextSize = 11
        enterBtn.TextXAlignment = Enum.TextXAlignment.Left
        enterBtn.TextTruncate = Enum.TextTruncate.AtEnd
        enterBtn.Parent = row

        local delBtn = Instance.new("TextButton")
        delBtn.Size = UDim2.new(0, 24, 0, 24)
        delBtn.Position = UDim2.new(1, -28, 0.5, -12)
        delBtn.BackgroundColor3 = Theme.Error
        delBtn.BackgroundTransparency = 0.2
        delBtn.Text = "X"
        delBtn.TextColor3 = Theme.TextWhite
        delBtn.Font = Enum.Font.GothamBold
        delBtn.TextSize = 10
        delBtn.Parent = row
        ApplyCorner(delBtn, 4)

        enterBtn.MouseButton1Click:Connect(function()
            selectedDexNode = child
            dexSelectedLabel.Text = "Selected: " .. child.Name
            pcall(function()
                if #child:GetChildren() > 0 then loadDirectory(child) end
            end)
        end)
        delBtn.MouseButton1Click:Connect(function()
            pcall(function() child:Destroy(); row:Destroy() end)
        end)
    end
end

backBtn.MouseButton1Click:Connect(function()
    if currentNavNode and currentNavNode.Parent then loadDirectory(currentNavNode.Parent) end
end)
dexRefreshBtn.MouseButton1Click:Connect(function()
    if currentNavNode then loadDirectory(currentNavNode) end
end)
scanAllBtn.MouseButton1Click:Connect(function() loadDirectory(game) end)
deleteSelectedBtn.MouseButton1Click:Connect(function()
    if selectedDexNode then
        pcall(function()
            selectedDexNode:Destroy()
            dexSelectedLabel.Text = "Selected: Nothing"
            selectedDexNode = nil
            if currentNavNode then loadDirectory(currentNavNode) end
        end)
    end
end)

task.spawn(function() task.wait(0.5); loadDirectory(game) end)

local SetLeft = nil
local SetRight = nil

task.spawn(function()
    task.wait(0.3)
end)

local function handleKeybindAction(action)
    if action == "BhopToggle" then Config.bhopEnabled = not Config.bhopEnabled
    elseif action == "WallhopToggle" then Config.wallhopEnabled = not Config.wallhopEnabled
    elseif action == "InfJumpToggle" then Config.infiniteJumpEnabled = not Config.infiniteJumpEnabled
    elseif action == "SuperJumpToggle" then Config.superJumpEnabled = not Config.superJumpEnabled
    elseif action == "SpeedToggle" then Config.superSpeedEnabled = not Config.superSpeedEnabled
    elseif action == "FlyToggle" and BHUB.toggleFly then BHUB.toggleFly(not Config.flyEnabled)
    elseif action == "NoclipToggle" and BHUB.toggleNoclip then BHUB.toggleNoclip(not Config.noclipEnabled)
    elseif action == "AirWalkToggle" and BHUB.toggleAirWalk then BHUB.toggleAirWalk(not Config.airWalkEnabled)
    elseif action == "SpiderToggle" and BHUB.toggleSpider then BHUB.toggleSpider(not Config.spiderEnabled)
    elseif action == "EspToggle" and BHUB.toggleEspWrapper then BHUB.toggleEspWrapper(not Config.espEnabled)
    elseif action == "XrayToggle" and BHUB.toggleXray then BHUB.toggleXray(not Config.xrayEnabled)
    elseif action == "ThirdPersonToggle" and BHUB.toggleThirdPerson then BHUB.toggleThirdPerson(not Config.thirdPersonEnabled)
    elseif action == "SpinbotToggle" and BHUB.toggleSpinbot then BHUB.toggleSpinbot(not Config.spinbotEnabled)
    elseif action == "WalkFlingToggle" and BHUB.toggleWalkFling then BHUB.toggleWalkFling(not Config.walkFlingEnabled)
    elseif action == "AntiFlingToggle" and BHUB.toggleAntiFling then BHUB.toggleAntiFling(not Config.antiFlingEnabled)
    elseif action == "UnlockMouse" and BHUB.toggleMouseUnlock then BHUB.toggleMouseUnlock(not Config.mouseUnlockEnabled)
    elseif action == "ClickTP" and BHUB.teleportToMouse then BHUB.teleportToMouse()
    elseif action == "DashKey" and BHUB.performDash then BHUB.performDash()
    end
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    local awaiting = BHUB.getAwaitingKeybind()
    if awaiting then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.Escape then
                keybinds[awaiting] = Enum.KeyCode.Unknown
                local btn = BHUB.keybindButtons[awaiting]
                if btn then btn.Text = "None" end
            else
                keybinds[awaiting] = input.KeyCode
                local btn = BHUB.keybindButtons[awaiting]
                if btn then btn.Text = input.KeyCode.Name end
            end
            BHUB.setAwaitingKeybind(nil)
            SaveConfig()
            return
        end
    end
    if UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.RightAlt then
        if BHUB.MainFrame then BHUB.MainFrame.Visible = not BHUB.MainFrame.Visible end
        return
    end
    for action, key in pairs(keybinds) do
        if key and key ~= Enum.KeyCode.Unknown and input.KeyCode == key then
            if action == "ToggleMenu" then
                if BHUB.MainFrame then BHUB.MainFrame.Visible = not BHUB.MainFrame.Visible end
            else
                handleKeybindAction(action)
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gp)
    if gp then return end
    if BHUB.flyKeys then
        if input.KeyCode == Enum.KeyCode.W then BHUB.flyKeys.forward = false
        elseif input.KeyCode == Enum.KeyCode.S then BHUB.flyKeys.backward = false
        elseif input.KeyCode == Enum.KeyCode.A then BHUB.flyKeys.left = false
        elseif input.KeyCode == Enum.KeyCode.D then BHUB.flyKeys.right = false
        elseif input.KeyCode == Enum.KeyCode.E then BHUB.flyKeys.up = false
        elseif input.KeyCode == Enum.KeyCode.Q then BHUB.flyKeys.down = false end
    end
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if not BHUB.flyKeys or not Config.flyEnabled then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.W then BHUB.flyKeys.forward = true
    elseif input.KeyCode == Enum.KeyCode.S then BHUB.flyKeys.backward = true
    elseif input.KeyCode == Enum.KeyCode.A then BHUB.flyKeys.left = true
    elseif input.KeyCode == Enum.KeyCode.D then BHUB.flyKeys.right = true
    elseif input.KeyCode == Enum.KeyCode.E then BHUB.flyKeys.up = true
    elseif input.KeyCode == Enum.KeyCode.Q then BHUB.flyKeys.down = true end
end)

task.spawn(function()
    task.wait(0.5)
    LoadConfig()
    task.wait(0.3)

    if Config.flyEnabled and BHUB.toggleFly then BHUB.toggleFly(true) end
    if Config.noclipEnabled and BHUB.toggleNoclip then BHUB.toggleNoclip(true) end
    if Config.airWalkEnabled and BHUB.toggleAirWalk then BHUB.toggleAirWalk(true) end
    if Config.spiderEnabled and BHUB.toggleSpider then BHUB.toggleSpider(true) end
    if Config.spinbotEnabled and BHUB.toggleSpinbot then BHUB.toggleSpinbot(true) end
    if Config.walkFlingEnabled and BHUB.toggleWalkFling then BHUB.toggleWalkFling(true) end
    if Config.antiFlingEnabled and BHUB.toggleAntiFling then BHUB.toggleAntiFling(true) end
    if Config.antiVoidEnabled and BHUB.toggleAntiVoid then BHUB.toggleAntiVoid(true) end
    if Config.antiRagdollEnabled and BHUB.toggleAntiRagdoll then BHUB.toggleAntiRagdoll(true) end
    if Config.autoHideCombatEnabled and BHUB.toggleAutoHideCombat then BHUB.toggleAutoHideCombat(true) end
    if Config.unlockMovementEnabled and BHUB.toggleUnlockMovement then BHUB.toggleUnlockMovement(true) end
    if Config.tinyCharEnabled and BHUB.applyTinyCharacter then BHUB.applyTinyCharacter(true) end
    if Config.customMassEnabled and BHUB.applyCharacterMass then BHUB.applyCharacterMass(true) end
    if Config.thirdPersonEnabled and BHUB.toggleThirdPerson then BHUB.toggleThirdPerson(true) end
    if Config.fullbrightEnabled and BHUB.toggleFullbright then BHUB.toggleFullbright(true) end
    if Config.xrayEnabled and BHUB.toggleXray then BHUB.toggleXray(true) end
    if Config.mouseUnlockEnabled and BHUB.toggleMouseUnlock then BHUB.toggleMouseUnlock(true) end
    if Config.espEnabled and BHUB.toggleEspWrapper then BHUB.toggleEspWrapper(true) end

    if Config.showFovEnabled and BHUB.FovCircle then
        BHUB.FovCircle.Size = UDim2.new(0, Config.fovRadius * 2, 0, Config.fovRadius * 2)
        BHUB.FovCircle.Visible = true
    end

    SaveConfig()
end)

task.spawn(function()
    local lastHash = ""
    while true do
        task.wait(5)
        local data = { Config = {}, Keybinds = {} }
        for k, v in pairs(Config) do
            if type(v) == "boolean" or type(v) == "number" or type(v) == "string" then
                data.Config[k] = v
            end
        end
        for k, v in pairs(keybinds) do
            if typeof(v) == "EnumItem" then data.Keybinds[k] = v.Name end
        end
        local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
        if ok and encoded and encoded ~= lastHash then
            lastHash = encoded
            pcall(function() writefile(BHUB.BHUB_CONFIG_PATH, encoded) end)
        end
    end
end)

print("[BALTIKA HUB NEW] Loaded. Config: " .. BHUB.BHUB_CONFIG_PATH)
