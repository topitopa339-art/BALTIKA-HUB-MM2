local BHUB = _G.BHUB
local Config = BHUB.Config
local Conns = BHUB.Conns
local player = BHUB.player
local Players = BHUB.Players
local Theme = BHUB.Theme
local getHum = BHUB.getHum

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local espHighlights = {}
local espLabels = {}
local _originalTransparencies = {}
local _originalScales = {}
local _originalLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Ambient = Lighting.Ambient
}

local flyBodyGyro = nil
local flyBodyVelocity = nil
local flyKeys = {forward=false, backward=false, left=false, right=false, up=false, down=false}

local airWalkLockedY = 0
local airWalkPart = Instance.new("Part")
airWalkPart.Size = Vector3.new(25, 1, 25)
airWalkPart.Transparency = 1
airWalkPart.Anchored = true
airWalkPart.CanCollide = true
airWalkPart.Name = "BHUB_AirWalk"

local savedHidePosition = nil

RunService.RenderStepped:Connect(function()
    if Config.fullbrightEnabled then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
    end
    if Config.thirdPersonEnabled then
        player.CameraMode = Enum.CameraMode.Classic
        player.CameraMaxZoomDistance = 128
        player.CameraMinZoomDistance = 10
    end
    if Config.mouseUnlockEnabled then
        UserInputService.MouseIconEnabled = true
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end
end)

RunService.Stepped:Connect(function()
    local char = player.Character
    if char then
        local hum = getHum(char)
        if hum then
            if Config.superSpeedEnabled then
                hum.WalkSpeed = 16 * Config.speedMultiplier
                Config.wasSpeedEnabled = true
            elseif Config.wasSpeedEnabled then
                hum.WalkSpeed = 16
                Config.wasSpeedEnabled = false
            end
            if Config.superJumpEnabled then
                hum.UseJumpPower = true
                hum.JumpPower = 50 * Config.jumpPowerMultiplier
                Config.wasJumpEnabled = true
            elseif Config.wasJumpEnabled then
                hum.UseJumpPower = true
                hum.JumpPower = 50
                Config.wasJumpEnabled = false
            end
        end
    end
end)

local function performDash()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or Config.isDashing then return end
    Config.isDashing = true
    local cam = Workspace.CurrentCamera
    local lookDir = cam.CFrame.LookVector
    local dashDir = Vector3.new(lookDir.X, 0.2, lookDir.Z).Unit
    local originalVel = hrp.AssemblyLinearVelocity
    hrp.AssemblyLinearVelocity = dashDir * Config.dashStrength
    task.delay(0.25, function()
        if hrp and hrp.Parent then
            hrp.AssemblyLinearVelocity = Vector3.new(originalVel.X, hrp.AssemblyLinearVelocity.Y, originalVel.Z)
        end
        Config.isDashing = false
    end)
end

local function applyCharacterMass(state)
    Config.customMassEnabled = state
    local char = player.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            if state then
                local density = math.clamp(0.7 * Config.massMultiplier, 0.01, 100)
                part.CustomPhysicalProperties = PhysicalProperties.new(density, 0.3, 0.5, 1, 1)
            else
                part.CustomPhysicalProperties = nil
            end
        end
    end
end

local function permaKillCharacter()
    local char = player.Character
    if not char then return end
    local hum = getHum(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hum then
        hum:ChangeState(Enum.HumanoidStateType.Dead)
        hum.Health = 0
        hum:Destroy()
    end
    if hrp then
        hrp.CFrame = CFrame.new(0, -9999999, 0)
        hrp.AssemblyLinearVelocity = Vector3.new(0, -9999999, 0)
    end
    char:ClearAllChildren()
end

local function applyTinyCharacter(state)
    Config.tinyCharEnabled = state
    local char = player.Character
    if not char then return end
    local hum = getHum(char)
    if not hum then return end
    local scaleValues = {"BodyDepthScale", "BodyHeightScale", "BodyWidthScale", "HeadScale"}
    if state then
        for _, name in ipairs(scaleValues) do
            local val = hum:FindFirstChild(name)
            if val and not _originalScales[name] then
                _originalScales[name] = val.Value
            end
        end
        local factor = math.clamp(Config.tinyScalePercent / 100, 0.05, 1)
        for _, name in ipairs(scaleValues) do
            local val = hum:FindFirstChild(name)
            if val then val.Value = factor end
        end
        local multVisual = 1 / factor
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("SpecialMesh") then
                part.Scale = Config.tinyVisualsEnabled and Vector3.new(1, 1, 1) or Vector3.new(multVisual, multVisual, multVisual)
            end
        end
        hum.HipHeight = 1.4 * factor
    else
        for name, orig in pairs(_originalScales) do
            local val = hum:FindFirstChild(name)
            if val then val.Value = orig end
        end
        _originalScales = {}
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("SpecialMesh") then part.Scale = Vector3.new(1, 1, 1) end
        end
        hum.HipHeight = 2
    end
end

local function toggleUnlockMovement(state)
    Config.unlockMovementEnabled = state
    if Conns.unlockMovement then
        Conns.unlockMovement:Disconnect()
        Conns.unlockMovement = nil
    end
    if state then
        Conns.unlockMovement = RunService.Stepped:Connect(function()
            local hum = getHum(player.Character)
            if hum then
                if hum.WalkSpeed < 16 then hum.WalkSpeed = 16 end
                if hum.JumpPower < 50 then hum.JumpPower = 50 end
                hum.PlatformStand = false
                hum.Sit = false
                hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            end
        end)
    end
end

player.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    if Config.tinyCharEnabled then applyTinyCharacter(true) end
    if Config.customMassEnabled then applyCharacterMass(true) end
end)

