-- Client-side combat window. Run this tab to open it; it does not run on creation.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer
if not player then return end

local key = "BasaltCombatWindowCleanup_v1"
if type(_G[key]) == "function" then pcall(_G[key]) end
local connections = {}
local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end

local gui = Instance.new("ScreenGui")
gui.Name = "BasaltCombatWindow"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local ok = pcall(function() gui.Parent = CoreGui end)
if not ok or not gui.Parent then gui.Parent = player:WaitForChild("PlayerGui") end

local state = {
    aim = false, wall = true, team = true, aimFov = 35, aimRing = false, strength = 35, magic = false,
    aimPart = "Head", fly = false, flySpeed = 50,
    trigger = false, triggerFov = 4, mercy = 0.15,
    spin = false, spinSpeed = 360, third = false,
    espTracers = false, espHealth = false, espUser = false, espBox = false, espTeam = false,
    espVisibleBox = false,
    autoJump = false, accelerate = false, accelRate = 30, maxSpeed = 45,
    walkOverride = false, walkSpeed = 16,
}
local espColors = {
    tracers = Color3.fromRGB(100, 160, 255), health = Color3.fromRGB(80, 235, 125),
    user = Color3.fromRGB(255, 255, 255), box = Color3.fromRGB(255, 100, 100),
    visibleBox = Color3.fromRGB(80, 235, 125),
}
local espObjects = {}
local movementHumanoid, originalWalkSpeed, currentSpeed, wasAirborne = nil, nil, nil, false
local lastJump = 0
local flyRoot, flyHumanoid, flyVelocity
local flyUp, flyDown = false, false
local function restoreFly()
    if flyVelocity then flyVelocity:Destroy() end
    flyRoot, flyHumanoid, flyVelocity = nil, nil, nil
end
local function restoreMovement()
    if movementHumanoid and movementHumanoid.Parent and originalWalkSpeed then
        movementHumanoid.WalkSpeed = originalWalkSpeed
    end
    movementHumanoid, originalWalkSpeed, currentSpeed, wasAirborne = nil, nil, nil, false
end
local lastTarget, targetSince, lastShot = nil, 0, 0
local originalZoom, originalMax, originalMode
local spinHumanoid
local oldAutoRotate
local alive = true
local renderName = "BasaltCombatWindowRender"

local function restoreSpin()
    if spinHumanoid and spinHumanoid.Parent and oldAutoRotate ~= nil then
        spinHumanoid.AutoRotate = oldAutoRotate
    end
    spinHumanoid, oldAutoRotate = nil, nil
end
local function restoreCameraMode()
    if originalMode ~= nil then
        pcall(function()
            player.CameraMode = originalMode
            player.CameraMinZoomDistance = originalZoom
            player.CameraMaxZoomDistance = originalMax
        end)
        originalMode = nil
    end
end
local function cleanup()
    if not alive then return end
    alive = false
    RunService:UnbindFromRenderStep(renderName)
    for _, connection in ipairs(connections) do connection:Disconnect() end
    restoreSpin()
    restoreFly()
    flyUp, flyDown = false, false
    restoreMovement()
    restoreCameraMode()
    gui:Destroy()
    if _G[key] == cleanup then _G[key] = nil end
end
_G[key] = cleanup

local function make(class, props, parent)
    local obj = Instance.new(class)
    for property, value in pairs(props) do obj[property] = value end
    obj.Parent = parent
    return obj
end
local C = {
    background = Color3.fromRGB(20, 23, 32),
    panel = Color3.fromRGB(29, 33, 45),
    control = Color3.fromRGB(40, 45, 60),
    accent = Color3.fromRGB(100, 160, 255),
    text = Color3.fromRGB(235, 239, 250),
    muted = Color3.fromRGB(164, 174, 196),
}
local function round(parent, radius)
    make("UICorner", {CornerRadius = UDim.new(0, radius)}, parent)
