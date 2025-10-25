local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local LocalPlayer = Players.LocalPlayer

local flying = false
local noclipEnabled = false
local espEnabled = false
local flySpeed = 60

local highlights = {}
local flyConnection, noclipConnection, bodyGyro, bodyVelocity, rotateConnection
local rotationSpeed = math.rad(720)

local roleColors = {
    Murderer = Color3.fromRGB(255,0,0),
    Sheriff = Color3.fromRGB(0,100,255),
    Innocent = Color3.fromRGB(0,255,0)
}

local function safeDestroy(obj)
    if obj and obj.Destroy then
        pcall(function() obj:Destroy() end)
    end
end

local function getPlayerRole(player)
    local pdata = ReplicatedStorage:FindFirstChild("PlayerData")
    if pdata and pdata:FindFirstChild(player.Name) and pdata[player.Name]:FindFirstChild("Role") then
        return pdata[player.Name].Role.Value
    end
    if player.Character then
        if player.Character:FindFirstChild("Knife") then return "Murderer" end
        if player.Character:FindFirstChild("Gun") then return "Sheriff" end
    end
    return "Innocent"
end

local function updateESP()
    for char, hl in pairs(highlights) do
        if not char or not char.Parent then
            safeDestroy(hl)
            highlights[char] = nil
        end
    end
    
    if not espEnabled then 
        for _, hl in pairs(highlights) do 
            safeDestroy(hl) 
        end
        highlights = {}
        return 
    end
    
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local char = p.Character
            
            if highlights[char] and highlights[char].Parent then
                local role = getPlayerRole(p)
                local col = roleColors[role] or Color3.new(1,1,1)
                highlights[char].FillColor = col
                highlights[char].OutlineColor = col
            else
                local role = getPlayerRole(p)
                local col = roleColors[role] or Color3.new(1,1,1)
                local hl = Instance.new("Highlight")
                hl.Parent = char
                hl.Adornee = char
                hl.FillColor = col
                hl.OutlineColor = col
                hl.FillTransparency = 0.6
                hl.OutlineTransparency = 0
                highlights[char] = hl
            end
        end
    end
end

