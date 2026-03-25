--!optimize 2

-- ═══════════════════════════════════════════════════════════════
--  Player Fling GUI v4
--  F2 = toggle panel | Player list + autocomplete for selection
--  "Fling" = one-shot | "Spam Fling" = repeat on timer
--  Sustained mode for fall-damage games | Spectate target
-- ═══════════════════════════════════════════════════════════════

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local DI          = DrawingImmediate

-- ── Config ──
local PANEL_KEY   = "f2"
local KEY_DELAY   = 0.3

local QUICK_FRAMES = 30
local QUICK_VEL    = 14000
local SUST_FRAMES  = 90
local SUST_VEL     = 9000
local RETURN_FRAMES = 12

-- ── Colors ──
local COL_BG       = Color3.fromRGB(15, 15, 22)
local COL_HEADER   = Color3.fromRGB(180, 40, 60)
local COL_ACCENT   = Color3.fromRGB(220, 50, 70)
local COL_BTN      = Color3.fromRGB(35, 35, 50)
local COL_HOVW     = Color3.fromRGB(255, 255, 255)
local COL_INPUT_BG = Color3.fromRGB(28, 28, 40)
local COL_INPUT_BD = Color3.fromRGB(70, 70, 100)
local COL_INPUT_AC = Color3.fromRGB(220, 50, 70)
local COL_TEXT     = Color3.fromRGB(240, 240, 255)
local COL_DIM      = Color3.fromRGB(130, 130, 155)
local COL_BORDER   = Color3.fromRGB(50, 50, 70)
local COL_GREEN    = Color3.fromRGB(60, 200, 100)
local COL_BLUE     = Color3.fromRGB(50, 120, 220)
local COL_PLUS     = Color3.fromRGB(60, 160, 220)
local COL_MINUS    = Color3.fromRGB(220, 140, 50)
local COL_YELLOW   = Color3.fromRGB(240, 200, 60)
local COL_CHECK_ON = Color3.fromRGB(80, 220, 140)
local COL_CHECK_OFF= Color3.fromRGB(55, 55, 75)
local COL_CYAN     = Color3.fromRGB(60, 200, 230)
local COL_LIST_BG  = Color3.fromRGB(22, 22, 32)
local COL_LIST_HOV = Color3.fromRGB(45, 45, 65)
local COL_LIST_SEL = Color3.fromRGB(60, 40, 120)

-- ── Layout ──
local panelW    = 270
local headerH   = 34
local padX      = 12
local padY      = 10
local inputH    = 30
local btnH      = 32
local checkH    = 28
local smallBtnW = 32
local gap       = 8
local listItemH = 24
local MAX_VISIBLE_PLAYERS = 6

-- ── State (persisted) ──
if not _G.FlingGUI4 then
    _G.FlingGUI4 = {
        panelX     = 60,
        panelY     = 80,
        visible    = true,
        inputText  = "",
        inputFocused = false,
        selectedPlayer = "",     -- resolved full name of target
        showList   = false,      -- player list expanded
        listScroll = 0,          -- scroll offset
        spamActive = false,
        spamDelay  = 2.0,
        sustained  = false,
        spectating = false,
        spectateName = "",
        -- Fling state
        flingPhase = "idle",
        flingFrames = 0,
        flingTargetName = "",
        savedPos   = nil,
    }
end
local S = _G.FlingGUI4

local currentKeys  = {}
local lastToggle   = 0
local lastType     = 0
local prevHeld     = false
local dragPhase    = 0
local dragOX, dragOY = 0, 0
local lastSpamTime = 0
local cursorBlink  = 0

-- Disconnect old connections
if _G.Fling4_Render then pcall(function() _G.Fling4_Render:Disconnect() end) end
if _G.Fling4_Post   then pcall(function() _G.Fling4_Post:Disconnect() end) end

-- ── Helpers ──
local function isPressed(k)
    for i = 1, #currentKeys do
        local ok, s = pcall(function() return tostring(currentKeys[i]):lower() end)
        if ok and s == k then return true end
    end
    return false
end

local function inRect(mx, my, rx, ry, rw, rh)
    return mx >= rx and mx <= rx + rw and my >= ry and my <= ry + rh
end

local function safe(v, fb)
    if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return fb end
    return v
end

local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function readPos(part)
    local ok, pos = pcall(function() return part.Position end)
    if not ok or not pos then return nil end
    return {
        x = safe(pos.X or pos.x, 0),
        y = safe(pos.Y or pos.y, 0),
        z = safe(pos.Z or pos.z, 0),
    }