end
-- Windows-style navigation: a compact rail with one page popping out on the right.
local railWidth, expandedWidth, windowHeight = 166, 602, 480
local window = make("Frame", {
    Name = "Window", Size = UDim2.fromOffset(railWidth, windowHeight),
    Position = UDim2.new(0.5, -301, 0.5, -240),
    BackgroundColor3 = C.background, BorderSizePixel = 0, Active = true, ZIndex = 10,
}, gui)
round(window, 12)
make("UIStroke", {Color = Color3.fromRGB(75, 88, 120), Thickness = 1}, window)
local header = make("Frame", {
    Name = "Header", Size = UDim2.new(1, 0, 0, 48),
    BackgroundTransparency = 1, Active = true,
}, window)
make("TextLabel", {
    Size = UDim2.fromOffset(82, 48), Position = UDim2.fromOffset(14, 0),
    BackgroundTransparency = 1, Text = "COMBAT", Font = Enum.Font.GothamBold,
    TextSize = 15, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
}, header)
local minimize = make("TextButton", {
    Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(100, 10),
    BackgroundColor3 = C.control, Text = "−", Font = Enum.Font.GothamBold,
    TextSize = 19, TextColor3 = C.text,
}, header)
round(minimize, 7)
local close = make("TextButton", {
    Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(131, 10),
    BackgroundColor3 = C.control, Text = "×", Font = Enum.Font.GothamBold,
    TextSize = 19, TextColor3 = C.text,
}, header)
round(close, 7)
connect(close.MouseButton1Click, cleanup)
local rail = make("ScrollingFrame", {
    Name = "Navigation", Position = UDim2.fromOffset(8, 50),
    Size = UDim2.fromOffset(railWidth - 16, windowHeight - 59),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
    ScrollBarImageColor3 = C.accent, AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.fromOffset(0, 0), ScrollingDirection = Enum.ScrollingDirection.Y,
}, window)
make("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, rail)
local body = rail -- Existing section declarations register pages in the navigation rail.
local pageHost = make("Frame", {
    Name = "SidePanel", Position = UDim2.fromOffset(railWidth, 0),
    Size = UDim2.new(1, -railWidth, 1, 0), BackgroundColor3 = C.panel,
    BorderSizePixel = 0, Visible = false,
}, window)
round(pageHost, 10)
local activePage, activeButton
local minimized = false
local function setMinimized(value)
    minimized = value
    rail.Visible = not value
    pageHost.Visible = not value and activePage ~= nil
    window.Size = UDim2.fromOffset(value and railWidth or (activePage and expandedWidth or railWidth),
        value and 48 or windowHeight)
    minimize.Text = value and "+" or "−"
end
connect(minimize.MouseButton1Click, function() setMinimized(not minimized) end)
local function showPage(page, button)
    if activePage then activePage.Visible = false end
    if activeButton then activeButton.BackgroundColor3 = C.control; activeButton.TextColor3 = C.text end
    if activePage == page then
        activePage, activeButton = nil, nil
        pageHost.Visible = false
        window.Size = UDim2.fromOffset(railWidth, windowHeight)
        return
    end
    activePage, activeButton = page, button
    page.Visible = true
    button.BackgroundColor3 = C.accent
    button.TextColor3 = C.background
    pageHost.Visible = true
    window.Size = UDim2.fromOffset(expandedWidth, windowHeight)
end

-- Drag only from the title bar (not navigation or slider controls).
local dragStart, windowStart, dragInput
connect(header.InputBegan, function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
    dragStart, windowStart, dragInput = input.Position, window.Position, input
end)
connect(UserInputService.InputChanged, function(input)
    if not dragStart then return end
    if input ~= dragInput and not (dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement) then return end
    local delta = input.Position - dragStart
    window.Position = UDim2.new(windowStart.X.Scale, windowStart.X.Offset + delta.X,
        windowStart.Y.Scale, windowStart.Y.Offset + delta.Y)
end)
connect(UserInputService.InputEnded, function(input)
    if input == dragInput or (dragInput and dragInput.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseButton1) then
        dragStart, dragInput = nil, nil
    end
end)

local function folder(_parent, title, _initiallyOpen)
    local button = make("TextButton", {
        Size = UDim2.new(1, -3, 0, 39), BackgroundColor3 = C.control,
        Text = "  " .. title .. "   ›", Font = Enum.Font.GothamMedium,
        TextSize = 13, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, rail)
    round(button, 7)
    local page = make("ScrollingFrame", {
        Name = title .. "Page", Position = UDim2.fromOffset(10, 11),
        Size = UDim2.new(1, -19, 1, -20), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = C.accent,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.fromOffset(0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false,
    }, pageHost)
    make("UIPadding", {PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 10),
        PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 9)}, page)
    make("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, page)
    connect(button.MouseButton1Click, function() showPage(page, button) end)
    return page
end
local controlUpdates = {}
local controlCallbacks = {}
local bindings, bindingUpdates = {}, {}
local awaitingBind
local function assignBind(field, code)
    if code then
        for other, bound in pairs(bindings) do
            if other ~= field and bound == code then
                bindings[other] = nil
                if bindingUpdates[other] then bindingUpdates[other]() end
            end
        end
    end
    bindings[field] = code
    if bindingUpdates[field] then bindingUpdates[field]() end
end
local function toggle(parent, label, field, callback)
    local row = make("Frame", {
        Size = UDim2.new(1, 0, 0, 35), BackgroundTransparency = 1,
    }, parent)
    local button = make("TextButton", {
        Size = UDim2.new(1, -79, 1, 0), BackgroundColor3 = C.control,
        Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)
    round(button, 6)
    make("UIPadding", {PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 3)}, button)
    local bindButton = make("TextButton", {
        Size = UDim2.fromOffset(74, 35), Position = UDim2.new(1, -74, 0, 0),
        BackgroundColor3 = C.control, Font = Enum.Font.GothamMedium,
        TextSize = 11, TextColor3 = C.muted, TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)
    round(bindButton, 6)
    local function updateBind()
        bindButton.Text = awaitingBind == field and "Press key..."
            or (bindings[field] and bindings[field].Name or "Bind key")
        bindButton.TextColor3 = awaitingBind == field and C.accent or C.muted
    end
    bindingUpdates[field] = updateBind
    local function update()
        button.Text = label .. (state[field] and "  [ON]" or "  [OFF]")
        button.TextColor3 = state[field] and C.accent or C.text
    end
    update()
    updateBind()
    controlUpdates[field] = update
    controlCallbacks[field] = callback
    connect(button.MouseButton1Click, function()
        state[field] = not state[field]
        update()
        if callback then callback(state[field]) end
    end)
    connect(bindButton.MouseButton1Click, function()
        local previous = awaitingBind
        awaitingBind = previous == field and nil or field
        if previous and bindingUpdates[previous] then bindingUpdates[previous]() end
        updateBind()
    end)
    return update
end
connect(UserInputService.InputBegan, function(input, processed)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local code = input.KeyCode
    if awaitingBind then
        if code == Enum.KeyCode.Unknown then return end
        local field = awaitingBind
        awaitingBind = nil
        if code == Enum.KeyCode.Escape or code == Enum.KeyCode.Backspace then
            assignBind(field, nil)
        else
            assignBind(field, code)
        end
        return
    end
    if processed or UserInputService:GetFocusedTextBox() then return end
    for field, bound in pairs(bindings) do
        if bound == code then
            state[field] = not state[field]
            controlUpdates[field]()
            local callback = controlCallbacks[field]
            if callback then callback(state[field]) end
            break
        end
    end
end)
local function slider(parent, label, field, low, high, decimals, unit)
    local box = make("Frame", {
        Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = C.control,
    }, parent)
    round(box, 6)
    local readout = make("TextLabel", {
        Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(9, 0),
        BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
    }, box)
    local track = make("Frame", {
        Size = UDim2.new(1, -20, 0, 8), Position = UDim2.fromOffset(10, 39),
        BackgroundColor3 = C.background, Active = true,
    }, box)
    round(track, 4)
    local fill = make("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.accent}, track)
    round(fill, 4)
    local handle = make("Frame", {
        Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = C.text,
    }, track)
    round(handle, 7)
    local function update()
        local fraction = math.clamp((state[field] - low) / (high - low), 0, 1)
        fill.Size = UDim2.fromScale(fraction, 1)
        handle.Position = UDim2.fromScale(fraction, 0.5)
        readout.Text = label .. ": " .. string.format("%." .. decimals .. "f", state[field]) .. unit
    end
    controlUpdates[field] = update
    local dragging = nil
    local function setAt(x)
        local fraction = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local factor = 10 ^ decimals
        state[field] = math.floor((low + (high - low) * fraction) * factor + 0.5) / factor
        update()
    end
    connect(box.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = input
            setAt(input.Position.X)
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if not dragging then return end
        if input == dragging or (dragging.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement) then
            setAt(input.Position.X)
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if input == dragging then dragging = nil end
    end)
    update()
    return update
end

local aimFolder = folder(body, "Aimbot", true)
local updateAimToggle = toggle(aimFolder, "Aimbot", "aim")
toggle(aimFolder, "Wall check", "wall")
toggle(aimFolder, "Team check", "team")
local aimParts = {"Head", "HumanoidRootPart", "Legs"}
local aimPartButton = make("TextButton", {
    Size = UDim2.new(1, 0, 0, 35), BackgroundColor3 = C.control,
    Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = C.text,
    TextXAlignment = Enum.TextXAlignment.Left,
}, aimFolder)
round(aimPartButton, 6)
make("UIPadding", {PaddingLeft = UDim.new(0, 10)}, aimPartButton)
local aimPartIndex = 1
local function updateAimPart()
    aimPartButton.Text = "Aim target: " .. aimParts[aimPartIndex] .. "  (tap to change)"
end
updateAimPart()
connect(aimPartButton.MouseButton1Click, function()
    aimPartIndex = aimPartIndex % #aimParts + 1
    state.aimPart = aimParts[aimPartIndex]
    lastTarget = nil
    updateAimPart()
end)
toggle(aimFolder, "Magic lock (visual only)", "magic")
make("TextLabel", {
  Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1,
    Text = "Keeps your camera still; visual lock only. Does not spoof shots.",
    TextWrapped = true, Font = Enum.Font.Gotham, TextSize = 11,
    TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left,
}, aimFolder)
local updateAimFov = slider(aimFolder, "Aimbot FOV", "aimFov", 1, 360, 0, "°")
toggle(aimFolder, "Show aim FOV ring", "aimRing")
local updateStrength = slider(aimFolder, "Strength", "strength", 1, 100, 0, "%")
local rageButton = make("TextButton", {
    Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Color3.fromRGB(128, 55, 72),
    Text = "RAGE  •  360° FOV + instant snap", Font = Enum.Font.GothamBold,
    TextSize = 13, TextColor3 = C.text,
}, aimFolder)
round(rageButton, 6)
connect(rageButton.MouseButton1Click, function()
    state.aimFov, state.strength, state.aim = 360, 100, true
    updateAimFov()
    updateStrength()
    updateAimToggle()
end)

local rageFolder = folder(body, "Ragemode", true)
local triggerFolder = folder(rageFolder, "Triggerbot", false)
toggle(triggerFolder, "Triggerbot", "trigger", function(enabled)
    if not enabled then lastTarget = nil end
end)
slider(triggerFolder, "Trigger FOV", "triggerFov", 1, 45, 0, "°")
slider(triggerFolder, "Mercy time", "mercy", 0, 2, 2, "s")
make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 33), BackgroundTransparency = 1,
    Text = "Mercy time = delay on the same target.\nFiring requires executor mouse1click().",
    TextWrapped = true, Font = Enum.Font.Gotham, TextSize = 11,
    TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left,
}, triggerFolder)
toggle(rageFolder, "Spin", "spin", function(enabled)
    if not enabled then restoreSpin() end
end)
slider(rageFolder, "Spin speed", "spinSpeed", 0, 10000, 0, "°/s")
toggle(rageFolder, "Forced third person", "third", function(enabled)
    if enabled then
        originalMode = player.CameraMode
        originalZoom = player.CameraMinZoomDistance
        originalMax = player.CameraMaxZoomDistance
    else
        restoreCameraMode()
    end
end)

-- Separate ESP switches and a per-feature palette picker (works on touch).
local espFolder = folder(body, "ESP", false)
toggle(espFolder, "Tracers", "espTracers")
toggle(espFolder, "Health", "espHealth")
toggle(espFolder, "User", "espUser")
toggle(espFolder, "Box ESP", "espBox")
toggle(espFolder, "Visible target box color", "espVisibleBox")
toggle(espFolder, "Show teammates in ESP", "espTeam")
local palette = {
    Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 75, 75),
    Color3.fromRGB(255, 165, 55), Color3.fromRGB(255, 235, 70),
    Color3.fromRGB(80, 235, 125), Color3.fromRGB(50, 225, 225),
    Color3.fromRGB(100, 160, 255), Color3.fromRGB(185, 115, 255),
    Color3.fromRGB(255, 105, 210), Color3.fromRGB(30, 30, 30),
}
local colorFolder = folder(espFolder, "Color picker", false)
local colorUpdates = {}
local function colorPicker(label, field)
    local row = make("Frame", {Size = UDim2.new(1, 0, 0, 59), BackgroundColor3 = C.control}, colorFolder)
    round(row, 6)
    make("TextLabel", {Size = UDim2.new(1, -15, 0, 25), Position = UDim2.fromOffset(9, 1),
        Text = label, BackgroundTransparency = 1, Font = Enum.Font.GothamMedium,
        TextSize = 12, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local chosen = make("Frame", {
        Size = UDim2.fromOffset(14, 14), Position = UDim2.new(1, -23, 0, 7),
        BackgroundColor3 = espColors[field],
    }, row)
    round(chosen, 3)
    colorUpdates[field] = function() chosen.BackgroundColor3 = espColors[field] end
    for i, color in ipairs(palette) do
        local swatch = make("TextButton", {
            Size = UDim2.new(0.1, -4, 0, 23), Position = UDim2.new((i - 1) * 0.1, 2, 0, 29),
            BackgroundColor3 = color, Text = "", BorderSizePixel = 0,
        }, row)
        round(swatch, 4)
        connect(swatch.MouseButton1Click, function()
            espColors[field] = color
            chosen.BackgroundColor3 = color
        end)
    end
end
colorPicker("Tracer color", "tracers")
colorPicker("Health color", "health")
colorPicker("Username color", "user")
colorPicker("Box color", "box")
colorPicker("Visible box color", "visibleBox")

local moveFolder = folder(body, "Movement", false)
toggle(moveFolder, "Autojump on landing", "autoJump")
toggle(moveFolder, "Acceleration", "accelerate", function(enabled)
    currentSpeed = nil
    if not enabled and not state.walkOverride then restoreMovement() end
end)
slider(moveFolder, "Acceleration rate", "accelRate", 1, 200, 0, " studs/s²")
slider(moveFolder, "Acceleration max speed", "maxSpeed", 16, 200, 0, "")
toggle(moveFolder, "WalkSpeed override", "walkOverride", function(enabled)
    currentSpeed = nil
    if not enabled and not state.accelerate then restoreMovement() end
end)
slider(moveFolder, "WalkSpeed", "walkSpeed", 0, 200, 0, "")
toggle(moveFolder, "Fly", "fly", function(enabled)
    if not enabled then
        restoreFly()
        flyUp, flyDown = false, false
    end
end)
slider(moveFolder, "Fly speed", "flySpeed", 5, 200, 0, " studs/s")
local flyControls = make("Frame", {
    Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1,
}, moveFolder)
local function flyButton(text, x, set)
    local button = make("TextButton", {
        Size = UDim2.new(0.5, -3, 1, 0), Position = UDim2.new(x, 0, 0, 0),
        BackgroundColor3 = C.control, Text = text, Font = Enum.Font.GothamMedium,
        TextSize = 13, TextColor3 = C.text,
    }, flyControls)
    round(button, 6)
    connect(button.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            set(true)
        end
    end)
    connect(button.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            set(false)
        end
    end)
end
flyButton("Fly UP (hold)", 0, function(down) flyUp = down end)
flyButton("Fly DOWN (hold)", 0.5, function(down) flyDown = down end)
make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 27), BackgroundTransparency = 1,
    Text = "Move with joystick/WASD; Space up, Ctrl down.",
    TextWrapped = true, Font = Enum.Font.Gotham, TextSize = 11,
    TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left,
}, moveFolder)