UserInputService.JumpRequest:Connect(function()
    if not Config.infiniteJumpEnabled and not Config.wallhopEnabled then return end
    local char = player.Character
    if not char then return end
    local hum = getHum(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    if Config.infiniteJumpEnabled then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
        hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, Config.infJumpBoost, hrp.AssemblyLinearVelocity.Z)
    end

    if Config.wallhopEnabled then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = {char}
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        local ray = Workspace:Raycast(hrp.Position, hrp.CFrame.LookVector * 3, rayParams)
        if ray and ray.Instance and ray.Instance.CanCollide then
            hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, Config.wallhopVelocity, hrp.AssemblyLinearVelocity.Z) + (ray.Normal * 15)
        end
    end
end)

local function toggleAirWalk(state)
    Config.airWalkEnabled = state
    if state then
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            airWalkLockedY = hrp.Position.Y - 3.2
            airWalkPart.Position = Vector3.new(hrp.Position.X, airWalkLockedY, hrp.Position.Z)
            airWalkPart.Parent = Workspace
            Conns.airWalk = RunService.Heartbeat:Connect(function()
                if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local curHrp = player.Character.HumanoidRootPart
                    local tgt = curHrp.Position.Y - 3.2
                    if tgt > airWalkLockedY then airWalkLockedY = tgt end
                    airWalkPart.Position = Vector3.new(curHrp.Position.X, airWalkLockedY, curHrp.Position.Z)
                end
            end)
        end
    else
        if Conns.airWalk then
            Conns.airWalk:Disconnect()
            Conns.airWalk = nil
        end
        airWalkLockedY = 0
        airWalkPart.Parent = nil
    end
end

local function toggleSpider(state)
    Config.spiderEnabled = state
    if state then
        Conns.spider = RunService.Stepped:Connect(function()
            local char = player.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = getHum(char)
            if not hrp or not hum then return end
            if hum.MoveDirection.Magnitude > 0 then
                local rayParams = RaycastParams.new()
                rayParams.FilterType = Enum.RaycastFilterType.Exclude
                rayParams.FilterDescendantsInstances = {char, airWalkPart}
                local ray = Workspace:Raycast(hrp.Position, hrp.CFrame.LookVector * 2.5, rayParams)
                if ray and ray.Instance and ray.Instance.CanCollide then
                    hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 35, hrp.AssemblyLinearVelocity.Z)
                end
            end
        end)
    else
        if Conns.spider then
            Conns.spider:Disconnect()
            Conns.spider = nil
        end
    end
end

local function toggleFly(state)
    Config.flyEnabled = state
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = getHum(char)
    if not hrp or not hum then return end

    if state then
        hum.PlatformStand = true
        flyBodyGyro = Instance.new("BodyGyro")
        flyBodyGyro.P = 9e4
        flyBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        flyBodyGyro.CFrame = hrp.CFrame
        flyBodyGyro.Parent = hrp

        flyBodyVelocity = Instance.new("BodyVelocity")
        flyBodyVelocity.Velocity = Vector3.zero
        flyBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        flyBodyVelocity.Parent = hrp

        Conns.fly = RunService.RenderStepped:Connect(function()
            flyBodyGyro.CFrame = Workspace.CurrentCamera.CFrame
            local move = Vector3.zero
            if flyKeys.forward then move = move + Workspace.CurrentCamera.CFrame.LookVector end
            if flyKeys.backward then move = move - Workspace.CurrentCamera.CFrame.LookVector end
            if flyKeys.left then move = move - Workspace.CurrentCamera.CFrame.RightVector end
            if flyKeys.right then move = move + Workspace.CurrentCamera.CFrame.RightVector end
            if flyKeys.up then move = move + Vector3.new(0, 1, 0) end
            if flyKeys.down then move = move - Vector3.new(0, 1, 0) end
            flyBodyVelocity.Velocity = move.Magnitude > 0 and move.Unit * Config.flySpeed or Vector3.zero
        end)
    else
        if Conns.fly then Conns.fly:Disconnect(); Conns.fly = nil end
        if flyBodyGyro then flyBodyGyro:Destroy(); flyBodyGyro = nil end
        if flyBodyVelocity then flyBodyVelocity:Destroy(); flyBodyVelocity = nil end
        hum.PlatformStand = false
    end