local function createGui()
    local existingGui = PlayerGui:FindFirstChild("Def1x")
    if existingGui then
        existingGui:Destroy()
    end
    
    local screenGui = Instance.new("ScreenGui", PlayerGui)
    screenGui.Name = "Def1x"
    screenGui.ResetOnSpawn = false
    
    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    
    local frame = Instance.new("Frame", screenGui)
    frame.Size = UDim2.new(0, 500, 0, 750)
    frame.Position = UDim2.new(0.5, -250, 0.5, -375)
    frame.BackgroundColor3 = Color3.fromRGB(20, 24, 49)
    frame.Active, frame.Draggable = true, true
    frame.ClipsDescendants = true
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
    
    local function createButton(txt, x, y)
        local btn = Instance.new("TextButton", frame)
        btn.Size = UDim2.new(0, 220, 0, 52)
        btn.Position = UDim2.new(0, x, 0, y)
        btn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 22
        btn.Text = txt
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
        return btn
    end
    
    local titleLabel = Instance.new("TextLabel", frame)
    titleLabel.Size = UDim2.new(1, -100, 0, 40)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.new(1, 1, 1)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 28
    titleLabel.Text = "Def1x"
    
    local minimizeBtn = Instance.new("TextButton", frame)
    minimizeBtn.Size = UDim2.new(0, 40, 0, 40)
    minimizeBtn.Position = UDim2.new(1, -100, 0, 5)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
    minimizeBtn.Text = "-"
    minimizeBtn.TextColor3 = Color3.new(1, 1, 1)
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.TextSize = 28
    Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 8)
    
    local closeBtn = Instance.new("TextButton", frame)
    closeBtn.Size = UDim2.new(0, 40, 0, 40)
    closeBtn.Position = UDim2.new(1, -50, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 24
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
        if rotateConnection then rotateConnection:Disconnect() rotateConnection = nil end
    end)

    local buttonSpacingY = 98
    local espBtn = createButton("ESP: OFF", 20, 60)
    local flyBtn = createButton("Fly: OFF", 260, 60)
    local noclipBtn = createButton("Noclip: OFF", 20, 60 + buttonSpacingY)
    local tpBtn = createButton("Teleport", 260, 60 + buttonSpacingY)
    local stopSpinBtn = createButton("Stop Spin", 20, 60 + buttonSpacingY * 2)
    local spinBtn = createButton("Spin Around", 260, 60 + buttonSpacingY * 2)
    local killAllBtn = createButton("Kill All", 140, 60 + buttonSpacingY * 3)

    local isMinimized = false
    local originalSize = frame.Size
    local minimizedSize = UDim2.new(0, 500, 0, 50)
    
    minimizeBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        if isMinimized then
            frame:TweenSize(minimizedSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
            minimizeBtn.Text = "+"
        else
            frame:TweenSize(originalSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
            minimizeBtn.Text = "-"
        end
    end)

    local sliderGui = Instance.new("Frame", screenGui)
    sliderGui.Size = UDim2.new(0, 220, 0, 80)
    sliderGui.Position = UDim2.new(0, frame.AbsolutePosition.X + frame.AbsoluteSize.X + 10, 0, frame.AbsolutePosition.Y + 50)
    sliderGui.BackgroundColor3 = Color3.fromRGB(35, 35, 70)
    sliderGui.BorderSizePixel = 0
    sliderGui.Visible = false
    sliderGui.Active = true
    sliderGui.Draggable = true
    Instance.new("UICorner", sliderGui).CornerRadius = UDim.new(0, 12)

    local flySpeedSliderTrack = Instance.new("Frame", sliderGui)
    flySpeedSliderTrack.Size = UDim2.new(0.7, 0, 0, 20)
    flySpeedSliderTrack.Position = UDim2.new(0, 15, 0, 30)
    flySpeedSliderTrack.BackgroundColor3 = Color3.fromRGB(70, 70, 140)
    flySpeedSliderTrack.BorderSizePixel = 0
    flySpeedSliderTrack.ClipsDescendants = true
    Instance.new("UICorner", flySpeedSliderTrack).CornerRadius = UDim.new(0, 10)

    local flySpeedSliderHandle = Instance.new("Frame", flySpeedSliderTrack)
    flySpeedSliderHandle.Size = UDim2.new(0, 20, 1, 0)
    flySpeedSliderHandle.Position = UDim2.new((flySpeed - 10) / 190, 0, 0, 0)
    flySpeedSliderHandle.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
    flySpeedSliderHandle.BorderSizePixel = 0
    Instance.new("UICorner", flySpeedSliderHandle).CornerRadius = UDim.new(1, 0)

    local sliderSpeedLabel = Instance.new("TextLabel", sliderGui)
    sliderSpeedLabel.Size = UDim2.new(0, 40, 0, 22)
    sliderSpeedLabel.Position = UDim2.new(1, -45, 0, 27)
    sliderSpeedLabel.BackgroundTransparency = 1
    sliderSpeedLabel.TextColor3 = Color3.new(1, 1, 1)
    sliderSpeedLabel.Font = Enum.Font.GothamBold
    sliderSpeedLabel.TextSize = 19
    sliderSpeedLabel.Text = tostring(flySpeed)

    local draggingSlider = false

    local function updateFlySpeedFromSlider(px)
        local trackAbsPos = flySpeedSliderTrack.AbsolutePosition.X
        local trackSize = flySpeedSliderTrack.AbsoluteSize.X
        local relativeX = math.clamp(px - trackAbsPos, 0, trackSize)
        local percent = relativeX / trackSize
        flySpeedSliderHandle.Position = UDim2.new(percent, 0, 0, 0)
        flySpeed = math.floor(10 + percent * 190 + 0.5)
        sliderSpeedLabel.Text = tostring(flySpeed)
    end

    local function onSliderInputBegan(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = true
            sliderGui.Draggable = false
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    draggingSlider = false
                    sliderGui.Draggable = true
                end
            end)
        end
    end
    flySpeedSliderHandle.InputBegan:Connect(onSliderInputBegan)
    flySpeedSliderTrack.InputBegan:Connect(onSliderInputBegan)
    UserInputService.InputChanged:Connect(function(input)
        if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFlySpeedFromSlider(input.Position.X)
        end
    end)
    flySpeedSliderTrack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            updateFlySpeedFromSlider(input.Position.X)
        end
    end)
    flyBtn.MouseButton2Click:Connect(function()
        sliderGui.Visible = not sliderGui.Visible
    end)

    local mobileControlsFrame
    if isMobile then
        mobileControlsFrame = Instance.new("Frame", screenGui)
        mobileControlsFrame.Size = UDim2.new(0, 300, 0, 300)
        mobileControlsFrame.Position = UDim2.new(0, 10, 1, -310)
        mobileControlsFrame.BackgroundTransparency = 1
        mobileControlsFrame.Visible = false
        
        local function createMobileButton(txt, pos, size)
            local btn = Instance.new("TextButton", mobileControlsFrame)
            btn.Size = size or UDim2.new(0, 80, 0, 80)
            btn.Position = pos
            btn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
            btn.BackgroundTransparency = 0.3
            btn.TextColor3 = Color3.new(1, 1, 1)
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 24
            btn.Text = txt
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 15)
            return btn
        end
        
        local upBtn = createMobileButton("↑", UDim2.new(0.5, -40, 0, 0))
        local downBtn = createMobileButton("↓", UDim2.new(0.5, -40, 1, -80))
        local leftBtn = createMobileButton("←", UDim2.new(0, 0, 0.5, -40))
        local rightBtn = createMobileButton("→", UDim2.new(1, -80, 0.5, -40))
        local forwardBtn = createMobileButton("W", UDim2.new(0.5, -40, 0, 85))
        local backBtn = createMobileButton("S", UDim2.new(0.5, -40, 1, -165))
        local speedBtn = createMobileButton("⚙", UDim2.new(1, -90, 0, 10), UDim2.new(0, 70, 0, 50))
        
        speedBtn.MouseButton1Click:Connect(function()
            sliderGui.Visible = not sliderGui.Visible
        end)
    end

    espBtn.MouseButton1Click:Connect(function()
        espEnabled = not espEnabled
        espBtn.Text = espEnabled and "ESP: ON" or "ESP: OFF"
        updateESP()
    end)

    flyBtn.MouseButton1Click:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        if flying then
            flying = false
            flyBtn.Text = "Fly: OFF"
            if flyConnection then flyConnection:Disconnect() flyConnection = nil end
            safeDestroy(bodyGyro)
            bodyGyro = nil
            safeDestroy(bodyVelocity)
            bodyVelocity = nil
            if mobileControlsFrame then mobileControlsFrame.Visible = false end
            for _, p in pairs(char:GetChildren()) do
                if p:IsA("BasePart") then p.CanCollide = true end
            end
        else
            flying = true
            flyBtn.Text = "Fly: ON"
            if mobileControlsFrame then mobileControlsFrame.Visible = true end
            for _, p in pairs(char:GetChildren()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
            bodyGyro = Instance.new("BodyGyro", hrp)
            bodyGyro.MaxTorque = Vector3.new(9e5, 9e5, 9e5)
            bodyGyro.P = 12000
            bodyGyro.D = 1000
            bodyVelocity = Instance.new("BodyVelocity", hrp)
            bodyVelocity.MaxForce = Vector3.new(9e5, 9e5, 9e5)
            bodyVelocity.Velocity = Vector3.new(0, 0, 0)
            
            local mobileDirection = Vector3.new(0, 0, 0)
            
            if isMobile then
                local upBtn = mobileControlsFrame:FindFirstChild("↑")
                local downBtn = mobileControlsFrame:FindFirstChild("↓")
                local leftBtn = mobileControlsFrame:FindFirstChild("←")
                local rightBtn = mobileControlsFrame:FindFirstChild("→")
                local forwardBtn = mobileControlsFrame:FindFirstChild("W")
                local backBtn = mobileControlsFrame:FindFirstChild("S")
                
                upBtn.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch then
                        mobileDirection = mobileDirection + Vector3.new(0, 1, 0)
                    end
                end)
                upBtn.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch then
                        mobileDirection = mobileDirection - Vector3.new(0, 1, 0)
                    end
                end)
                
                downBtn.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch then
                        mobileDirection = mobileDirection - Vector3.new(0, 1, 0)
                    end
                end)
                downBtn.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch then
                        mobileDirection = mobileDirection + Vector3.new(0, 1, 0)
                    end
                end)
                
                forwardBtn.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch then
                        mobileDirection = mobileDirection + Vector3.new(0, 0, 1)
                    end
                end)
                forwardBtn.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch then
                        mobileDirection = mobileDirection - Vector3.new(0, 0, 1)
                    end
                end)
                
                backBtn.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch then
                        mobileDirection = mobileDirection - Vector3.new(0, 0, 1)
                    end
                end)
                backBtn.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch then
                        mobileDirection = mobileDirection + Vector3.new(0, 0, 1)
                    end
                end)
                
                leftBtn.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch then
                        mobileDirection = mobileDirection - Vector3.new(1, 0, 0)
                    end
                end)
                leftBtn.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch then
                        mobileDirection = mobileDirection + Vector3.new(1, 0, 0)
                    end
                end)
                
                rightBtn.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch then
                        mobileDirection = mobileDirection + Vector3.new(1, 0, 0)
                    end
                end)
                rightBtn.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch then
                        mobileDirection = mobileDirection - Vector3.new(1, 0, 0)
                    end
                end)
            end
            
            flyConnection = RunService.RenderStepped:Connect(function()
                if not flying then return end
                local cam = workspace.CurrentCamera
                local moveVec = Vector3.new()
                
                if isMobile then
                    if mobileDirection.Z ~= 0 then
                        moveVec = moveVec + cam.CFrame.LookVector * mobileDirection.Z
                    end
                    if mobileDirection.X ~= 0 then
                        moveVec = moveVec + cam.CFrame.RightVector * mobileDirection.X
                    end
                    if mobileDirection.Y ~= 0 then
                        moveVec = moveVec + Vector3.new(0, mobileDirection.Y, 0)
                    end
                else
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec += cam.CFrame.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec -= cam.CFrame.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec -= cam.CFrame.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec += cam.CFrame.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVec += Vector3.new(0, 1, 0) end
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveVec -= Vector3.new(0, 1, 0) end
                end
                
                if moveVec.Magnitude > 0 then
                    moveVec = moveVec.Unit * flySpeed
                end
                bodyVelocity.Velocity = moveVec
                bodyGyro.CFrame = CFrame.new(hrp.Position, hrp.Position + cam.CFrame.LookVector)
            end)
        end
    end)

    noclipBtn.MouseButton1Click:Connect(function()
        if noclipEnabled then
            noclipEnabled = false
            if noclipConnection then noclipConnection:Disconnect() noclipConnection = nil end
            local char = LocalPlayer.Character
            if char then
                for _, p in pairs(char:GetChildren()) do
                    if p:IsA("BasePart") then
                        p.CanCollide = true
                    end
                end
            end
            noclipBtn.Text = "Noclip: OFF"
        else
            noclipEnabled = true
            noclipBtn.Text = "Noclip: ON"
            noclipConnection = RunService.Stepped:Connect(function()
                local char = LocalPlayer.Character
                if char then
                    for _, p in pairs(char:GetChildren()) do
                        if p:IsA("BasePart") then
                            p.CanCollide = false
                        end
                    end
                end
            end)
        end
    end)

    local tpFrame = Instance.new("Frame", screenGui)
    tpFrame.Size = UDim2.new(0, 320, 0, 340)
    tpFrame.Position = UDim2.new(0.5, -460, 0.5, -180)
    tpFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 49)
    tpFrame.Visible = false
    tpFrame.Active, tpFrame.Draggable = true, true
    Instance.new("UICorner", tpFrame).CornerRadius = UDim.new(0, 12)

    local tpTitle = Instance.new("TextLabel", tpFrame)
    tpTitle.Size = UDim2.new(1, 0, 0, 40)
    tpTitle.BackgroundTransparency = 1
    tpTitle.TextColor3 = Color3.new(1, 1, 1)
    tpTitle.Font = Enum.Font.GothamBold
    tpTitle.TextSize = 24
    tpTitle.Text = "Teleport to Player"

    local tpCloseBtn = Instance.new("TextButton", tpFrame)
    tpCloseBtn.Size = UDim2.new(0, 40, 0, 40)
    tpCloseBtn.Position = UDim2.new(1, -50, 0, 0)
    tpCloseBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
    tpCloseBtn.TextColor3 = Color3.new(1, 1, 1)
    tpCloseBtn.Text = "X"
    tpCloseBtn.Font = Enum.Font.GothamBold
    tpCloseBtn.TextSize = 26
    Instance.new("UICorner", tpCloseBtn).CornerRadius = UDim.new(0, 10)
    tpCloseBtn.MouseButton1Click:Connect(function() tpFrame.Visible = false end)

    local tpList = Instance.new("ScrollingFrame", tpFrame)
    tpList.Size = UDim2.new(1, -20, 1, -50)
    tpList.Position = UDim2.new(0, 10, 0, 45)
    tpList.BackgroundColor3 = Color3.fromRGB(40, 70, 120)
    tpList.ScrollBarThickness = 8

    local tpListLayout = Instance.new("UIListLayout", tpList)
    tpListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tpListLayout.Padding = UDim.new(0, 5)

    local function clearList(list)
        for _, v in pairs(list:GetChildren()) do
            if v:IsA("TextButton") then
                safeDestroy(v)
            end
        end
    end

    local function populateTeleportList()
        clearList(tpList)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local targetHRP = p.Character.HumanoidRootPart
                if targetHRP.Position.Y > 10 then
                    local btn = Instance.new("TextButton", tpList)
                    btn.Size = UDim2.new(1, 0, 0, 30)
                    btn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
                    btn.TextColor3 = Color3.new(1, 1, 1)
                    btn.Font = Enum.Font.GothamBold
                    btn.TextSize = 18
                    btn.Text = p.Name
                    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
                    btn.MouseButton1Click:Connect(function()
                        local char = LocalPlayer.Character
                        if char then
                            local hrp = char:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                hrp.CFrame = targetHRP.CFrame * CFrame.new(0, 5, 0)
                            end
                        end
                        tpFrame.Visible = false
                    end)
                    btn.Parent = tpList
                end
            end
        end
        tpList.CanvasSize = UDim2.new(0, 0, 0, tpListLayout.AbsoluteContentSize.Y + 10)
    end
    tpBtn.MouseButton1Click:Connect(function()
        tpFrame.Visible = not tpFrame.Visible
        if tpFrame.Visible then
            populateTeleportList()
        end
    end)

    local spinFrame = Instance.new("Frame", screenGui)
    spinFrame.Size = UDim2.new(0, 320, 0, 340)
    spinFrame.Position = UDim2.new(0.5, 120, 0.5, -180)
    spinFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 49)
    spinFrame.Visible = false
    spinFrame.Active, spinFrame.Draggable = true, true
    Instance.new("UICorner", spinFrame).CornerRadius = UDim.new(0, 12)

    local spinTitle = Instance.new("TextLabel", spinFrame)
    spinTitle.Size = UDim2.new(1, 0, 0, 40)
    spinTitle.BackgroundTransparency = 1
    spinTitle.TextColor3 = Color3.new(1, 1, 1)
    spinTitle.Font = Enum.Font.GothamBold
    spinTitle.TextSize = 24
    spinTitle.Text = "Spin Around Player"

    local spinCloseBtn = Instance.new("TextButton", spinFrame)
    spinCloseBtn.Size = UDim2.new(0, 40, 0, 40)
    spinCloseBtn.Position = UDim2.new(1, -50, 0, 0)
    spinCloseBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
    spinCloseBtn.TextColor3 = Color3.new(1, 1, 1)
    spinCloseBtn.Text = "X"
    spinCloseBtn.Font = Enum.Font.GothamBold
    spinCloseBtn.TextSize = 26
    Instance.new("UICorner", spinCloseBtn).CornerRadius = UDim.new(0, 10)
    spinCloseBtn.MouseButton1Click:Connect(function()
        spinFrame.Visible = false
    end)

    local spinList = Instance.new("ScrollingFrame", spinFrame)
    spinList.Size = UDim2.new(1, -20, 1, -50)
    spinList.Position = UDim2.new(0, 10, 0, 45)
    spinList.BackgroundColor3 = Color3.fromRGB(40, 70, 120)
    spinList.ScrollBarThickness = 8

    local spinListLayout = Instance.new("UIListLayout", spinList)
    spinListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    spinListLayout.Padding = UDim.new(0, 5)

    local function populateSpinList()
        clearList(spinList)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local targetHRP = p.Character.HumanoidRootPart
                if targetHRP.Position.Y > 10 then
                    local btn = Instance.new("TextButton", spinList)
                    btn.Size = UDim2.new(1, 0, 0, 30)
                    btn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
                    btn.TextColor3 = Color3.new(1, 1, 1)
                    btn.Font = Enum.Font.GothamBold
                    btn.TextSize = 18
                    btn.Text = p.Name
                    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
                    btn.MouseButton1Click:Connect(function()
                        local char = LocalPlayer.Character
                        if char then
                            local hrp = char:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                if rotateConnection then rotateConnection:Disconnect() rotateConnection = nil end
                                local radius = 5
                                local angle = 0
                                rotateConnection = RunService.RenderStepped:Connect(function(dt)
                                    angle = (angle + rotationSpeed * dt) % (2 * math.pi)
                                    local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
                                    hrp.CFrame = CFrame.new(targetHRP.Position + offset, targetHRP.Position)
                                end)
                                spinFrame.Visible = false
                            end
                        end
                    end)
                    btn.Parent = spinList
                end
            end
        end
        spinList.CanvasSize = UDim2.new(0, 0, 0, spinListLayout.AbsoluteContentSize.Y + 10)
    end
    spinBtn.MouseButton1Click:Connect(function()
        spinFrame.Visible = not spinFrame.Visible
        if spinFrame.Visible then
            populateSpinList()
        end
    end)

    stopSpinBtn.MouseButton1Click:Connect(function()
        if rotateConnection then
            rotateConnection:Disconnect()
            rotateConnection = nil
        end
    end)

    -- ИСПРАВЛЕННАЯ ФУНКЦИЯ KILL ALL
    killAllBtn.MouseButton1Click:Connect(function()
        task.spawn(function()
            local char = LocalPlayer.Character
            if not char then return end
            
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            
            -- Находим нож
            local knife = char:FindFirstChild("Knife") or LocalPlayer.Backpack:FindFirstChild("Knife")
            
            if not knife then
                print("Нож не найден! Вы должны быть убийцей.")
                return
            end
            
            -- Экипируем нож
            if knife.Parent == LocalPlayer.Backpack then
                char.Humanoid:EquipTool(knife)
                task.wait(0.2)
            end
            
            print("Начинаем Kill All...")
            killAllBtn.Text = "Killing..."
            killAllBtn.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            
            local killed = 0
            
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local targetHRP = player.Character:FindFirstChild("HumanoidRootPart")
                    local targetHum = player.Character:FindFirstChildOfClass("Humanoid")
                    
                    if targetHRP and targetHum and targetHum.Health > 0 and targetHRP.Position.Y > 10 then
                        -- Телепортируемся
                        hrp.CFrame = targetHRP.CFrame * CFrame.new(0, 0, 1.5)
                        task.wait(0.15)
                        
                        -- Атакуем
                        if knife and knife.Parent == char then
                            knife:Activate()
                            task.wait(0.05)
                            knife:Activate()
                        end
                        
                        killed = killed + 1
                        killAllBtn.Text = "Killed: "..killed
                        task.wait(0.2)
                    end
                end
            end
            
            print("Kill All завершен! Убито:", killed)
            task.wait(1)
            killAllBtn.Text = "Kill All"
            killAllBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
        end)
    end)
end

spawn(function()
    while wait(0.5) do
        if espEnabled then
            updateESP()
        end
    end
end)

createGui()

LocalPlayer.CharacterAdded:Connect(function()
    wait(0.8)
    if not PlayerGui:FindFirstChild("Def1x") then
        createGui()
    end
end)
