--!optimize 2
-- ================================================================
--  Severe | Solid Woven Asian Hat v2 (GUI Edition)
--  F3 → Toggle GUI Panel | F4 → Toggle Hat
-- ================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local DI = DrawingImmediate

-- ── State & Config (Persistent) ──────────────────────────────────
if not _G.SevereHatState then
    _G.SevereHatState = {
        active     = true,
        guiVisible = true,
        panelX     = 50,
        panelY     = 200,
        
        radius     = 2.4,
        height     = 1.3,
        offset     = 0.6,
        opacity    = 0.95,
        themeIdx   = 1,
        segments   = 16,
        rings      = 4
    }
end
local S = _G.SevereHatState

local KEY_GUI    = "f3"
local KEY_HAT    = "f4"
local KEY_DELAY  = 0.3

local currentKeys = {}
local last_toggle = 0

-- UI Interaction State
local prevHeld = false
local dragPhase = 0
local dragOX, dragOY = 0, 0
local activeSlider = nil

-- Themes
local Themes = {
    {name = "Bamboo",      fill = Color3.fromRGB(238, 197, 145), line = Color3.fromRGB(156, 118, 70)},
    {name = "Dark Straw",  fill = Color3.fromRGB(139, 101, 8),   line = Color3.fromRGB(60, 40, 0)},
    {name = "Jade",        fill = Color3.fromRGB(75, 150, 100),  line = Color3.fromRGB(20, 80, 40)},
    {name = "Imperial",    fill = Color3.fromRGB(180, 30, 30),   line = Color3.fromRGB(80, 10, 10)}
}

-- [ CRASH PREVENTION ]
if _G.SevereHatRender then pcall(function() _G.SevereHatRender:Disconnect() end) end

-- ── Helpers ──────────────────────────────────────────────────────
local function safe(v, fb)
    if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return fb end
    return v
end

local function inRect(mx, my, rx, ry, rw, rh)
    return mx >= rx and mx <= rx + rw and my >= ry and my <= ry + rh
end