-- Named profiles live in one JSON file per place. File APIs are executor-dependent.
local HttpService = game:GetService("HttpService")
local configDir = "BasaltCombatConfigs"
local configPath = configDir .. "/" .. tostring(game.PlaceId) .. ".json"
local fileReady = type(readfile) == "function" and type(writefile) == "function"
    and type(isfolder) == "function" and type(makefolder) == "function"
local profiles, selected, autoLoad = {}, nil, false
local configFolder = folder(body, "Config", false)
local configName = make("TextBox", {
    Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = C.control,
    PlaceholderText = "Config name (letters, numbers, - or _)", Text = "",
    ClearTextOnFocus = false, Font = Enum.Font.GothamMedium,
    TextSize = 12, TextColor3 = C.text, PlaceholderColor3 = C.muted,
}, configFolder)
round(configName, 6)
local configStatus = make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1,
    TextWrapped = true, Font = Enum.Font.Gotham, TextSize = 11,
    TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left,
}, configFolder)
local function configButton(label, callback)
    local button = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 35), BackgroundColor3 = C.control,
        Text = label, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = C.text,
    }, configFolder)
    round(button, 6)
    connect(button.MouseButton1Click, callback)
    return button
end
local selectButton, autoButton
local function configMessage(message)
    configStatus.Text = message
    if selectButton then selectButton.Text = "Selected: " .. (selected or "none") .. " (tap to cycle)" end
    if autoButton then autoButton.Text = "Auto-load selected    [" .. (autoLoad and "ON" or "OFF") .. "]" end
