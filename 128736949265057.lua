--// Nexus Event Auto-Parry (With Wind-up Delay Adjustments)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--// CONFIGURATION STATE
local Options = {
    Enabled = true,
    StrikeZone = 7.0,     -- Range threshold
    ReactionDelay = 0.20,   -- Delayed timing in seconds (Configurable via new UI slider)
    MaxScanDistance = 50,  
    Cooldown = 0.25,       
    HoldDuration = 0.05    
}

local PlayerTrackers = {}  
local CoreConnections = {} 
local LastParryTime = 0
local StatusFootnote = nil

--// CLEANUP & SHUTDOWN
local function CleanUp()
    _G.TrackerActive = false
    
    for _, conn in pairs(CoreConnections) do
        if conn then conn:Disconnect() end
    end
    CoreConnections = {}
    
    for pl, connections in pairs(PlayerTrackers) do
        for _, connection in pairs(connections) do
            if connection then connection:Disconnect() end
        end
    end
    PlayerTrackers = {}
    
    local oldGui = PlayerGui:FindFirstChild("ParryV6_UI")
    if oldGui then oldGui:Destroy() end
    
    print("[PARRY SYSTEM] Safely stopped.")
end

local oldGui = PlayerGui:FindFirstChild("ParryV6_UI")
if oldGui then CleanUp() task.wait(0.1) end

_G.TrackerActive = true

--// PHYSICAL INPUT EMULATION
local function SimulateFPress()
    task.spawn(function()
        if keypress and keyrelease then
            keypress(0x46)
            task.wait(Options.HoldDuration)
            keyrelease(0x46)
        elseif presskey and releasekey then
            presskey(0x46)
            task.wait(Options.HoldDuration)
            releasekey(0x46)
        else
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
            task.wait(Options.HoldDuration)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        end
    end)
end

--// TRIGGER BLOCK MECHANISM
local function TriggerParry(enemyName)
    local now = os.clock()
    if now - LastParryTime < Options.Cooldown then return end
    LastParryTime = now
    
    -- Execute weapon-specific wind-up frame delay
    if Options.ReactionDelay > 0 then
        task.wait(Options.ReactionDelay)
    end
    
    if StatusFootnote then
        StatusFootnote.Text = string.format("⚡ BLOCKED: %s (%.2fs delay) ⚡", string.upper(enemyName), Options.ReactionDelay)
        StatusFootnote.TextColor3 = Color3.fromRGB(240, 70, 70)
        task.delay(0.4, function()
            if StatusFootnote then 
                StatusFootnote.Text = "SYSTEM MONITORING..."
                StatusFootnote.TextColor3 = Color3.fromRGB(0, 180, 214) 
            end
        end)
    end
    
    SimulateFPress()
end

--// DIRECT SWING EVALUATION
local function evaluateSwing(player, character)
    if not Options.Enabled or not _G.TrackerActive then return end
    if player.Team == LocalPlayer.Team and LocalPlayer.Team ~= nil then return end
    
    local myChar = LocalPlayer.Character
    if not myChar then return end
    
    local myRoot = myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso")
    local enemyRoot = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
    if not myRoot or not enemyRoot then return end
    
    local distance = (enemyRoot.Position - myRoot.Position).Magnitude
    
    if distance <= Options.StrikeZone then
        task.spawn(TriggerParry, player.Name)
    end
end

--// UN-GATED EVENT COUPLING
local function stopTrackingPlayer(player)
    if PlayerTrackers[player] then
        for _, connection in pairs(PlayerTrackers[player]) do
            if connection then connection:Disconnect() end
        end
        PlayerTrackers[player] = nil
    end
end