-- ── Main Loop (Render + GUI) ─────────────────────────────────────
_G.SevereHatRender = RunService.Render:Connect(function()
    pcall(function()
        -- 1. Input Polling
        local ok, keys = pcall(getpressedkeys)
        currentKeys = (ok and type(keys) == "table") and keys or {}

        local now = os.clock()
        if now - last_toggle > KEY_DELAY then
            for i = 1, #currentKeys do
                local s_ok, k = pcall(function() return tostring(currentKeys[i]):lower() end)
                if s_ok then
                    if k == KEY_GUI then
                        S.guiVisible = not S.guiVisible
                        last_toggle = now
                        break
                    elseif k == KEY_HAT then
                        S.active = not S.active
                        last_toggle = now
                        break
                    end
                end
            end
        end

        local char = LocalPlayer.Character
        local head = char and char:FindFirstChild("Head")
        local cam = workspace.CurrentCamera
        local curTheme = Themes[S.themeIdx]

        -- 2. Draw Hat
        if S.active and head and cam then
            local hPos = head.Position
            local top3D = hPos + Vector3.new(0, S.offset + S.height, 0)
            local topScr, topVis = cam:WorldToScreenPoint(top3D)
            local top2D = Vector2.new(safe(topScr.X or topScr.x, 0), safe(topScr.Y or topScr.y, 0))
            
            local basePoints2D = {}
            local baseVis = {}
            
            for i = 1, S.segments do
                local angle = (i / S.segments) * math.pi * 2
                local p3D = hPos + Vector3.new(math.cos(angle) * S.radius, S.offset, math.sin(angle) * S.radius)
                local scr, vis = cam:WorldToScreenPoint(p3D)
                basePoints2D[i] = Vector2.new(safe(scr.X or scr.x, 0), safe(scr.Y or scr.y, 0))
                baseVis[i] = vis
            end
            
            for i = 1, S.segments do
                local next_i = (i % S.segments) + 1
                local p1, p2 = basePoints2D[i], basePoints2D[next_i]
                local v1, v2 = baseVis[i], baseVis[next_i]
                
                if topVis and v1 and v2 then
                    pcall(function() DI.FilledTriangle(top2D, p1, p2, curTheme.fill, S.opacity) end)
                    pcall(function()
                        DI.Line(top2D, p1, curTheme.line, S.opacity, 1, 1)
                        DI.Line(p1, p2, curTheme.line, S.opacity, 1, 1)
                    end)
                end
            end
            
            for ring = 1, S.rings do
                local t = ring / (S.rings + 1)
                local ringY = S.offset + (S.height * (1 - t))
                local ringRad = S.radius * t
                local prev2D, prevVis, first2D, firstVis = nil, false, nil, false
                
                for i = 1, S.segments do
                    local angle = (i / S.segments) * math.pi * 2
                    local p3D = hPos + Vector3.new(math.cos(angle) * ringRad, ringY, math.sin(angle) * ringRad)
                    local scr, vis = cam:WorldToScreenPoint(p3D)
                    local curr2D = Vector2.new(safe(scr.X or scr.x, 0), safe(scr.Y or scr.y, 0))
                    
                    if i == 1 then first2D = curr2D; firstVis = vis end
                    if i > 1 and vis and prevVis then
                        pcall(function() DI.Line(prev2D, curr2D, curTheme.line, S.opacity, 1, 1) end)
                    end
                    prev2D = curr2D; prevVis = vis
                end
                
                if prevVis and firstVis then
                     pcall(function() DI.Line(prev2D, first2D, curTheme.line, S.opacity, 1, 1) end)
                end
            end
        end

        -- 3. Draw GUI Panel
        if S.guiVisible then
            local mp = getmouseposition()
            local mx = safe(mp.X or mp.x, 0)
            local my = safe(mp.Y or mp.y, 0)
            local lHeld = isleftpressed()
            local lClick = lHeld and not prevHeld
            local lRelease = not lHeld and prevHeld
            prevHeld = lHeld

            local vp = cam and cam.ViewportSize
            local vpW = safe(vp and (vp.X or vp.x), 1920)
            local vpH = safe(vp and (vp.Y or vp.y), 1080)

            local pW, pH = 220, 210
            local px, py = S.panelX, S.panelY

            -- Drag Logic
            if lClick and inRect(mx, my, px, py, pW, 25) then
                dragPhase = 1
                dragOX, dragOY = mx - px, my - py
            end
            if dragPhase == 1 and (math.abs(mx - (px + dragOX)) > 2 or math.abs(my - (py + dragOY)) > 2) then dragPhase = 2 end
            if dragPhase == 2 and lHeld then
                S.panelX = math.clamp(mx - dragOX, 0, vpW - pW)
                S.panelY = math.clamp(my - dragOY, 0, vpH - pH)
            end
            if lRelease then dragPhase = 0; activeSlider = nil end

            -- Panel Background
            DI.FilledRectangle(Vector2.new(px, py), Vector2.new(pW, pH), Color3.fromRGB(20, 20, 25), 0.95)
            DI.Rectangle(Vector2.new(px, py), Vector2.new(pW, pH), Color3.fromRGB(50, 50, 60), 0.8, 1)
            
            -- Header
            DI.FilledRectangle(Vector2.new(px, py), Vector2.new(pW, 25), Color3.fromRGB(180, 40, 40), 1)
            DI.OutlinedText(Vector2.new(px + pW/2, py + 5), 14, Color3.fromRGB(255,255,255), 1, "Woven Hat Config", true, "Proggy")

            local cy = py + 35
            
            -- Helper to draw sliders
            local function drawSlider(label, key, minVal, maxVal)
                DI.Text(Vector2.new(px + 10, cy), 13, Color3.fromRGB(200, 200, 200), 1, string.format("%s: %.1f", label, S[key]), false, "Proggy")
                cy = cy + 15
                local sX, sY, sW, sH = px + 10, cy, pW - 20, 10
                
                DI.FilledRectangle(Vector2.new(sX, sY), Vector2.new(sW, sH), Color3.fromRGB(40, 40, 50), 1)
                
                if lClick and inRect(mx, my, sX, sY, sW, sH) then activeSlider = key end
                if activeSlider == key and lHeld then
                    local pct = math.clamp((mx - sX) / sW, 0, 1)
                    S[key] = minVal + ((maxVal - minVal) * pct)
                end
                
                local fillW = sW * ((S[key] - minVal) / (maxVal - minVal))
                DI.FilledRectangle(Vector2.new(sX, sY), Vector2.new(fillW, sH), Color3.fromRGB(220, 80, 80), 1)
                cy = cy + 20
            end

            drawSlider("Radius", "radius", 1.0, 5.0)
            drawSlider("Height", "height", 0.1, 4.0)
            drawSlider("Offset", "offset", -2.0, 3.0)
            drawSlider("Opacity", "opacity", 0.1, 1.0)

            -- Theme Button
            local btnX, btnY, btnW, btnH = px + 10, cy, pW - 20, 20
            local btnHov = inRect(mx, my, btnX, btnY, btnW, btnH)
            DI.FilledRectangle(Vector2.new(btnX, btnY), Vector2.new(btnW, btnH), btnHov and Color3.fromRGB(60,60,70) or Color3.fromRGB(40,40,50), 1)
            DI.Rectangle(Vector2.new(btnX, btnY), Vector2.new(btnW, btnH), Color3.fromRGB(100,100,110), 1, 1)
            DI.OutlinedText(Vector2.new(px + pW/2, btnY + 4), 13, Color3.fromRGB(255,255,255), 1, "Theme: " .. curTheme.name, true, "Proggy")
            
            if lClick and btnHov then
                S.themeIdx = (S.themeIdx % #Themes) + 1
            end
            
            -- Footer hints
            DI.Text(Vector2.new(px + pW/2, py + pH - 15), 11, Color3.fromRGB(120, 120, 130), 1, "[F3] Hide UI  |  [F4] Toggle Hat", true, "Tamzen")
        end
    end)
end)