end
local function persistProfiles()
    if not fileReady then return false, "Executor file APIs unavailable" end
    local ok, err = pcall(function()
        if not isfolder(configDir) then makefolder(configDir) end
        writefile(configPath, HttpService:JSONEncode({profiles = profiles,
            selected = selected or "", autoLoad = autoLoad}))
    end)
    return ok, ok and nil or tostring(err)
end
local function profileNames()
    local names = {}
    for name, profile in pairs(profiles) do
        if type(name) == "string" and type(profile) == "table" then table.insert(names, name) end
    end
    table.sort(names)
    return names
end
local limits = {
    aimFov = {1, 360}, strength = {1, 100}, flySpeed = {5, 200},
    triggerFov = {1, 45}, mercy = {0, 2}, spinSpeed = {0, 10000},
    accelRate = {1, 200}, maxSpeed = {16, 200}, walkSpeed = {0, 200},
}
local function loadProfile(name)
    local profile = profiles[name]
    if type(profile) ~= "table" or type(profile.state) ~= "table" then
        configMessage("No saved config: " .. tostring(name))
        return
    end
    local changes = {}
    for field, previous in pairs(state) do
        local value = profile.state[field]
        if field ~= "aimPart" and type(value) == type(previous) then
            if type(value) == "number" then
                local range = limits[field]
                if value == value and value ~= math.huge and value ~= -math.huge and range then
                    value = math.clamp(value, range[1], range[2])
                else
                    value = previous
                end
            end
            if value ~= previous then changes[field] = true; state[field] = value end
        end
    end
    if type(profile.state.aimPart) == "string" then
        for index, part in ipairs(aimParts) do
            if profile.state.aimPart == part then
                aimPartIndex = index
                state.aimPart = part
                updateAimPart()
                break
            end
        end
    end
    if type(profile.colors) == "table" then
        for field, previous in pairs(espColors) do
            local rgb = profile.colors[field]
            if type(rgb) == "table" and type(rgb[1]) == "number"
                and type(rgb[2]) == "number" and type(rgb[3]) == "number"
                and rgb[1] == rgb[1] and rgb[2] == rgb[2] and rgb[3] == rgb[3] then
                espColors[field] = Color3.fromRGB(math.clamp(rgb[1], 0, 255),
                    math.clamp(rgb[2], 0, 255), math.clamp(rgb[3], 0, 255))
            end
            if colorUpdates[field] then colorUpdates[field]() end
        end
    end
    -- Older profiles without bindings remain valid. Only known toggle fields and real keys load.
    for field in pairs(bindingUpdates) do assignBind(field, nil) end
    if type(profile.bindings) == "table" then
        local fields = {}
        for field in pairs(bindingUpdates) do table.insert(fields, field) end
        table.sort(fields)
        for _, field in ipairs(fields) do
            local name = profile.bindings[field]
            if type(name) == "string" then
                local okKey, code = pcall(function() return Enum.KeyCode[name] end)
                if okKey and code and code ~= Enum.KeyCode.Unknown then assignBind(field, code) end
            end
        end
    end
    for field, update in pairs(controlUpdates) do update() end
    for field in pairs(changes) do
        local callback = controlCallbacks[field]
        if callback then callback(state[field]) end
    end
    lastTarget = nil
    selected = name
    configMessage("Loaded: " .. name)