end

local function toggleNoclip(state)
    Config.noclipEnabled = state
    if Conns.noclip then Conns.noclip:Disconnect(); Conns.noclip = nil end
    if state then
        Conns.noclip = RunService.Stepped:Connect(function()
            if player.Character then
                for _, p in pairs(player.Character:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
                end
            end
        end)
    else
        if player.Character then
            for _, p in pairs(player.Character:GetDescendants()) do
                if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.CanCollide = true end
            end
        end
    end
end

local function toggleSpinbot(state)
    Config.spinbotEnabled = state
    if state then
        Conns.spinbot = RunService.Stepped:Connect(function()
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                player.Character.HumanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, Config.spinbotSpeed, 0)
            end
        end)
    else
        if Conns.spinbot then Conns.spinbot:Disconnect(); Conns.spinbot = nil end
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            player.Character.HumanoidRootPart.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

local function toggleWalkFling(state)
    Config.walkFlingEnabled = state
    if state then
        Conns.walkFling = RunService.Heartbeat:Connect(function()
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local vel = hrp.AssemblyLinearVelocity
                hrp.AssemblyLinearVelocity = vel * 10000 + Vector3.new(0, 10000, 0)
                RunService.RenderStepped:Wait()
                if hrp and hrp.Parent then hrp.AssemblyLinearVelocity = vel end
            end
        end)
    else
        if Conns.walkFling then Conns.walkFling:Disconnect(); Conns.walkFling = nil end
    end
end