end

-- Get all other players
local function getOtherPlayers()
    local list = {}
    for _, p in Players:GetChildren() do
        if p ~= LocalPlayer then
            local nOk, name = pcall(function() return p.Name end)
            local dOk, dname = pcall(function() return p.DisplayName end)
            if nOk then
                table.insert(list, {
                    player = p,
                    name = name,
                    display = (dOk and dname) or name,
                })
            end
        end
    end
    return list
end

-- Filter players by partial match
local function filterPlayers(allPlayers, query)
    if not query or query == "" then return allPlayers end
    local lower = query:lower()
    local matches = {}
    for _, entry in ipairs(allPlayers) do
        if entry.name:lower():sub(1, #lower) == lower or
           entry.display:lower():sub(1, #lower) == lower or
           entry.name:lower():find(lower, 1, true) or
           entry.display:lower():find(lower, 1, true) then
            table.insert(matches, entry)
        end
    end
    return matches
end

local function findPlayerByName(name)
    if not name or name == "" then return nil end
    local lower = name:lower()
    for _, p in Players:GetChildren() do
        if p ~= LocalPlayer then
            local nOk, pn = pcall(function() return p.Name end)
            local dOk, dn = pcall(function() return p.DisplayName end)
            if (nOk and pn:lower() == lower) or (dOk and dn:lower() == lower) then
                return p
            end
            -- Partial match
            if (nOk and pn:lower():sub(1, #lower) == lower) or
               (dOk and dn:lower():sub(1, #lower) == lower) then
                return p
            end
        end
    end
    return nil
end

local function getTargetHRP(player)
    local ok, char = pcall(function() return player.Character end)
    if not ok or not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function getTargetHumanoid(player)
    local ok, char = pcall(function() return player.Character end)
    if not ok or not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

local function selectPlayer(name)
    S.selectedPlayer = name
    S.inputText = name
    S.inputFocused = false
    S.showList = false
    send_notification("Selected: " .. name, "info")
end

local function startFling()
    local targetName = S.selectedPlayer ~= "" and S.selectedPlayer or S.inputText
    if targetName == "" then
        send_notification("Select a target first!", "error")
        return false
    end
    local target = findPlayerByName(targetName)
    if not target then
        send_notification("Player not found: " .. targetName, "error")
        return false
    end
    local thrp = getTargetHRP(target)
    if not thrp then
        send_notification(target.Name .. " has no character!", "error")
        return false
    end
    local myHrp = getHRP()
    if not myHrp then
        send_notification("You have no character!", "error")
        return false
    end

    local myPos = readPos(myHrp)
    if not myPos then return false end
    S.savedPos = myPos
    S.flingTargetName = target.Name

    S.flingFrames = S.sustained and SUST_FRAMES or QUICK_FRAMES
    S.flingPhase = "fling"
    send_notification((S.sustained and "Sustained" or "Quick") .. " fling → " .. target.Name, "info")
    return true
end

local function setSpectate(enabled)
    local cam = workspace.CurrentCamera
    if not cam then return end
    if enabled then
        local targetName = S.selectedPlayer ~= "" and S.selectedPlayer or S.inputText
        local target = findPlayerByName(targetName)
        if not target then
            send_notification("Select a target to spectate!", "error")
            return
        end
        local thum = getTargetHumanoid(target)
        if not thum then
            send_notification(target.Name .. " has no humanoid!", "error")
            return
        end
        S.spectateName = target.Name
        pcall(function() cam.CameraSubject = thum end)
        S.spectating = true
        send_notification("Spectating " .. target.Name, "info")
    else
        S.spectateName = ""
        local myHum = getHumanoid()
        if myHum then pcall(function() cam.CameraSubject = myHum end) end
        S.spectating = false
        send_notification("Spectate OFF", "info")
    end
end

-- ═══════════════════════════════════════════════════
--  RENDER — Input + Drawing
-- ═══════════════════════════════════════════════════
_G.Fling4_Render = RunService.Render:Connect(function()
    pcall(function()
        local ok, keys = pcall(getpressedkeys)
        currentKeys = (ok and type(keys) == "table") and keys or {}

        local now = os.clock()
        if now - lastToggle > KEY_DELAY and isPressed(PANEL_KEY) then
            lastToggle = now
            S.visible = not S.visible
            send_notification(S.visible and "Fling GUI Shown" or "Fling GUI Hidden", "info")
        end

        -- Spam fling timer
        if S.spamActive and S.flingPhase == "idle" and now - lastSpamTime > S.spamDelay then
            lastSpamTime = now
            startFling()
        end

        -- Persistent spectate
        if S.spectating and S.spectateName ~= "" then
            local target = findPlayerByName(S.spectateName)
            if target then
                local thum = getTargetHumanoid(target)
                if thum then
                    local cam = workspace.CurrentCamera
                    if cam then pcall(function() cam.CameraSubject = thum end) end
                end
            end
        end

        if not S.visible then return end

        -- Mouse
        local mp = getmouseposition()
        local mx = mp.X or mp.x or 0
        local my = mp.Y or mp.y or 0
        local lHeld    = isleftpressed()
        local lClick   = lHeld and not prevHeld
        local lRelease = not lHeld and prevHeld
        prevHeld = lHeld

        local vp  = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
        local vpW = vp and (vp.X or vp.x or 1920) or 1920
        local vpH = vp and (vp.Y or vp.y or 1080) or 1080

        -- ── Drag ──
        local inHead = inRect(mx, my, S.panelX, S.panelY, panelW, headerH)
        if lClick and inHead then dragPhase = 1; dragOX = mx - S.panelX; dragOY = my - S.panelY end
        if dragPhase == 1 and (math.abs(mx - (S.panelX + dragOX)) > 2 or math.abs(my - (S.panelY + dragOY)) > 2) then
            dragPhase = 2
        end
        if dragPhase == 2 and lHeld then
            S.panelX = math.clamp(mx - dragOX, 0, vpW - panelW)
            S.panelY = math.clamp(my - dragOY, 0, vpH - 60)
        end
        if lRelease then dragPhase = 0 end

        -- ── Text input ──
        if S.inputFocused then
            if now - lastType > 0.08 then
                for i = 1, #currentKeys do
                    local kok, key = pcall(function() return tostring(currentKeys[i]):lower() end)
                    if kok then
                        if key == "back" or key == "backspace" then
                            if #S.inputText > 0 then
                                S.inputText = S.inputText:sub(1, -2)
                                S.selectedPlayer = ""  -- clear selection when typing
                                S.listScroll = 0
                                lastType = now
                            end; break
                        elseif key == "return" or key == "esc" or key == "escape" then
                            S.inputFocused = false; lastType = now; break
                        elseif key == "space" then
                            S.inputText = S.inputText .. " "
                            S.selectedPlayer = ""; lastType = now; break
                        elseif #key == 1 and key:match("[%a%d]") then
                            local ch = (isPressed("shift") or isPressed("leftshift")) and key:upper() or key
                            S.inputText = S.inputText .. ch
                            S.selectedPlayer = ""
                            S.listScroll = 0
                            lastType = now; break
                        end
                    end
                end
            end
        end

        -- Build player list + filter
        local allPlayers = getOtherPlayers()
        local showingAutocomplete = S.inputFocused and S.inputText ~= ""
        local displayList = showingAutocomplete and filterPlayers(allPlayers, S.inputText) or (S.showList and allPlayers or {})
        local listCount = #displayList
        local visibleCount = math.min(listCount, MAX_VISIBLE_PLAYERS)
        local listH = visibleCount * listItemH
        local hasScrollUp = S.listScroll > 0
        local hasScrollDown = S.listScroll + MAX_VISIBLE_PLAYERS < listCount
        local scrollBtnH = 18
        local totalListH = listH + (hasScrollUp and scrollBtnH or 0) + (hasScrollDown and scrollBtnH or 0)

        -- ── Calculate dynamic panel height ──
        local baseH = headerH + padY + 14 + inputH + gap  -- header → input
        local afterInputH = 0
        if listCount > 0 then
            afterInputH = totalListH + gap
        end
        -- buttons: fling + spam + interval + sustained + spectate + footer
        local btnsH = btnH + gap + btnH + gap + btnH + gap + checkH + gap + btnH + padY + 14 + 6
        local panelH = baseH + afterInputH + btnsH

        -- ═══════════════════════════════
        --  DRAW PANEL
        -- ═══════════════════════════════
        local px, py = S.panelX, S.panelY
        cursorBlink = (cursorBlink + 1) % 60

        -- Shadow + BG
        DI.FilledRectangle(Vector2.new(px + 4, py + 4), Vector2.new(panelW, panelH), Color3.fromRGB(0,0,0), 0.35)
        DI.FilledRectangle(Vector2.new(px, py), Vector2.new(panelW, panelH), COL_BG, 0.94)
        DI.Rectangle(Vector2.new(px, py), Vector2.new(panelW, panelH), COL_BORDER, 0.6, 1)

        -- Header
        DI.FilledRectangle(Vector2.new(px, py), Vector2.new(panelW, headerH), COL_HEADER, 0.95)
        DI.FilledRectangle(Vector2.new(px, py + headerH - 2), Vector2.new(panelW, 2), COL_ACCENT, 0.9)
        DI.OutlinedText(Vector2.new(px + panelW / 2, py + 9), 16, COL_TEXT, 1, "Player Fling v4", true, "Proggy")

        local cy = py + headerH + padY

        -- Label row: "Target:" + [Players ▼] button
        local listBtnW = 70
        DI.Text(Vector2.new(px + padX, cy + 1), 12, COL_DIM, 0.8, "Target:", false, "Tamzen")
        -- Show selected player name
        if S.selectedPlayer ~= "" then
            DI.Text(Vector2.new(px + padX + 50, cy + 1), 12, COL_GREEN, 0.9, S.selectedPlayer, false, "Tamzen")
        end
        -- [Players ▼] toggle button
        local lbX = px + panelW - padX - listBtnW
        local lbHov = inRect(mx, my, lbX, cy - 2, listBtnW, 16)
        DI.FilledRectangle(Vector2.new(lbX, cy - 2), Vector2.new(listBtnW, 16), S.showList and COL_BLUE or COL_BTN, 0.8)
        if lbHov then DI.FilledRectangle(Vector2.new(lbX, cy - 2), Vector2.new(listBtnW, 16), COL_HOVW, 0.08) end
        DI.Rectangle(Vector2.new(lbX, cy - 2), Vector2.new(listBtnW, 16), COL_BORDER, 0.5, 1)
        local listLabel = S.showList and "Players ^" or "Players v"
        DI.Text(Vector2.new(lbX + listBtnW / 2, cy), 11, COL_TEXT, 0.9, listLabel, true, "Tamzen")
        if lClick and lbHov and dragPhase == 0 then
            S.showList = not S.showList
            S.listScroll = 0
        end
        cy += 14

        -- ── Input field ──
        local inputX = px + padX
        local inputW = panelW - padX * 2
        DI.FilledRectangle(Vector2.new(inputX, cy), Vector2.new(inputW, inputH), COL_INPUT_BG, 0.95)
        DI.Rectangle(Vector2.new(inputX, cy), Vector2.new(inputW, inputH), S.inputFocused and COL_INPUT_AC or COL_INPUT_BD, 0.8, 1)
        local dt = S.inputText .. ((S.inputFocused and cursorBlink < 35) and "|" or "")
        if dt == "" then
            DI.Text(Vector2.new(inputX + 8, cy + 8), 13, COL_DIM, 0.4, "Type to search...", false, "Proggy")
        else
            DI.Text(Vector2.new(inputX + 8, cy + 8), 13, COL_TEXT, 0.95, dt, false, "Proggy")
        end
        if lClick and inRect(mx, my, inputX, cy, inputW, inputH) and dragPhase == 0 then
            S.inputFocused = true
        end
        -- Click outside input & list = unfocus
        if lClick and S.inputFocused then
            local listAreaBottom = cy + inputH + (listCount > 0 and (totalListH + gap) or 0)
            if not inRect(mx, my, inputX, cy, inputW, listAreaBottom - cy) then
                S.inputFocused = false
            end
        end
        cy += inputH

        -- ── Player List / Autocomplete dropdown ──
        if listCount > 0 then
            cy += 2 -- tiny gap
            local listX = px + padX
            local listW = panelW - padX * 2

            -- Scroll up button
            if hasScrollUp then
                local suHov = inRect(mx, my, listX, cy, listW, scrollBtnH)
                DI.FilledRectangle(Vector2.new(listX, cy), Vector2.new(listW, scrollBtnH), COL_BTN, 0.85)
                if suHov then DI.FilledRectangle(Vector2.new(listX, cy), Vector2.new(listW, scrollBtnH), COL_HOVW, 0.08) end
                DI.OutlinedText(Vector2.new(listX + listW / 2, cy + 3), 12, COL_DIM, 0.9, "-- scroll up --", true, "Tamzen")
                if lClick and suHov and dragPhase == 0 then
                    S.listScroll = math.max(0, S.listScroll - 1)
                end
                cy += scrollBtnH
            end

            -- Player items
            for i = 1, visibleCount do
                local idx = i + S.listScroll
                local entry = displayList[idx]
                if entry then
                    local itemY = cy
                    local isSelected = entry.name == S.selectedPlayer
                    local itemHov = inRect(mx, my, listX, itemY, listW, listItemH)

                    -- Background
                    local bgCol = isSelected and COL_LIST_SEL or COL_LIST_BG
                    DI.FilledRectangle(Vector2.new(listX, itemY), Vector2.new(listW, listItemH), bgCol, 0.92)
                    if itemHov then
                        DI.FilledRectangle(Vector2.new(listX, itemY), Vector2.new(listW, listItemH), COL_LIST_HOV, 0.5)
                    end
                    -- Border
                    DI.Line(Vector2.new(listX, itemY + listItemH), Vector2.new(listX + listW, itemY + listItemH), COL_BORDER, 0.3, 1, 1)

                    -- Name + DisplayName
                    local label = entry.name
                    if entry.display ~= entry.name then
                        label = entry.display .. " (" .. entry.name .. ")"
                    end
                    -- Truncate if too long
                    if #label > 30 then label = label:sub(1, 28) .. ".." end

                    local nameCol = isSelected and COL_GREEN or COL_TEXT
                    DI.Text(Vector2.new(listX + 8, itemY + 5), 12, nameCol, 0.95, label, false, "Tamzen")

                    -- Click to select
                    if lClick and itemHov and dragPhase == 0 then
                        selectPlayer(entry.name)
                    end

                    cy += listItemH
                end
            end

            -- Scroll down button
            if hasScrollDown then
                local sdHov = inRect(mx, my, listX, cy, listW, scrollBtnH)
                DI.FilledRectangle(Vector2.new(listX, cy), Vector2.new(listW, scrollBtnH), COL_BTN, 0.85)
                if sdHov then DI.FilledRectangle(Vector2.new(listX, cy), Vector2.new(listW, scrollBtnH), COL_HOVW, 0.08) end
                DI.OutlinedText(Vector2.new(listX + listW / 2, cy + 3), 12, COL_DIM, 0.9, "-- scroll down --", true, "Tamzen")
                if lClick and sdHov and dragPhase == 0 then
                    S.listScroll = math.min(listCount - MAX_VISIBLE_PLAYERS, S.listScroll + 1)
                end
                cy += scrollBtnH
            end

            cy += gap - 2
        else
            cy += gap
        end

        -- ── Helper: draw button ──
        local btnW = panelW - padX * 2
        local function drawBtn(bx, by, bw, bh, label, baseCol, hovered, enabled)
            local col = enabled == false and Color3.fromRGB(60, 60, 75) or baseCol
            DI.FilledRectangle(Vector2.new(bx, by), Vector2.new(bw, bh), col, 0.9)
            if hovered and enabled ~= false then
                DI.FilledRectangle(Vector2.new(bx, by), Vector2.new(bw, bh), COL_HOVW, 0.08)
            end
            DI.Rectangle(Vector2.new(bx, by), Vector2.new(bw, bh), col, 0.5, 1)
            DI.OutlinedText(Vector2.new(bx + bw / 2, by + 9), 14, COL_TEXT, 1, label, true, "Proggy")
        end

        -- ── FLING button ──
        local busy = S.flingPhase ~= "idle"
        local flingHov = inRect(mx, my, px + padX, cy, btnW, btnH)
        local flingLabel = "Fling"
        if S.flingPhase == "fling" then
            flingLabel = (S.sustained and "Sustained" or "Quick") .. "... (" .. S.flingFrames .. ")"
        elseif S.flingPhase == "return" then
            flingLabel = "Returning... (" .. S.flingFrames .. ")"
        end
        drawBtn(px + padX, cy, btnW, btnH, flingLabel, COL_ACCENT, flingHov, not busy)
        if lClick and flingHov and not busy and dragPhase == 0 then startFling() end
        cy += btnH + gap

        -- ── SPAM FLING toggle ──
        local spamHov = inRect(mx, my, px + padX, cy, btnW, btnH)
        local spamCol = S.spamActive and COL_GREEN or COL_BTN
        DI.FilledRectangle(Vector2.new(px + padX, cy), Vector2.new(btnW, btnH), spamCol, 0.9)
        if spamHov then DI.FilledRectangle(Vector2.new(px + padX, cy), Vector2.new(btnW, btnH), COL_HOVW, 0.06) end
        DI.Rectangle(Vector2.new(px + padX, cy), Vector2.new(btnW, btnH), S.spamActive and COL_GREEN or COL_BORDER, 0.5, 1)
        local dotCol = S.spamActive and Color3.fromRGB(100, 255, 140) or Color3.fromRGB(100, 100, 120)
        DI.FilledCircle(Vector2.new(px + padX + 14, cy + btnH / 2), 4, dotCol, 1)
        DI.OutlinedText(Vector2.new(px + padX + 26, cy + 9), 13, COL_TEXT, 1, S.spamActive and "Spam Fling: ON" or "Spam Fling: OFF", false, "Proggy")
        if lClick and spamHov and dragPhase == 0 then
            S.spamActive = not S.spamActive; lastSpamTime = now
            send_notification(S.spamActive and "Spam Fling ON" or "Spam Fling OFF", S.spamActive and "success" or "info")
        end
        cy += btnH + gap

        -- ── Interval row ──
        local minX = px + padX
        local plsX = px + panelW - padX - smallBtnW
        local lblW = panelW - padX * 2 - smallBtnW * 2 - gap * 2
        local lblX = minX + smallBtnW + gap

        local minHov = inRect(mx, my, minX, cy, smallBtnW, btnH)
        DI.FilledRectangle(Vector2.new(minX, cy), Vector2.new(smallBtnW, btnH), COL_MINUS, 0.85)
        if minHov then DI.FilledRectangle(Vector2.new(minX, cy), Vector2.new(smallBtnW, btnH), COL_HOVW, 0.1) end
        DI.Rectangle(Vector2.new(minX, cy), Vector2.new(smallBtnW, btnH), COL_MINUS, 0.5, 1)
        DI.OutlinedText(Vector2.new(minX + smallBtnW / 2, cy + 9), 16, COL_TEXT, 1, "-", true, "Proggy")
        if lClick and minHov and dragPhase == 0 then
            S.spamDelay = math.max(0.5, S.spamDelay - 0.5)
            send_notification(string.format("Interval: %.1fs", S.spamDelay), "info")
        end

        DI.FilledRectangle(Vector2.new(lblX, cy), Vector2.new(lblW, btnH), COL_INPUT_BG, 0.9)
        DI.Rectangle(Vector2.new(lblX, cy), Vector2.new(lblW, btnH), COL_BORDER, 0.4, 1)
        DI.OutlinedText(Vector2.new(lblX + lblW / 2, cy + 9), 13, COL_DIM, 1, string.format("Interval: %.1fs", S.spamDelay), true, "Proggy")

        local plsHov = inRect(mx, my, plsX, cy, smallBtnW, btnH)
        DI.FilledRectangle(Vector2.new(plsX, cy), Vector2.new(smallBtnW, btnH), COL_PLUS, 0.85)
        if plsHov then DI.FilledRectangle(Vector2.new(plsX, cy), Vector2.new(smallBtnW, btnH), COL_HOVW, 0.1) end
        DI.Rectangle(Vector2.new(plsX, cy), Vector2.new(smallBtnW, btnH), COL_PLUS, 0.5, 1)
        DI.OutlinedText(Vector2.new(plsX + smallBtnW / 2, cy + 9), 16, COL_TEXT, 1, "+", true, "Proggy")
        if lClick and plsHov and dragPhase == 0 then
            S.spamDelay = math.min(30, S.spamDelay + 0.5)
            send_notification(string.format("Interval: %.1fs", S.spamDelay), "info")
        end
        cy += btnH + gap

        -- ── Sustained checkbox ──
        local chkBx = px + padX
        local chkSz = 18
        local chkY  = cy + (checkH - chkSz) / 2
        local chkHov = inRect(mx, my, chkBx, cy, panelW - padX * 2, checkH)
        DI.FilledRectangle(Vector2.new(chkBx, chkY), Vector2.new(chkSz, chkSz), S.sustained and COL_CHECK_ON or COL_CHECK_OFF, 0.9)
        DI.Rectangle(Vector2.new(chkBx, chkY), Vector2.new(chkSz, chkSz), S.sustained and COL_CHECK_ON or COL_BORDER, 0.7, 1)
        if S.sustained then
            DI.Line(Vector2.new(chkBx+4, chkY+10), Vector2.new(chkBx+8, chkY+14), COL_TEXT, 1, 1, 2)
            DI.Line(Vector2.new(chkBx+8, chkY+14), Vector2.new(chkBx+15, chkY+4), COL_TEXT, 1, 1, 2)
        end
        DI.OutlinedText(Vector2.new(chkBx + chkSz + 8, cy + 3), 13, S.sustained and COL_YELLOW or COL_DIM, 1, S.sustained and "Sustained (ON)" or "Sustained (OFF)", false, "Proggy")
        DI.Text(Vector2.new(chkBx + chkSz + 8, cy + 16), 10, COL_DIM, 0.5, "For fall-damage games", false, "Tamzen")
        if chkHov then DI.FilledRectangle(Vector2.new(chkBx, cy), Vector2.new(panelW - padX * 2, checkH), COL_HOVW, 0.04) end
        if lClick and chkHov and dragPhase == 0 then
            S.sustained = not S.sustained
            send_notification(S.sustained and "Sustained ON" or "Sustained OFF", S.sustained and "success" or "info")
        end
        cy += checkH + gap

        -- ── Spectate button ──
        local specHov = inRect(mx, my, px + padX, cy, btnW, btnH)
        local specCol = S.spectating and COL_CYAN or COL_BLUE
        local specLabel = S.spectating and "Stop Spectating" or "Spectate Target"
        drawBtn(px + padX, cy, btnW, btnH, specLabel, specCol, specHov, true)
        if lClick and specHov and dragPhase == 0 then
            setSpectate(not S.spectating)
        end
        cy += btnH + padY

        -- Footer
        DI.Text(Vector2.new(px + panelW / 2, cy), 11, COL_DIM, 0.45, "F2 to toggle panel", true, "Tamzen")
    end)
end)

-- ═══════════════════════════════════════════════════
--  POSTLOCAL — Fling Physics
-- ═══════════════════════════════════════════════════
_G.Fling4_Post = RunService.PostLocal:Connect(function()
    pcall(function()
        if S.flingPhase == "idle" then return end

        local myHrp = getHRP()
        if not myHrp then
            S.flingPhase = "idle"; S.flingFrames = 0
            return
        end

        -- ── FLING ──
        if S.flingPhase == "fling" then
            local target = findPlayerByName(S.flingTargetName)
            local thrp = target and getTargetHRP(target)

            if thrp then
                local vel = S.sustained and SUST_VEL or QUICK_VEL

                local tCF = nil
                pcall(function() tCF = thrp.CFrame end)

                if tCF then
                    local tPos = tCF.Position
                    local tx = safe(tPos.X or tPos.x, 0)
                    local ty = safe(tPos.Y or tPos.y, 0)
                    local tz = safe(tPos.Z or tPos.z, 0)

                    -- Velocity + RotVelocity
                    pcall(function()
                        myHrp.Velocity = Vector3.new(
                            math.random(-vel, vel),
                            math.random(vel / 3, vel),
                            math.random(-vel, vel)
                        )
                    end)
                    pcall(function()
                        myHrp.RotVelocity = Vector3.new(
                            math.random(-600, 600),
                            math.random(-600, 600),
                            math.random(-600, 600)
                        )
                    end)

                    -- CFrame LAST — position sticks, collision generates force
                    pcall(function()
                        myHrp.CFrame = CFrame.new(tx, ty, tz)
                    end)
                end
            end

            S.flingFrames -= 1
            if S.flingFrames <= 0 then
                S.flingPhase = "return"
                S.flingFrames = RETURN_FRAMES
            end
            return
        end

        -- ── RETURN ──
        if S.flingPhase == "return" then
            if S.savedPos then
                pcall(function()
                    myHrp.CFrame      = CFrame.new(S.savedPos.x, S.savedPos.y, S.savedPos.z)
                    myHrp.Velocity    = Vector3.new(0, 0, 0)
                    myHrp.RotVelocity = Vector3.new(0, 0, 0)
                end)
            end
            S.flingFrames -= 1
            if S.flingFrames <= 0 then
                S.flingPhase = "idle"
                S.savedPos = nil
            end
        end
    end)
end)

send_notification("Fling GUI v4 Loaded — F2", "success")