end
if fileReady then
    local ok, data = pcall(function()
        if isfolder(configDir) and type(isfile) == "function" and isfile(configPath) then
            return HttpService:JSONDecode(readfile(configPath))
        end
        if isfolder(configDir) then
            local success, raw = pcall(readfile, configPath)
            if success then return HttpService:JSONDecode(raw) end
        end
    end)
    if ok and type(data) == "table" then
        if type(data.profiles) == "table" then profiles = data.profiles end
        if type(data.selected) == "string" and profiles[data.selected] then selected = data.selected end
        autoLoad = data.autoLoad == true
    elseif not ok then
        warn("Combat config read failed:", data)
    end
end
selectButton = configButton("Selected: none (tap to cycle)", function()
    local names = profileNames()
    if #names == 0 then configMessage("Save a config first"); return end
    local current = table.find(names, selected) or 0
    local previous = selected
    selected = names[current % #names + 1]
    local ok, err = persistProfiles()
    if not ok then selected = previous else configName.Text = selected end
    configMessage(ok and ("Selected: " .. selected) or ("Selection not saved: " .. err))
end)
configButton("Save named config", function()
    local name = configName.Text:match("^%s*(.-)%s*$")
    if #name < 1 or #name > 40 or not name:match("^[%w_%-]+$") then
        configMessage("Use 1-40 letters, numbers, - or _")
        return
    end
    if not fileReady then configMessage("Executor file APIs unavailable"); return end
    local values, colors = {}, {}
    for field, value in pairs(state) do values[field] = value end
    for field, color in pairs(espColors) do
        colors[field] = {math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5),
            math.floor(color.B * 255 + 0.5)}
    end
    local savedBindings = {}
    for field, code in pairs(bindings) do savedBindings[field] = code.Name end
    local previousProfile, previousSelection = profiles[name], selected
    profiles[name] = {state = values, colors = colors, bindings = savedBindings}
    selected = name
    local ok, err = persistProfiles()
    if not ok then profiles[name], selected = previousProfile, previousSelection end
    configMessage(ok and ("Saved: " .. name) or ("Save failed: " .. err))
end)
configButton("Load selected config", function()
    if selected then loadProfile(selected) else configMessage("Select a saved config first") end
end)
autoButton = configButton("Auto-load selected    [OFF]", function()
    if not selected then configMessage("Select a saved config first"); return end
    autoLoad = not autoLoad
    local ok, err = persistProfiles()
    if not ok then autoLoad = not autoLoad end
    configMessage(ok and ("Auto-load " .. (autoLoad and "enabled" or "disabled") .. ": " .. selected)
        or ("Auto-load setting not saved: " .. err))
end)
configMessage(fileReady and "Save a named config to begin" or "Executor file APIs unavailable; configs cannot persist")
if autoLoad and selected then loadProfile(selected) end

