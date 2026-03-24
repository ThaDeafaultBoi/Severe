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
local KEYBIND      = "f1"
local KEY_DELAY    = 0.3
local BASE_SPEED   = 1.0
local FAST_SPEED   = 3.5
local SENSITIVITY  = 0.004
local MOVE_SMOOTH  = 0.25
local MOUSE_SMOOTH = 0.45

-- ── State ────────────────────────────────────────────────────────
local active      = false
local last_toggle = 0

local camX, camY, camZ  = 0, 0, 0
local camYaw, camPitch  = 0, 0
local tgtX, tgtY, tgtZ = 0, 0, 0
local tgtYaw, tgtPitch  = 0, 0
local lastMX, lastMY    = nil, nil
local sDX, sDY          = 0, 0
local currentKeys       = {}

-- ── Helpers ──────────────────────────────────────────────────────

-- Guards against NaN / inf which cause CFrame crashes
local function safe(v, fallback)
    if type(v) ~= "number" then return fallback end
    if v ~= v then return fallback end
    if v == math.huge or v == -math.huge then return fallback end
    return v
end

local function isPressed(k)
    for i = 1, #currentKeys do
        -- Each key comparison in its own pcall — one bad value won't break the loop
        local ok, s = pcall(function()
            return tostring(currentKeys[i]):lower()
        end)
        if ok and s == k then return true end
    end
    return false
end

local function yawFromCF(cf)
    local lx = safe(cf.LookVector.X or cf.LookVector.x, 0)
    local lz = safe(cf.LookVector.Z or cf.LookVector.z, 0)
    local r = math.atan2(-lx, -lz)
    return safe(r, 0)
end

local function pitchFromCF(cf)
    local ly = safe(cf.LookVector.Y or cf.LookVector.y, 0)
    local r = math.asin(math.clamp(ly, -1, 1))
    return safe(r, 0)
end

local function makeCF(x, y, z, ya, pi)
    -- Sanitize all inputs before building CFrame — NaN in any value = crash
    x  = safe(x,  0) ; y  = safe(y,  0) ; z  = safe(z,  0)
    ya = safe(ya, 0) ; pi = safe(pi, 0)
    local origin   = CFrame.new(x, y, z)
    local rotYaw   = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), ya)
    local rotPitch = CFrame.fromAxisAngle(Vector3.new(1, 0, 0), pi)
    return origin * rotYaw * rotPitch
end

local function lerp(a, b, t)
    a = safe(a, 0) ; b = safe(b, 0) ; t = safe(t, 0)
    return a + (b - a) * t
end

-- ── Enable / Disable ─────────────────────────────────────────────
local function enableFreecam()
    local cam = workspace.CurrentCamera
    if not cam then
        send_notification("[FreeCam] No camera", "error")
        return
    end

    pcall(function()
        local cf = cam.CFrame
        camX = safe(cf.X or cf.Position.X, 0)
        camY = safe(cf.Y or cf.Position.Y, 0)
        camZ = safe(cf.Z or cf.Position.Z, 0)
        camYaw   = yawFromCF(cf)
        camPitch = pitchFromCF(cf)
        tgtX, tgtY, tgtZ  = camX, camY, camZ
        tgtYaw, tgtPitch  = camYaw, camPitch
    end)

    sDX, sDY       = 0, 0
    lastMX, lastMY = nil, nil
    currentKeys    = {}

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

    pcall(function()
        local cam  = workspace.CurrentCamera
        local char = LocalPlayer.Character
        if cam and char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then cam.CameraSubject = hum end
        end
    end)

    lastMX, lastMY = nil, nil
    sDX, sDY       = 0, 0
    send_notification("[FreeCam] OFF", "info")
end

-- ── Render ───────────────────────────────────────────────────────
RunService.Render:Connect(function()
    -- Entire frame in pcall — nothing can propagate and crash
    pcall(function()

        -- Read keys exactly once per frame
        local ok, keys = pcall(getpressedkeys)
        currentKeys = (ok and type(keys) == "table") and keys or {}

        -- Toggle
        local now = os.clock()
        if now - last_toggle > KEY_DELAY and isPressed(KEYBIND) then
            last_toggle = now
            if not active then enableFreecam()
            else disableFreecam() end
            return
        end

        if not active then return end

        local cam = workspace.CurrentCamera
        if not cam then return end

        -- ── Mouse look ───────────────────────────────────────────
        local mpOk, mp = pcall(getmouseposition)
        if not mpOk or not mp then return end

        local mx = safe(mp.X or mp.x, 0)
        local my = safe(mp.Y or mp.y, 0)

        if lastMX ~= nil then
            -- Clamp raw delta to prevent massive spikes (alt-tab, focus loss etc.)
            local rawDX = math.clamp((mx - lastMX) * SENSITIVITY, -0.1, 0.1)
            local rawDY = math.clamp((my - lastMY) * SENSITIVITY, -0.1, 0.1)
            sDX = sDX + (rawDX - sDX) * MOUSE_SMOOTH
            sDY = sDY + (rawDY - sDY) * MOUSE_SMOOTH
            tgtYaw   = tgtYaw   - sDX
            tgtPitch = math.clamp(tgtPitch - sDY, -1.48, 1.48)
        end
        lastMX, lastMY = mx, my

        -- ── Movement ─────────────────────────────────────────────
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

        -- ── Lerp ─────────────────────────────────────────────────
        local posT = fast and 0.95 or (1 - MOVE_SMOOTH)
        local rotT = 1 - MOVE_SMOOTH
        camX     = lerp(camX,     tgtX,     posT)
        camY     = lerp(camY,     tgtY,     posT)
        camZ     = lerp(camZ,     tgtZ,     posT)
        camYaw   = lerp(camYaw,   tgtYaw,   rotT)
        camPitch = lerp(camPitch, tgtPitch, rotT)

        -- Write cam.CFrame — guarded by makeCF sanitization + outer pcall
        cam.CFrame = makeCF(camX, camY, camZ, camYaw, camPitch)

    end) -- end pcall
end)

send_notification("[FreeCam] Loaded  —  F1 to toggle", "success")
