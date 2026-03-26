--!optimize 2
-- ================================================================
--  Severe | Solid Woven Asian Hat
--  F4 → Toggle Hat ON/OFF
--  Uses DrawingImmediate for solid filled polygons & woven details.
-- ================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local DI = DrawingImmediate

-- ── Config ───────────────────────────────────────────────────────
local KEY_TOGGLE = "f4"
local KEY_DELAY  = 0.3

local Config = {
    radius = 2.4,        -- Width of the brim
    height = 1.3,        -- Height of the cone
    y_offset = 0.6,      -- How high it sits above the center of the head
    segments = 16,       -- Number of vertical panels (smoothness)
    rings = 4,           -- Number of horizontal woven rings
    
    colorFill = Color3.fromRGB(238, 197, 145), -- Base straw color
    colorLine = Color3.fromRGB(156, 118, 70),  -- Darker weave accents
    opacity = 0.95
}

-- ── State ────────────────────────────────────────────────────────
local active = true
local last_toggle = 0
local currentKeys = {}

send_notification("[Cosmetics] Woven Hat Loaded - Press F4", "success")

-- [ CRASH PREVENTION ]
if _G.SevereHatRender then 
    pcall(function() _G.SevereHatRender:Disconnect() end) 
end

-- ── Render Loop (Drawing) ────────────────────────────────────────
_G.SevereHatRender = RunService.Render:Connect(function()
    pcall(function()
        -- 1. Single-Poll Input
        local ok, keys = pcall(getpressedkeys)
        currentKeys = (ok and type(keys) == "table") and keys or {}

        local now = os.clock()
        if now - last_toggle > KEY_DELAY then
            for i = 1, #currentKeys do
                local s_ok, k = pcall(function() return tostring(currentKeys[i]):lower() end)
                if s_ok and k == KEY_TOGGLE then
                    active = not active
                    last_toggle = now
                    send_notification("Woven Hat: " .. (active and "ON" or "OFF"), "info")
                    break
                end
            end
        end

        if not active then return end

        local char = LocalPlayer.Character
        if not char then return end
        local head = char:FindFirstChild("Head")
        if not head then return end
        
        local cam = workspace.CurrentCamera
        if not cam then return end
        
        -- 2. Calculate Top Tip of the Hat
        local hPos = head.Position
        local top3D = hPos + Vector3.new(0, Config.y_offset + Config.height, 0)
        
        local topScr, topVis = cam:WorldToScreenPoint(top3D)
        local top2D = Vector2.new(topScr.X or topScr.x or 0, topScr.Y or topScr.y or 0)
        
        -- 3. Calculate Base Rim Points
        local basePoints2D = {}
        local baseVis = {}
        
        for i = 1, Config.segments do
            local angle = (i / Config.segments) * math.pi * 2
            local p3D = hPos + Vector3.new(
                math.cos(angle) * Config.radius,
                Config.y_offset,
                math.sin(angle) * Config.radius
            )
            local scr, vis = cam:WorldToScreenPoint(p3D)
            basePoints2D[i] = Vector2.new(scr.X or scr.x or 0, scr.Y or scr.y or 0)
            baseVis[i] = vis
        end
        
        -- 4. Draw Solid Hat Panels & Vertical Ribs
        for i = 1, Config.segments do
            local next_i = (i % Config.segments) + 1
            
            local p1 = basePoints2D[i]
            local p2 = basePoints2D[next_i]
            local v1 = baseVis[i]
            local v2 = baseVis[next_i]
            
            if topVis and v1 and v2 then
                -- Solid color panel filling the gap
                pcall(function()
                    DI.FilledTriangle(top2D, p1, p2, Config.colorFill, Config.opacity)
                end)
                
                -- Darker vertical rib structural outline
                pcall(function()
                    DI.Line(top2D, p1, Config.colorLine, Config.opacity, 1, 1)
                    DI.Line(p1, p2, Config.colorLine, Config.opacity, 1, 1)
                end)
            end
        end
        
        -- 5. Draw Horizontal Woven Rings
        for ring = 1, Config.rings do
            local t = ring / (Config.rings + 1)
            -- Intersect height and radius based on the ring level
            local ringY = Config.y_offset + (Config.height * (1 - t))
            local ringRad = Config.radius * t
            
            local prev2D = nil
            local prevVis = false
            local first2D = nil
            local firstVis = false
            
            for i = 1, Config.segments do
                local angle = (i / Config.segments) * math.pi * 2
                local p3D = hPos + Vector3.new(
                    math.cos(angle) * ringRad,
                    ringY,
                    math.sin(angle) * ringRad
                )
                local scr, vis = cam:WorldToScreenPoint(p3D)
                local curr2D = Vector2.new(scr.X or scr.x or 0, scr.Y or scr.y or 0)
                
                if i == 1 then
                    first2D = curr2D
                    firstVis = vis
                end
                
                if i > 1 and vis and prevVis then
                    pcall(function()
                        DI.Line(prev2D, curr2D, Config.colorLine, Config.opacity, 1, 1)
                    end)
                end
                
                prev2D = curr2D
                prevVis = vis
            end
            
            -- Close the final ring segment
            if prevVis and firstVis then
                 pcall(function()
                     DI.Line(prev2D, first2D, Config.colorLine, Config.opacity, 1, 1)
                 end)
            end
        end
    end)
end)