-- Visual target lock does not modify the camera or alter game hit detection.
local lockBadge = make("TextLabel", {
    Name = "VisualLockStatus", Size = UDim2.fromOffset(270, 32),
    AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52),
    BackgroundColor3 = Color3.fromRGB(25, 45, 35), BackgroundTransparency = 0.15,
    Text = "", Font = Enum.Font.GothamBold, TextSize = 13,
    TextColor3 = Color3.fromRGB(110, 255, 155), ZIndex = 5, Visible = false,
}, gui)
round(lockBadge, 7)
local lockMarker = make("TextLabel", {
    Name = "VisualLockMarker", Size = UDim2.fromOffset(50, 50),
    AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
    Text = "◎", Font = Enum.Font.GothamBold, TextSize = 35,
    TextColor3 = Color3.fromRGB(110, 255, 155), TextStrokeTransparency = 0.25,
    ZIndex = 5, Visible = false,
}, gui)

-- Circular aim FOV indicator, centered on the camera viewport.
local aimRing = make("Frame", {
    Name = "AimFovRing", AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
    ZIndex = 4,
}, gui)
make("UICorner", {CornerRadius = UDim.new(1, 0)}, aimRing)
make("UIStroke", {Color = C.accent, Thickness = 2, Transparency = 0.15}, aimRing)
local function updateAimRing(camera)
    aimRing.Visible = state.aimRing
    if not state.aimRing then return end
 local screen = camera.ViewportSize
    -- Project half the angular FOV onto the screen; cap angles beyond the viewport.
    local focalLength = screen.Y / (2 * math.tan(math.rad(camera.FieldOfView / 2)))
    local radius = math.min(focalLength * math.tan(math.rad(math.min(state.aimFov / 2, 85))),
        math.min(screen.X, screen.Y) * 0.48)
    aimRing.Position = UDim2.fromOffset(screen.X / 2, screen.Y / 2)
    aimRing.Size = UDim2.fromOffset(radius * 2, radius * 2)
end

-- Screen-space ESP uses Roblox GUI instances; no Drawing or executor API required.
local overlay = make("Frame", {
    Name = "ESPOverlay", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
    Position = UDim2.fromScale(0, 0), Active = false, ZIndex = 1,
}, gui)
local function newEsp(other)
    local container = make("Frame", {
        Name = "ESP_" .. other.UserId, BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), Visible = false,
    }, overlay)
    local line = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0,
        BackgroundColor3 = espColors.tracers, Visible = false,
    }, container)
    local box = make("Frame", {
        BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
    }, container)
    local stroke = make("UIStroke", {Thickness = 2, Color = espColors.box}, box)
    local username = make("TextLabel", {
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13,
        TextStrokeTransparency = 0.35, TextColor3 = espColors.user,
        Visible = false,
    }, container)
    local health = make("TextLabel", {
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12,
        TextStrokeTransparency = 0.35, TextColor3 = espColors.health,
        Visible = false,
    }, container)
    local entry = {container = container, line = line, box = box, stroke = stroke,
        username = username, health = health}
    espObjects[other] = entry
    return entry