local function toggleAntiFling(state)
    Config.antiFlingEnabled = state
    if Conns.antiFling then Conns.antiFling:Disconnect(); Conns.antiFling = nil end
    if state then
        Conns.antiFling = RunService.Stepped:Connect(function()
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= player and p.Character then
                    for _, part in pairs(p.Character:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
                    end
                end
            end
        end)
    else
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                for _, part in pairs(p.Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then part.CanCollide = true end
                end
            end
        end
    end
end

local function toggleAntiVoid(state)
    Config.antiVoidEnabled = state
    if state then
        Conns.antiVoid = RunService.Heartbeat:Connect(function()
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if hrp and hrp.Position.Y < (Workspace.FallenPartsDestroyHeight + 20) then
                hrp.AssemblyLinearVelocity = Vector3.new(0, 150, 0)
            end
        end)
    else
        if Conns.antiVoid then Conns.antiVoid:Disconnect(); Conns.antiVoid = nil end
    end
end

local function toggleAntiRagdoll(state)
    Config.antiRagdollEnabled = state
    if state then
        Conns.antiRagdoll = RunService.Stepped:Connect(function()
            local hum = getHum(player.Character)
            if hum then
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                local cState = hum:GetState()
                if cState == Enum.HumanoidStateType.Ragdoll or cState == Enum.HumanoidStateType.FallingDown then
                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                end
            end
        end)
    else
        if Conns.antiRagdoll then Conns.antiRagdoll:Disconnect(); Conns.antiRagdoll = nil end
        local hum = getHum(player.Character)
        if hum then
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        end
    end
end

local function getClosestEnemyForHide(myHrp)
    local closest, minDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local hum = getHum(p.Character)
            if hum and hum.Health > 0 then
                local dist = (p.Character.HumanoidRootPart.Position - myHrp.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    closest = p.Character.HumanoidRootPart
                end
            end
        end
    end
    return closest
end

local function toggleAutoHideCombat(state)
    Config.autoHideCombatEnabled = state
    if state then
        Conns.autoHide = RunService.Stepped:Connect(function()
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = getHum(char)
            if hrp and hum then
                if hum.Health > 0 and hum.Health <= 40 and not Config.isHidingUnderground then
                    savedHidePosition = hrp.CFrame
                    Config.isHidingUnderground = true
                elseif hum.Health >= 100 and Config.isHidingUnderground then
                    hrp.CFrame = savedHidePosition
                    Config.isHidingUnderground = false
                    savedHidePosition = nil
                end
                if Config.isHidingUnderground then
                    local target = getClosestEnemyForHide(hrp)
                    if target then
                        hrp.CFrame = target.CFrame * CFrame.new(0, -4.5, 0)
                        hrp.AssemblyLinearVelocity = Vector3.zero
                    else
                        if savedHidePosition then
                            hrp.CFrame = savedHidePosition * CFrame.new(0, -15, 0)
                            hrp.AssemblyLinearVelocity = Vector3.zero
                        end
                    end
                end
            end
        end)
    else
        if Conns.autoHide then Conns.autoHide:Disconnect(); Conns.autoHide = nil end
        if Config.isHidingUnderground and savedHidePosition then
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.CFrame = savedHidePosition end
        end
        Config.isHidingUnderground = false
        savedHidePosition = nil
    end
end

local function getClosestTargetToCenter()
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    local closestTarget = nil
    local shortestDistance = Config.fovRadius
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local hum = p.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local pos, onScreen = cam:WorldToViewportPoint(p.Character.HumanoidRootPart.Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    if dist <= shortestDistance then
                        shortestDistance = dist
                        closestTarget = p.Character.HumanoidRootPart
                    end
                end
            end
        end
    end
    if Config.aimbotTargetBots then
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Model") and obj ~= player.Character and not Players:GetPlayerFromCharacter(obj) then
                local hrp = obj:FindFirstChild("HumanoidRootPart")
                local hum = obj:FindFirstChildOfClass("Humanoid")
                if hrp and hum and hum.Health > 0 then
                    local pos, onScreen = cam:WorldToViewportPoint(hrp.Position)
                    if onScreen then
                        local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                        if dist <= shortestDistance then
                            shortestDistance = dist
                            closestTarget = hrp
                        end
                    end
                end
            end
        end
    end
    return closestTarget
end

local function applyEspLabel(targetChar, displayName, name)
    local head = targetChar:FindFirstChild("Head") or targetChar:FindFirstChild("HumanoidRootPart")
    if head and not head:FindFirstChild("BHUB_ESP_BG") then
        local bg = Instance.new("BillboardGui")
        bg.Name = "BHUB_ESP_BG"
        bg.Adornee = head
        bg.Size = UDim2.new(0, 200, 0, 50)
        bg.StudsOffset = Vector3.new(0, 3, 0)
        bg.AlwaysOnTop = true
        local txt = Instance.new("TextLabel")
        txt.Size = UDim2.new(1, 0, 1, 0)
        txt.BackgroundTransparency = 1
        txt.TextColor3 = Color3.fromRGB(255, 255, 255)
        txt.TextStrokeTransparency = 0
        txt.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        txt.Font = Enum.Font.GothamBold
        txt.TextSize = 12
        txt.Text = displayName .. " (@" .. name .. ")"
        txt.Parent = bg
        bg.Parent = head
        return txt
    end
    return head and head:FindFirstChild("BHUB_ESP_BG") and head.BHUB_ESP_BG:FindFirstChildOfClass("TextLabel")
end

local function toggleEspWrapper(state)
    Config.espEnabled = state
    if not state then
        for _, hl in pairs(espHighlights) do
            if hl and hl.Parent then hl:Destroy() end
        end
        espHighlights = {}
        for _, txt in pairs(espLabels) do
            if txt and txt.Parent and txt.Parent.Parent then
                txt.Parent.Parent:Destroy()
            end
        end
        espLabels = {}
    end
end

RunService.RenderStepped:Connect(function()
    if Config.espEnabled then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local char = p.Character
                if not char:FindFirstChild("BHUB_ESP_HL") then
                    local hl = Instance.new("Highlight")
                    hl.Name = "BHUB_ESP_HL"
                    hl.FillColor = Color3.fromRGB(255, 255, 255)
                    hl.FillTransparency = 0.4
                    hl.OutlineColor = Theme.Accent
                    hl.OutlineTransparency = 0
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Parent = char
                    table.insert(espHighlights, hl)
                end
                if not espLabels[p] then
                    espLabels[p] = applyEspLabel(char, p.DisplayName, p.Name)
                end
            end
        end
        local myHrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        for targetPlayer, txtLabel in pairs(espLabels) do
            if targetPlayer and targetPlayer.Character and txtLabel.Parent then
                local targetHrp = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
                if targetHrp then
                    local dist = myHrp and math.floor((myHrp.Position - targetHrp.Position).Magnitude) or 0
                    txtLabel.Text = string.format("%s (@%s)\n[%d Studs]", targetPlayer.DisplayName, targetPlayer.Name, dist)
                end
            end
        end
    end
    if Config.aimbotEnabled then
        local target = getClosestTargetToCenter()
        if target then
            local cam = Workspace.CurrentCamera
            local smoothFactor = Config.aimbotSmoothness / 10
            cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, target.Position), smoothFactor)
        end
    end
end)

local function updateXrayPart(part)
    if part:IsA("BasePart") then
        local model = part:FindFirstAncestorOfClass("Model")
        if model and model:FindFirstChildOfClass("Humanoid") then return end
        if Config.xrayEnabled then
            if not _originalTransparencies[part] then
                _originalTransparencies[part] = part.Transparency
            end
            part.Transparency = Config.xrayTransparency
        else
            if _originalTransparencies[part] then
                part.Transparency = _originalTransparencies[part]
                _originalTransparencies[part] = nil
            end
        end
    end
end

local function toggleXray(state)
    Config.xrayEnabled = state
    for _, v in pairs(Workspace:GetDescendants()) do updateXrayPart(v) end
    if state then
        if not Conns.xray then
            Conns.xray = Workspace.DescendantAdded:Connect(function(v)
                task.wait(0.1)
                if Config.xrayEnabled then updateXrayPart(v) end
            end)
        end
    else
        if Conns.xray then Conns.xray:Disconnect(); Conns.xray = nil end
        for part, trans in pairs(_originalTransparencies) do
            if part and part.Parent then part.Transparency = trans end
        end
        _originalTransparencies = {}
    end
end

local function toggleFullbright(state)
    Config.fullbrightEnabled = state
    if not state then
        Lighting.Brightness = _originalLighting.Brightness
        Lighting.ClockTime = _originalLighting.ClockTime
        Lighting.FogEnd = _originalLighting.FogEnd
        Lighting.GlobalShadows = _originalLighting.GlobalShadows
        Lighting.OutdoorAmbient = _originalLighting.OutdoorAmbient
        Lighting.Ambient = _originalLighting.Ambient
    end
end

local function toggleThirdPerson(state)
    Config.thirdPersonEnabled = state
    if not state then
        player.CameraMode = Enum.CameraMode.Classic
        player.CameraMinZoomDistance = 0.5
        player.CameraMaxZoomDistance = 128
    end
end

local function toggleMouseUnlock(state)
    Config.mouseUnlockEnabled = state
end

local function teleportToMouse()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local mouseLocation = UserInputService:GetMouseLocation()
    local unitRay = Workspace.CurrentCamera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {char, airWalkPart}
    local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, rayParams)
    if result and result.Position then
        hrp.CFrame = CFrame.new(result.Position + Vector3.new(0, 3.5, 0), result.Position + Vector3.new(0, 3.5, 0) + hrp.CFrame.LookVector)
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
end

local function updateFov()
    if BHUB.FovCircle then
        BHUB.FovCircle.Size = UDim2.new(0, Config.fovRadius * 2, 0, Config.fovRadius * 2)
        BHUB.FovCircle.Visible = Config.showFovEnabled
    end
end

BHUB.performDash = performDash
BHUB.applyCharacterMass = applyCharacterMass
BHUB.permaKillCharacter = permaKillCharacter
BHUB.applyTinyCharacter = applyTinyCharacter
BHUB.toggleUnlockMovement = toggleUnlockMovement
BHUB.toggleAirWalk = toggleAirWalk
BHUB.toggleSpider = toggleSpider
BHUB.toggleFly = toggleFly
BHUB.toggleNoclip = toggleNoclip
BHUB.toggleSpinbot = toggleSpinbot
BHUB.toggleWalkFling = toggleWalkFling
BHUB.toggleAntiFling = toggleAntiFling
BHUB.toggleAntiVoid = toggleAntiVoid
BHUB.toggleAntiRagdoll = toggleAntiRagdoll
BHUB.toggleAutoHideCombat = toggleAutoHideCombat
BHUB.toggleEspWrapper = toggleEspWrapper
BHUB.toggleXray = toggleXray
BHUB.toggleFullbright = toggleFullbright
BHUB.toggleThirdPerson = toggleThirdPerson
BHUB.toggleMouseUnlock = toggleMouseUnlock
BHUB.teleportToMouse = teleportToMouse
BHUB.updateFov = updateFov
BHUB.flyKeys = flyKeys
BHUB.airWalkPart = airWalkPart