local function hookCombatListeners(player, character)
    stopTrackingPlayer(player)
    PlayerTrackers[player] = {}
    
    local humanoid = character:WaitForChild("Humanoid", 7)
    if not humanoid then return end
    
    local animator = humanoid:WaitForChild("Animator", 5) or humanoid
    
    PlayerTrackers[player]["AnimHook"] = animator.AnimationPlayed:Connect(function(track)
        local name = string.lower(track.Name or "")
        if string.find(name, "swing") or string.find(name, "slash") or string.find(name, "punch") 
        or string.find(name, "attack") or string.find(name, "m1") or string.find(name, "heavy")
        or string.find(name, "hit") or string.find(name, "strike") or string.find(name, "use") then
            evaluateSwing(player, character)
        end
    end)
    
    PlayerTrackers[player]["AttributeHook"] = character.AttributeChanged:Connect(function(attribute)
        local lowerAttr = string.lower(attribute)
        if string.find(lowerAttr, "attack") or string.find(lowerAttr, "swing") or string.find(lowerAttr, "heavy") or string.find(lowerAttr, "active") then
            local value = character:GetAttribute(attribute)
            if value == true or type(value) == "number" then
                evaluateSwing(player, character)
            end
        end
    end)
end

local function trackPlayer(player)
    if player == LocalPlayer then return end
    player.CharacterAdded:Connect(function(char) hookCombatListeners(player, char) end)
    if player.Character then hookCombatListeners(player, player.Character) end
end

for _, player in ipairs(Players:GetPlayers()) do trackPlayer(player) end
CoreConnections["PlayerAdded"] = Players.PlayerAdded:Connect(trackPlayer)
CoreConnections["PlayerRemoving"] = Players.PlayerRemoving:Connect(stopTrackingPlayer)

--// UI ASSEMBLY
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ParryV6_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 280, 0, 240)
Frame.Position = UDim2.new(0.05, 0, 0.4, 0)
Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
Frame.BorderSizePixel = 0
Frame.Active = true
Frame.Draggable = true 
Frame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = Frame

local Header = Instance.new("TextLabel")
Header.Size = UDim2.new(1, 0, 0, 35)
Header.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
Header.Text = "   NEXUS DELAYED MELEE PARRIER"
Header.TextColor3 = Color3.fromRGB(255, 255, 255)
Header.TextXAlignment = Enum.TextXAlignment.Left
Header.Font = Enum.Font.GothamBold
Header.TextSize = 11
Header.Parent = Frame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 8)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 35, 0, 35)
CloseBtn.Position = UDim2.new(1, -35, 0, 0)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(240, 70, 70)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = Header
CloseBtn.MouseButton1Click:Connect(CleanUp)

local function CreateToggle(name, yPos, default, callback)
    local state = default
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, -20, 0, 32)
    Btn.Position = UDim2.new(0, 10, 0, yPos)
    Btn.BackgroundColor3 = state and Color3.fromRGB(0, 180, 214) or Color3.fromRGB(35, 35, 40)
    Btn.Text = name .. ": " .. (state and "ON" or "OFF")
    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Btn.Font = Enum.Font.GothamSemibold
    Btn.TextSize = 11
    Btn.Parent = Frame
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)

    Btn.MouseButton1Click:Connect(function()
        state = not state
        Btn.BackgroundColor3 = state and Color3.fromRGB(0, 180, 214) or Color3.fromRGB(35, 35, 40)
        Btn.Text = name .. ": " .. (state and "ON" or "OFF")
        callback(state)
    end)
end

CreateToggle("Master Parry Switch", 50, Options.Enabled, function(val) Options.Enabled = val end)

-- SLIDER 1: TRIGGER RANGE
local RangeLabel = Instance.new("TextLabel")
RangeLabel.Size = UDim2.new(1, -20, 0, 20)
RangeLabel.Position = UDim2.new(0, 10, 0, 95)
RangeLabel.BackgroundTransparency = 1
RangeLabel.Text = "Parry Activation Radius: " .. Options.StrikeZone .. " studs"
RangeLabel.TextColor3 = Color3.fromRGB(180, 180, 185)
RangeLabel.Font = Enum.Font.Gotham
RangeLabel.TextSize = 10
RangeLabel.TextXAlignment = Enum.TextXAlignment.Left
RangeLabel.Parent = Frame

local RangeSlider = Instance.new("TextButton")
RangeSlider.Size = UDim2.new(1, -20, 0, 8)
RangeSlider.Position = UDim2.new(0, 10, 0, 120)
RangeSlider.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
RangeSlider.Text = ""
RangeSlider.Parent = Frame
Instance.new("UICorner", RangeSlider).CornerRadius = UDim.new(0, 4)