end
local espElapsed = 0
local function updateEsp(camera, aimTarget, dt)
    local active = state.espTracers or state.espHealth or state.espUser or state.espBox
    overlay.Visible = active
    if not active then espElapsed = 0; return end
    -- ESP geometry and visibility checks refresh at 20 Hz, not every render frame.
    espElapsed += dt
    if espElapsed < 0.05 then return end
    espElapsed = 0
    local targetVisible = false
    if aimTarget and state.espBox and state.espVisibleBox then
        local character = aimTarget:FindFirstAncestorOfClass("Model")
        targetVisible = character ~= nil and visible(camera, aimTarget, character)
    end
    local screen = camera.ViewportSize
    local start = Vector2.new(screen.X / 2, screen.Y)
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player then
            local entry = espObjects[other] or newEsp(other)
            local character = other.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local teamAllowed = state.espTeam or player.Team == nil or other.Team ~= player.Team
            local show = character and humanoid and root and humanoid.Health > 0 and teamAllowed
            local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
            if show and (state.espBox or state.espUser or state.espHealth) then
                local cf, size = character:GetBoundingBox()
                for sx = -1, 1, 2 do
                    for sy = -1, 1, 2 do
                        for sz = -1, 1, 2 do
                            local world = cf:PointToWorldSpace(Vector3.new(sx * size.X, sy * size.Y, sz * size.Z) * 0.5)
                            local point = camera:WorldToViewportPoint(world)
                            if point.Z <= 0 then show = false; break end
                            minX, minY = math.min(minX, point.X), math.min(minY, point.Y)
                            maxX, maxY = math.max(maxX, point.X), math.max(maxY, point.Y)
                        end
                        if not show then break end
                    end
                    if not show then break end
                end
            end
            local boxOnScreen = show and maxX >= 0 and minX <= screen.X and maxY >= 0 and minY <= screen.Y
            entry.container.Visible = not not (boxOnScreen or (show and state.espTracers))
            entry.box.Visible = not not (boxOnScreen and state.espBox)
            entry.username.Visible = not not (boxOnScreen and state.espUser)
            entry.health.Visible = not not (boxOnScreen and state.espHealth)
            entry.line.Visible = not not (show and state.espTracers)
            if boxOnScreen then
                local width, height = math.max(3, maxX - minX), math.max(3, maxY - minY)
                entry.box.Visible = state.espBox
                entry.box.Position = UDim2.fromOffset(minX, minY)
                entry.box.Size = UDim2.fromOffset(width, height)
                if state.espBox and state.espVisibleBox and targetVisible and aimTarget
                    and aimTarget:IsDescendantOf(character) then
                    entry.stroke.Color = espColors.visibleBox
                else
                    entry.stroke.Color = espColors.box
                end
                entry.username.Visible = state.espUser
                entry.username.Text = other.Name
                entry.username.TextColor3 = espColors.user
                entry.username.Position = UDim2.fromOffset(minX - 20, minY - 21)
                entry.username.Size = UDim2.fromOffset(width + 40, 19)
                entry.health.Visible = state.espHealth
                entry.health.Text = string.format("HP %d/%d", math.ceil(humanoid.Health), math.ceil(humanoid.MaxHealth))
                entry.health.TextColor3 = espColors.health
                entry.health.Position = UDim2.fromOffset(minX - 20, maxY + 2)
                entry.health.Size = UDim2.fromOffset(width + 40, 19)
            end
            if show and state.espTracers then
                local point = camera:WorldToViewportPoint(root.Position)
                local center = Vector2.new(screen.X / 2, screen.Y / 2)
                local goal = Vector2.new(point.X, point.Y)
                if point.Z <= 0 then
                    -- Project a behind-camera target toward the nearest screen edge.
                    local localDirection = camera.CFrame:VectorToObjectSpace(root.Position - camera.CFrame.Position)
                    local planar = Vector2.new(localDirection.X, -localDirection.Y)
                    if planar.Magnitude < 0.001 then planar = Vector2.new(0, -1) end
                    goal = center + planar.Unit * math.max(screen.X, screen.Y)
                end
                if point.Z <= 0 or goal.X < 8 or goal.X > screen.X - 8
                    or goal.Y < 8 or goal.Y > screen.Y - 8 then
                    local ray = goal - center
                    if ray.Magnitude < 0.001 then ray = Vector2.new(0, -1) end
                    local factor = math.min((screen.X / 2 - 8) / math.max(math.abs(ray.X), 0.001),
                        (screen.Y / 2 - 8) / math.max(math.abs(ray.Y), 0.001))
                    goal = center + ray * factor
                end
                local delta = goal - start
                entry.line.Size = UDim2.fromOffset(math.max(delta.Magnitude, 1), 2)
                entry.line.Position = UDim2.fromOffset((start.X + goal.X) / 2, (start.Y + goal.Y) / 2)
                entry.line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
                entry.line.BackgroundColor3 = espColors.tracers
            end
        end
    end
end
connect(Players.PlayerRemoving, function(other)
    local entry = espObjects[other]
    if entry then
        entry.container:Destroy()
        espObjects[other] = nil
    end
end)

local function updateMovement(dt)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid ~= movementHumanoid then
        restoreMovement()
        if humanoid then
            movementHumanoid = humanoid
            originalWalkSpeed = humanoid.WalkSpeed
            currentSpeed = originalWalkSpeed
        end
    end
    if not humanoid or humanoid.Health <= 0 then return end
    local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
    local landing = grounded and wasAirborne
    wasAirborne = not grounded
    if state.autoJump and not state.fly and landing and os.clock() - lastJump > 0.12 then
        lastJump = os.clock()
        humanoid.Jump = true
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
    if state.accelerate or state.walkOverride then
        local base = state.walkOverride and state.walkSpeed or originalWalkSpeed
        if state.accelerate and humanoid.MoveDirection.Magnitude > 0.05 then
            currentSpeed = math.min(math.max(base, state.maxSpeed),
                math.max(base, currentSpeed or base) + state.accelRate * math.min(dt, 0.1))
        else
            currentSpeed = base
        end
        if humanoid.WalkSpeed ~= currentSpeed then humanoid.WalkSpeed = currentSpeed end
    end
end

