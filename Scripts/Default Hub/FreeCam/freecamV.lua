--!optimize 2
-- ================================================================
--  Severe | Universal FreeCam
--  F1      → toggle
--  W/A/S/D → move  |  Q/E → down/up  |  Shift → fast
--  Mouse   → look
-- ================================================================

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- ── Config ───────────────────────────────────────────────────────
local KEYBIND     = "f1"
local KEY_DELAY   = 0.3
local BASE_SPEED  = 1.0
local FAST_SPEED  = 3.5
local SENSITIVITY = 0.004
local MOVE_SMOOTH  = 0.25
local MOUSE_SMOOTH = 0.45

-- ── State ────────────────────────────────────────────────────────
local active      = false
local last_toggle = 0

local camX, camY, camZ   = 0, 0, 0
local camYaw, camPitch   = 0, 0
local tgtX, tgtY, tgtZ  = 0, 0, 0
local tgtYaw, tgtPitch  = 0, 0
local lastMX, lastMY    = nil, nil
local sDX, sDY          = 0, 0

-- Single shared keys table — read once per frame, reused everywhere
-- This avoids multiple getpressedkeys() calls which can race/crash
local currentKeys = {}

-- ── Helpers ──────────────────────────────────────────────────────
local function isPressed(k)
    for i = 1, #currentKeys do
        if tostring(currentKeys[i]):lower() == k then return true end
    end
    return false
end

local function yawFromCF(cf)
    local lx = cf.LookVector.X or cf.LookVector.x or 0
    local lz = cf.LookVector.Z or cf.LookVector.z or 0
    return math.atan2(-lx, -lz)
end

local function pitchFromCF(cf)
    local ly = cf.LookVector.Y or cf.LookVector.y or 0
    return math.asin(math.clamp(ly, -1, 1))
end

local function makeCF(x, y, z, ya, pi)
    local origin   = CFrame.new(x, y, z)
    local rotYaw   = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), ya)
    local rotPitch = CFrame.fromAxisAngle(Vector3.new(1, 0, 0), pi)
    return origin * rotYaw * rotPitch
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

-- ── Enable / Disable ─────────────────────────────────────────────
local function enableFreecam()
    local cam = workspace.CurrentCamera
    if not cam then
        send_notification("[FreeCam] No camera", "error")
        return
    end

    local cf = cam.CFrame
    camX = cf.X or cf.Position.X or 0
    camY = cf.Y or cf.Position.Y or 0
    camZ = cf.Z or cf.Position.Z or 0
    camYaw   = yawFromCF(cf)
    camPitch = pitchFromCF(cf)
    tgtX, tgtY, tgtZ   = camX, camY, camZ
    tgtYaw, tgtPitch   = camYaw, camPitch
    sDX, sDY           = 0, 0
    lastMX, lastMY     = nil, nil
    currentKeys        = {}

    pcall(function()
        game:GetService("UserInputService").MouseBehavior = 0
    end)
    pcall(function() cam.CameraSubject = nil end)

    active = true
    send_notification("[FreeCam] ON  —  F1 to exit", "info")
end

local function disableFreecam()
    active      = false
    currentKeys = {}

    local cam  = workspace.CurrentCamera
    local char = LocalPlayer.Character
    if cam and char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() cam.CameraSubject = hum end)
        end
    end

    lastMX, lastMY = nil, nil
    sDX, sDY       = 0, 0
    send_notification("[FreeCam] OFF", "info")
end

-- ── Render ───────────────────────────────────────────────────────
RunService.Render:Connect(function()
    -- Always read keys once at the top of the frame — safe, no racing
    local ok, keys = pcall(getpressedkeys)
    currentKeys = (ok and type(keys) == "table") and keys or {}

    -- Check toggle key
    local now = os.clock()
    if now - last_toggle > KEY_DELAY and isPressed(KEYBIND) then
        last_toggle = now
        if not active then enableFreecam()
        else disableFreecam() end
        return  -- skip this frame after toggle
    end

    if not active then return end

    local cam = workspace.CurrentCamera
    if not cam then return end

    -- ── Mouse look ───────────────────────────────────────────────
    local mp = getmouseposition()
    local mx = mp.X or mp.x or 0
    local my = mp.Y or mp.y or 0

    if lastMX ~= nil then
        local rawDX = (mx - lastMX) * SENSITIVITY
        local rawDY = (my - lastMY) * SENSITIVITY
        sDX = sDX + (rawDX - sDX) * MOUSE_SMOOTH
        sDY = sDY + (rawDY - sDY) * MOUSE_SMOOTH
        tgtYaw   = tgtYaw   - sDX
        tgtPitch = math.clamp(tgtPitch - sDY, -1.48, 1.48)
    end
    lastMX, lastMY = mx, my

    -- ── Movement ─────────────────────────────────────────────────
    local fast  = isPressed("shift") or isPressed("leftshift")
    local speed = fast and FAST_SPEED or BASE_SPEED

    local sinY = math.sin(tgtYaw)
    local cosY = math.cos(tgtYaw)

    if isPressed("w") then tgtX -= sinY*speed ; tgtZ -= cosY*speed end
    if isPressed("s") then tgtX += sinY*speed ; tgtZ += cosY*speed end
    if isPressed("a") then tgtX -= cosY*speed ; tgtZ += sinY*speed end
    if isPressed("d") then tgtX += cosY*speed ; tgtZ -= sinY*speed end
    if isPressed("e") then tgtY += speed end
    if isPressed("q") then tgtY -= speed end

    -- ── Lerp ─────────────────────────────────────────────────────
    -- Snappier lerp when boosting so speed increase is felt
    local posT = fast and 0.95 or (1 - MOVE_SMOOTH)
    local rotT = 1 - MOVE_SMOOTH
    camX     = lerp(camX,     tgtX,     posT)
    camY     = lerp(camY,     tgtY,     posT)
    camZ     = lerp(camZ,     tgtZ,     posT)
    camYaw   = lerp(camYaw,   tgtYaw,   rotT)
    camPitch = lerp(camPitch, tgtPitch, rotT)

    pcall(function()
        cam.CFrame = makeCF(camX, camY, camZ, camYaw, camPitch)
    end)
end)

send_notification("[FreeCam] Loaded  —  F1 to toggle", "success")
