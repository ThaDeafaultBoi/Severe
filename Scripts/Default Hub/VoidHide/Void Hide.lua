--!native
--!optimize 2
-- ================================================================
--  Severe | Universal Void Hide
--  Based exactly on the original working approach:
--    - hrp.Position additive offset every frame (keeps you out)
--    - hrp.Position = SavedPosition on return (single write)
--  Fixed:
--    - Keybind uses table.find + uppercase match (confirmed working)
--    - Added on-screen button as backup
--    - Debounce via task.wait inside the key loop
-- ================================================================

---- environment ----
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

---- constants ----
local VOID_OFFSET = 5000   -- far enough to leave any map, close enough renderer doesn't break
local KEYBIND     = "V"    -- uppercase, matched via table.find
local KEY_DELAY   = 0.2

---- variables ----
local LocalPlayer  = Players.LocalPlayer
local Enabled      = false
local SavedPosition = nil
local JustDisabled = false
local last_toggle  = 0

---- button layout ----
local BTN_X = 20
local BTN_Y = 20
local BTN_W = 140
local BTN_H = 28

local C = {
    bg     = Color3.fromRGB( 10,  12,  18),
    border = Color3.fromRGB( 34,  40,  64),
    blue   = Color3.fromRGB( 80, 120, 255),
    red    = Color3.fromRGB(195,  52,  52),
    dim    = Color3.fromRGB( 44,  50,  72),
    white  = Color3.fromRGB(255, 255, 255),
}

---- helpers ----
local function getHRP()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function inRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

local function doToggle()
    local hrp = getHRP()
    if not hrp then
        send_notification("[VoidHide] No character", "error")
        return
    end
    if not Enabled then
        SavedPosition = hrp.Position
        Enabled = true
        send_notification("[VoidHide] In void — press V or click to return", "info")
    else
        JustDisabled = true
        Enabled = false
        send_notification("[VoidHide] Returning...", "info")
    end
end

---- keybind loop (original pattern: task.spawn + table.find) ----
task.spawn(function()
    while task.wait(0.05) do
        local now = os.clock()
        if now - last_toggle > KEY_DELAY then
            local keys = getpressedkeys()
            if table.find(keys, KEYBIND) then
                last_toggle = now
                doToggle()
                task.wait(KEY_DELAY)
            end
        end
    end
end)

---- drawing ----
local DI = DrawingImmediate

local function fRect(x, y, w, h, col, op)
    DI.FilledRectangle(Vector2.new(x, y), Vector2.new(w, h), col, op or 1)
end
local function sRect(x, y, w, h, col, thick, op)
    DI.Rectangle(Vector2.new(x, y), Vector2.new(w, h), col, op or 1, thick or 1)
end
local function lbl(x, y, sz, col, s, center)
    DI.OutlinedText(Vector2.new(x, y), sz, col, 1, s, center or false, "Tamzen")
end

---- button input ----
local prevHeld  = false
local clickCool = 0

RunService.Render:Connect(function(dt)
    local mp      = getmouseposition()
    local mx      = mp.X or mp.x or 0
    local my      = mp.Y or mp.y or 0
    local lHeld   = isleftpressed()
    local clicked = lHeld and not prevHeld
    prevHeld = lHeld

    if clickCool > 0 then clickCool -= dt end

    local hovering = inRect(mx, my, BTN_X, BTN_Y, BTN_W, BTN_H)
    if clicked and hovering and clickCool <= 0 then
        clickCool = 0.3
        doToggle()
    end

    -- draw button
    local bgCol = Enabled and C.red or (hovering and C.blue or C.dim)
    fRect(BTN_X, BTN_Y, BTN_W, BTN_H, C.bg)
    fRect(BTN_X, BTN_Y, BTN_W, BTN_H, bgCol, 0.9)
    sRect(BTN_X, BTN_Y, BTN_W, BTN_H, C.border, 1, 0.8)
    fRect(BTN_X, BTN_Y, 2, BTN_H, Enabled and C.red or C.blue)
    lbl(BTN_X + BTN_W / 2, BTN_Y + BTN_H / 2 - 6, 12, C.white,
        Enabled and "VOID  [V / click]" or "VOID HIDE  [V / click]", true)
end)

---- main physics loop (original logic, unchanged) ----
RunService.PostLocal:Connect(function()
    local hrp = getHRP()
    if not hrp then return end

    if Enabled then
        -- Additive every frame — keeps pushing further out,
        -- server corrections can never catch up
        local pos = hrp.Position
        hrp.Position = Vector3.new(
            pos.X + VOID_OFFSET,
            pos.Y + VOID_OFFSET,
            pos.Z + VOID_OFFSET
        )
    elseif JustDisabled and SavedPosition then
        hrp.Position = SavedPosition
        hrp.Velocity = Vector3.new(0, 0, 0)
        JustDisabled  = false
        SavedPosition = nil
    end
end)

send_notification("[VoidHide] Ready — V or click button", "success")