local SliderFill = Instance.new("Frame")
SliderFill.Size = UDim2.new((Options.StrikeZone - 2) / 28, 0, 1, 0) 
SliderFill.BackgroundColor3 = Color3.fromRGB(0, 180, 214)
SliderFill.BorderSizePixel = 0
SliderFill.Parent = RangeSlider
Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(0, 4)

local function UpdateRangeSlider(input)
    local percent = math.clamp((input.Position.X - RangeSlider.AbsolutePosition.X) / RangeSlider.AbsoluteSize.X, 0, 1)
    SliderFill.Size = UDim2.new(percent, 0, 1, 0)
    Options.StrikeZone = math.round((2 + (percent * 28)) * 10) / 10
    RangeLabel.Text = "Parry Activation Radius: " .. Options.StrikeZone .. " studs"
end

local DraggingRange = false
RangeSlider.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then DraggingRange = true end end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then DraggingRange = false end end)
UserInputService.InputChanged:Connect(function(input)
    if DraggingRange and input.UserInputType == Enum.UserInputType.MouseMovement then UpdateRangeSlider(input) end
end)


-- SLIDER 2: WIND-UP DELAY
local DelayLabel = Instance.new("TextLabel")
DelayLabel.Size = UDim2.new(1, -20, 0, 20)
DelayLabel.Position = UDim2.new(0, 10, 0, 145)
DelayLabel.BackgroundTransparency = 1
DelayLabel.Text = "Wind-Up Parry Delay: " .. string.format("%.2f", Options.ReactionDelay) .. "s"
DelayLabel.TextColor3 = Color3.fromRGB(180, 180, 185)
DelayLabel.Font = Enum.Font.Gotham
DelayLabel.TextSize = 10
DelayLabel.TextXAlignment = Enum.TextXAlignment.Left
DelayLabel.Parent = Frame

local DelaySlider = Instance.new("TextButton")
DelaySlider.Size = UDim2.new(1, -20, 0, 8)
DelaySlider.Position = UDim2.new(0, 10, 0, 170)
DelaySlider.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
DelaySlider.Text = ""
DelaySlider.Parent = Frame
Instance.new("UICorner", DelaySlider).CornerRadius = UDim.new(0, 4)

local DelayFill = Instance.new("Frame")
DelayFill.Size = UDim2.new(Options.ReactionDelay / 1.0, 0, 1, 0) -- 0.0s to 1.0s slider mapping
DelayFill.BackgroundColor3 = Color3.fromRGB(0, 180, 214)
DelayFill.BorderSizePixel = 0
DelayFill.Parent = DelaySlider
Instance.new("UICorner", DelayFill).CornerRadius = UDim.new(0, 4)

local function UpdateDelaySlider(input)
    local percent = math.clamp((input.Position.X - DelaySlider.AbsolutePosition.X) / DelaySlider.AbsoluteSize.X, 0, 1)
    DelayFill.Size = UDim2.new(percent, 0, 1, 0)
    Options.ReactionDelay = math.round((percent * 1.0) * 100) / 100
    DelayLabel.Text = "Wind-Up Parry Delay: " .. string.format("%.2f", Options.ReactionDelay) .. "s"
end

local DraggingDelay = false
DelaySlider.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then DraggingDelay = true end end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then DraggingDelay = false end end)
UserInputService.InputChanged:Connect(function(input)
    if DraggingDelay and input.UserInputType == Enum.UserInputType.MouseMovement then UpdateDelaySlider(input) end
end)


StatusFootnote = Instance.new("TextLabel")
StatusFootnote.Size = UDim2.new(1, -20, 0, 25)
StatusFootnote.Position = UDim2.new(0, 10, 1, -30)
StatusFootnote.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
StatusFootnote.Text = "SYSTEM ACTIVE"
StatusFootnote.TextColor3 = Color3.fromRGB(0, 180, 214)
StatusFootnote.Font = Enum.Font.Code
StatusFootnote.TextSize = 10
StatusFootnote.Parent = Frame
Instance.new("UICorner", StatusFootnote).CornerRadius = UDim.new(0, 4)