local function updateFly()
    if not state.fly then
        if flyVelocity then restoreFly() end
        return
    end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then
        if flyVelocity then restoreFly() end
        return
    end
    if root ~= flyRoot or humanoid ~= flyHumanoid or not flyVelocity then
        restoreFly()
        flyRoot, flyHumanoid = root, humanoid
        flyVelocity = Instance.new("BodyVelocity")
        flyVelocity.Name = "BasaltFlyVelocity"
        flyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        flyVelocity.P = 10000
        flyVelocity.Parent = root
    end
    local move = humanoid.MoveDirection
    local horizontal = Vector3.new(move.X, 0, move.Z)
    local vertical = (flyUp or UserInputService:IsKeyDown(Enum.KeyCode.Space)) and 1 or 0
    vertical -= (flyDown or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)) and 1 or 0
    local direction = horizontal + Vector3.new(0, vertical, 0)
    flyVelocity.Velocity = direction.Magnitude > 1 and direction.Unit * state.flySpeed or direction * state.flySpeed
end

local function validTarget(other)
    if other == player then return nil end
    if state.team and player.Team ~= nil and other.Team == player.Team then return nil end
    local character = other.Character
    if not character then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return nil end
    local part
    if state.aimPart == "Legs" then
        part = character:FindFirstChild("LeftLowerLeg") or character:FindFirstChild("RightLowerLeg")
            or character:FindFirstChild("Left Leg") or character:FindFirstChild("Right Leg")
            or character:FindFirstChild("LeftFoot") or character:FindFirstChild("RightFoot")
    else
        part = character:FindFirstChild(state.aimPart)
    end
    if not part or not part:IsA("BasePart") then return nil end
    return part, character
end
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function visible(camera, part, character)
    rayParams.FilterDescendantsInstances = player.Character and {player.Character} or {}
    local hit = workspace:Raycast(camera.CFrame.Position, part.Position - camera.CFrame.Position, rayParams)
    return not hit or hit.Instance:IsDescendantOf(character)
end
local function closest(camera, fov, checkWalls)
    local chosen = nil
    local bestDot = math.cos(math.rad(math.min(fov * 0.5, 180)))
    local forward = camera.CFrame.LookVector
    local origin = camera.CFrame.Position
    for _, other in ipairs(Players:GetPlayers()) do
        local part, character = validTarget(other)
        if part then
            local direction = part.Position - origin
            local length = direction.Magnitude
            if length > 0.01 then
                local dot = forward:Dot(direction) / length
                if dot >= bestDot and (not checkWalls or visible(camera, part, character)) then
                    bestDot, chosen = dot, part
                end
            end
        end
    end
    return chosen
end
local warnedClick = false
RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, function(dt)
    if not alive then return end
    if state.autoJump or state.accelerate or state.walkOverride or movementHumanoid then
        updateMovement(dt)
    end
    local camera = workspace.CurrentCamera
    if not camera then
        aimRing.Visible = false
        return
    end
    updateAimRing(camera)
    updateFly()
    if state.third then
        pcall(function()
            if player.CameraMode ~= Enum.CameraMode.Classic then player.CameraMode = Enum.CameraMode.Classic end
            if player.CameraMinZoomDistance ~= 8 then player.CameraMinZoomDistance = 8 end
            local maxZoom = math.max(8, originalMax or 12)
            if player.CameraMaxZoomDistance ~= maxZoom then player.CameraMaxZoomDistance = maxZoom end
        end)
    end
    if state.spin then
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if root and humanoid and humanoid.Health > 0 then
            if spinHumanoid ~= humanoid then
                restoreSpin()
                spinHumanoid, oldAutoRotate = humanoid, humanoid.AutoRotate
            end
            humanoid.AutoRotate = false
            local cameraCFrame = camera.CFrame
            root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(state.spinSpeed * math.min(dt, 0.1)), 0)
            camera.CFrame = cameraCFrame
        end
    end
    local aimTarget = state.aim and closest(camera, state.aimFov, state.wall) or nil
    updateEsp(camera, aimTarget, dt)
    lockBadge.Visible = state.aim and state.magic
    lockMarker.Visible = false
    if state.aim then
        local target = aimTarget
        if state.magic then
            if target then
                local character = target:FindFirstAncestorOfClass("Model")
                local owner = character and Players:GetPlayerFromCharacter(character)
                lockBadge.Text = "VISUAL LOCK: " .. (owner and owner.Name or "Target")
                    .. "  (no spoof)"
                local point, onScreen = camera:WorldToViewportPoint(target.Position)
                lockMarker.Visible = onScreen
                if onScreen then lockMarker.Position = UDim2.fromOffset(point.X, point.Y) end
            else
                lockBadge.Text = "MAGIC: SEARCHING  (no spoof)"
            end
        elseif target then
            local goal = CFrame.lookAt(camera.CFrame.Position, target.Position)
            local alpha = state.strength >= 100 and 1 or (1 - math.exp(-dt * state.strength * 0.65))
            camera.CFrame = camera.CFrame:Lerp(goal, alpha)
        end
    end
    if state.trigger then
        -- Triggerbot always requires line of sight; team filtering follows Team check.
        local target = closest(camera, state.triggerFov, true)
        local now = os.clock()
        if target ~= lastTarget then
            lastTarget, targetSince = target, now
        end
        if target and now - targetSince >= state.mercy and now - lastShot >= 0.12 then
            if type(mouse1click) == "function" then
                local fired, err = pcall(mouse1click)
                if fired then
                    lastShot = now
                elseif not warnedClick then
                    warnedClick = true
                    warn("Triggerbot: mouse1click failed:", err)
                end
            elseif not warnedClick then
                warnedClick = true
                warn("Triggerbot: this executor does not expose mouse1click; automatic firing is unavailable.")
            end
		end
    else
        lastTarget = nil
    end
end)
