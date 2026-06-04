-- tiling.lua: Per-screen window tiling layouts

local M = {}

local GRID_W = 12
local GRID_H = 12

local floatingApps = {
    'Finder', 'System Preferences', 'System Settings',
    'Activity Monitor', 'Calculator', 'Hosting AU'
}

-- Per-screen window order cache (non-deck layouts): screenUUID -> { windowId, ... }
-- The first entry is the primary window.
local windowOrder = {}

-- Per-screen state for the deck layout:
--   screenUUID -> { order = { winId, ... }, primaryId = winId }
-- `order` is the stable card sequence; `primaryId` is the card currently facing up.
local deckState = {}

-- Windows currently excluded from tiling (fullscreened via hyper+f):
--   winId -> { frame = pixelFrame, tileScreenId = uuid|nil, tileIndex = n|nil }
local fullscreenState = {}

-- Tracks which screens are currently in tiling mode.
local tiledScreens = {}

-- Window filtering ------------------------------------------------------------

local function isFloating(win)
    if fullscreenState[win:id()] then return true end
    local app = win:application()
    if not app then return true end
    local name = app:name()
    for _, floatName in ipairs(floatingApps) do
        if floatName == name then return true end
    end
    return false
end

-- Returns all tileable windows on screen in focus order, with no caching.
local function filterWindows(screen)
    local screenId = screen:getUUID()
    local result   = {}
    for _, win in ipairs(hs.window.orderedWindows()) do
        if win:screen()
            and win:screen():getUUID() == screenId
            and win:isStandard()
            and not win:isMinimized()
            and not isFloating(win)
        then
            table.insert(result, win)
        end
    end
    return result
end

-- Returns tileable windows on screen, preserving the windowOrder cache so
-- the primary slot survives retiling and new windows append at the end.
local function getTileableWindows(screen)
    local screenId = screen:getUUID()
    local eligible = filterWindows(screen)

    local order = windowOrder[screenId]
    if order and #order > 0 then
        local indexed = {}
        for _, win in ipairs(eligible) do indexed[win:id()] = win end

        local ordered = {}
        local used    = {}
        for _, id in ipairs(order) do
            if indexed[id] then
                table.insert(ordered, indexed[id])
                used[id] = true
            end
        end
        for _, win in ipairs(eligible) do
            if not used[win:id()] then table.insert(ordered, win) end
        end
        eligible = ordered
    end

    local ids = {}
    for _, win in ipairs(eligible) do table.insert(ids, win:id()) end
    windowOrder[screenId] = ids

    return eligible
end

-- Non-deck layout functions ---------------------------------------------------

local function layoutColumns(windows, screen, _config)
    local n = #windows
    if n == 0 then return end
    local colW = math.floor(GRID_W / n)
    for i, win in ipairs(windows) do
        local x = (i - 1) * colW
        local w = (i == n) and (GRID_W - x) or colW
        hs.grid.set(win, string.format('%d,0 %dx%d', x, w, GRID_H), screen)
    end
end

local function layoutRows(windows, screen, _config)
    local n = #windows
    if n == 0 then return end
    local rowH = math.floor(GRID_H / n)
    for i, win in ipairs(windows) do
        local y = (i - 1) * rowH
        local h = (i == n) and (GRID_H - y) or rowH
        hs.grid.set(win, string.format('0,%d %dx%d', y, GRID_W, h), screen)
    end
end

-- First window is primary (left column); the rest stack on the right.
local function layoutPrimaryStack(windows, screen, config)
    local n = #windows
    if n == 0 then return end

    if n == 1 then
        hs.grid.set(windows[1], string.format('0,0 %dx%d', GRID_W, GRID_H), screen)
        return
    end

    local primaryRatio = (config and config.primaryRatio) or 0.6
    local primaryCols  = math.floor(GRID_W * primaryRatio)
    local restCols     = GRID_W - primaryCols

    hs.grid.set(windows[1], string.format('0,0 %dx%d', primaryCols, GRID_H), screen)

    local restCount = n - 1
    local rowH      = math.floor(GRID_H / restCount)
    for i = 2, n do
        local y = (i - 2) * rowH
        local h = (i == n) and (GRID_H - y) or rowH
        hs.grid.set(windows[i], string.format('%d,%d %dx%d', primaryCols, y, restCols, h), screen)
    end
end

-- First window is primary (top row); the rest spread across the bottom.
local function layoutPrimaryWide(windows, screen, config)
    local n = #windows
    if n == 0 then return end

    if n == 1 then
        hs.grid.set(windows[1], string.format('0,0 %dx%d', GRID_W, GRID_H), screen)
        return
    end

    local primaryRatio = (config and config.primaryRatio) or 0.55
    local primaryRows  = math.floor(GRID_H * primaryRatio)
    local restRows     = GRID_H - primaryRows

    hs.grid.set(windows[1], string.format('0,0 %dx%d', GRID_W, primaryRows), screen)

    local restCount = n - 1
    local colW      = math.floor(GRID_W / restCount)
    for i = 2, n do
        local x = (i - 2) * colW
        local w = (i == n) and (GRID_W - x) or colW
        hs.grid.set(windows[i], string.format('%d,%d %dx%d', x, primaryRows, w, restRows), screen)
    end
end

local layouts = {
    columns       = layoutColumns,
    rows          = layoutRows,
    primary_stack = layoutPrimaryStack,
    primary_wide  = layoutPrimaryWide,
}

-- Deck layout -----------------------------------------------------------------

-- Reconciles deckState for a screen against currently visible windows.
-- Adds new windows at the end, removes closed ones, preserves primaryId.
-- Returns windows in deck order: { primary, peek, hidden... }
local function reconcileDeck(screen, eligible)
    local screenId = screen:getUUID()
    local state    = deckState[screenId]
    local byId     = {}
    for _, win in ipairs(eligible) do byId[win:id()] = win end

    if not state or #state.order == 0 then
        -- First tile: seed order from current focus order.
        local order = {}
        for _, win in ipairs(eligible) do table.insert(order, win:id()) end
        state = { order = order, primaryId = order[1] }
        deckState[screenId] = state
    else
        -- Remove windows that have since closed.
        local newOrder = {}
        for _, id in ipairs(state.order) do
            if byId[id] then table.insert(newOrder, id) end
        end
        -- Append any windows that appeared after the last tile.
        local inOrder = {}
        for _, id in ipairs(newOrder) do inOrder[id] = true end
        for _, win in ipairs(eligible) do
            if not inOrder[win:id()] then table.insert(newOrder, win:id()) end
        end
        state.order = newOrder
        -- Recover gracefully if the primary window was closed.
        if not byId[state.primaryId] then
            state.primaryId = state.order[1]
        end
    end

    if not state.primaryId or #state.order == 0 then return {} end

    -- Rotate order so primary is first, then peek, then hidden.
    local primaryIdx = nil
    for i, id in ipairs(state.order) do
        if id == state.primaryId then primaryIdx = i; break end
    end

    local n       = #state.order
    local rotated = {}
    for i = 0, n - 1 do
        local idx = ((primaryIdx - 1 + i) % n) + 1
        local win = byId[state.order[idx]]
        if win then table.insert(rotated, win) end
    end
    return rotated
end

-- Positions windows in the card-stack layout:
--   windows[1] = primary (full height, main portion of screen)
--   windows[2] = peek    (narrow strip on the right, raised to front)
--   windows[3+] = hidden (stacked at peek position behind peek)
--
-- Z-order note: sendToBack() is intentionally avoided — it loops through all
-- overlapping windows calling focus() with 80 ms delays, causing visible
-- flicker. Instead, raise() on the peek + focus() on primary (called by the
-- deckNext/deckPrev callers) achieves the correct order with no side-effects.
local function layoutDeck(windows, screen, config)
    local n     = #windows
    if n == 0 then return end

    local peekW = (config and config.peekWidth) or 2
    local mainW = GRID_W - peekW

    hs.grid.set(windows[1], string.format('0,0 %dx%d', mainW, GRID_H), screen)

    if n == 1 then return end

    local peekStr = string.format('%d,0 %dx%d', mainW, peekW, GRID_H)

    for i = 3, n do
        hs.grid.set(windows[i], peekStr, screen)
    end

    -- Place peek last and raise it above the hidden stack.
    hs.grid.set(windows[2], peekStr, screen)
    windows[2]:raise()
end

-- Retile helpers for resize ---------------------------------------------------

-- Distribute secondary windows in the right column of a primary_stack layout.
local function placeRest_stack(primaryCols, rest, screen)
    local restCols = GRID_W - primaryCols
    if restCols <= 0 or #rest == 0 then return end
    local rowH = math.floor(GRID_H / #rest)
    for i, win in ipairs(rest) do
        local y = (i - 1) * rowH
        local h = (i == #rest) and (GRID_H - y) or rowH
        hs.grid.set(win, string.format('%d,%d %dx%d', primaryCols, y, restCols, h), screen)
    end
end

-- Distribute secondary windows in the bottom row of a primary_wide layout.
local function placeRest_wide(primaryRows, rest, screen)
    local restRows = GRID_H - primaryRows
    if restRows <= 0 or #rest == 0 then return end
    local colW = math.floor(GRID_W / #rest)
    for i, win in ipairs(rest) do
        local x = (i - 1) * colW
        local w = (i == #rest) and (GRID_W - x) or colW
        hs.grid.set(win, string.format('%d,%d %dx%d', x, primaryRows, w, restRows), screen)
    end
end

-- Swap helper -----------------------------------------------------------------

-- Returns true + screenId + index when win is in a non-deck tiled screen.
-- Reconciles windowOrder first so windows that arrived after the last explicit
-- tile (moveToScreen, natural open, etc.) are recognised correctly.
local function isWindowInTile(win)
    local screen = win:screen()
    if not screen then return false, nil, nil end
    local screenId = screen:getUUID()
    if not tiledScreens[screenId] then return false, nil, nil end
    local config = M.screenLayouts[screenId]
    if config and config.layout == 'deck' then return false, nil, nil end
    -- Refresh order before searching so newly-arrived windows are included.
    getTileableWindows(screen)
    local order = windowOrder[screenId]
    if not order then return false, nil, nil end
    for i, id in ipairs(order) do
        if id == win:id() then return true, screenId, i end
    end
    return false, nil, nil
end

-- Finds the nearest tileable window in the given direction from win, using
-- pixel frame centres. A candidate qualifies when its centre lies on the
-- correct side AND the target axis dominates (|dy|>|dx| for up/down,
-- |dx|>|dy| for left/right), preventing diagonal mis-matches.
local function nearestInDirection(win, direction, windows)
    local center = win:frame().center
    local best, bestDist = nil, math.huge

    for _, w in ipairs(windows) do
        if w:id() ~= win:id() then
            local wc  = w:frame().center
            local dx  = wc.x - center.x
            local dy  = wc.y - center.y
            local adx = math.abs(dx)
            local ady = math.abs(dy)

            local ok = false
            if direction == 'left'  and dx < 0 and adx > ady then ok = true end
            if direction == 'right' and dx > 0 and adx > ady then ok = true end
            if direction == 'up'    and dy < 0 and ady > adx then ok = true end
            if direction == 'down'  and dy > 0 and ady > adx then ok = true end

            if ok then
                local dist = dx * dx + dy * dy
                if dist < bestDist then bestDist = dist; best = w end
            end
        end
    end
    return best
end

-- Public API ------------------------------------------------------------------

-- Set per-screen layout config in init.lua:
--   tiling.screenLayouts[screenUUID] = { layout = 'primary_stack', primaryRatio = 0.6 }
M.screenLayouts = {}

function M.isScreenTiled(screen)
    return tiledScreens[screen:getUUID()] == true
end

-- True when the screen is actively tiled AND configured as a deck layout.
function M.isDeckScreen(screen)
    local screenId = screen:getUUID()
    local config   = M.screenLayouts[screenId]
    return tiledScreens[screenId] == true
        and config ~= nil
        and config.layout == 'deck'
end

-- Marks screen as no longer tiled without moving any windows.
function M.untileScreen(screen)
    tiledScreens[screen:getUUID()] = nil
end

-- Returns true when the window is currently fullscreened via fullscreenToggle.
function M.isFullscreened(win)
    return fullscreenState[win:id()] ~= nil
end

-- Toggles fullscreen for a window, integrating with the tiling state:
--   ON  – snapshots all tile frames, removes win from tile, retiles remaining,
--          then maximises. The snapshot means restore will put every window back
--          at its manually-adjusted size, not the default layout formula size.
--   OFF – re-inserts win into the tile order and restores all saved frames
--          verbatim (no retile recalculation). Falls back to the single saved
--          frame when the window was not part of a tile.
function M.fullscreenToggle(win)
    local winId = win:id()
    if fullscreenState[winId] then
        -- Toggle OFF: restore previous state.
        local state = fullscreenState[winId]
        fullscreenState[winId] = nil
        if state.tileScreenId and tiledScreens[state.tileScreenId] then
            -- Re-insert into order at the original position.
            local order = windowOrder[state.tileScreenId] or {}
            local idx   = math.min(state.tileIndex, #order + 1)
            table.insert(order, idx, winId)
            windowOrder[state.tileScreenId] = order
            -- Restore every window's frame from the pre-fullscreen snapshot so
            -- manually-resized tile proportions are preserved.
            if state.tileFrames then
                local byId = {}
                for _, w in ipairs(hs.window.allWindows()) do byId[w:id()] = w end
                for id, frame in pairs(state.tileFrames) do
                    local w = byId[id]
                    if w then w:setFrame(frame) end
                end
            else
                win:setFrame(state.frame)
            end
        else
            win:setFrame(state.frame)
        end
    else
        -- Toggle ON: snapshot tile frames BEFORE removing the window.
        local inTile, tileScreenId, tileIndex = isWindowInTile(win)
        local tileFrames = nil
        if inTile then
            local scr = hs.screen.find(tileScreenId)
            if scr then
                tileFrames = {}
                -- filterWindows is called before fullscreenState is written, so
                -- win is still visible and its frame is included in the snapshot.
                for _, w in ipairs(filterWindows(scr)) do
                    tileFrames[w:id()] = w:frame()
                end
            end
        end
        fullscreenState[winId] = {
            frame        = win:frame(),
            tileScreenId = tileScreenId,
            tileIndex    = tileIndex,
            tileFrames   = tileFrames,
        }
        if inTile then
            local order = windowOrder[tileScreenId]
            for i = #order, 1, -1 do
                if order[i] == winId then table.remove(order, i); break end
            end
            local scr = hs.screen.find(tileScreenId)
            if scr then M.tileScreen(scr) end
        end
        hs.grid.maximizeWindow(win)
    end
end

-- Swaps the focused window with its nearest tiled neighbour in direction
-- ('up'|'down'|'left'|'right'). Returns true when a swap happened so the
-- caller knows not to fall back to the normal grid push.
-- No-op (returns false) when the screen is not tiled or is a deck screen.
--
-- Uses getTileableWindows (not filterWindows) so that windowOrder is always
-- reconciled with current reality before index lookups: windows that arrived
-- on the screen after the last explicit tile (via moveToScreen, natural open,
-- etc.) are appended to the order and can participate in swaps immediately,
-- without requiring the user to retile first.
--
-- Frames are exchanged directly (no retile recalculation) so any manually-
-- adjusted tile proportions survive the swap.
function M.swapWithAdjacent(win, direction)
    local screen = win:screen()
    if not M.isScreenTiled(screen) then return false end
    if M.isDeckScreen(screen)      then return false end

    local screenId = screen:getUUID()
    -- Refresh windowOrder to pick up any windows that appeared since the last
    -- tile, and to evict IDs of windows that have since closed or moved away.
    local windows  = getTileableWindows(screen)
    local target   = nearestInDirection(win, direction, windows)
    if not target then return false end

    local order = windowOrder[screenId]
    if not order then return false end

    local idxA, idxB = nil, nil
    for i, id in ipairs(order) do
        if id == win:id()    then idxA = i end
        if id == target:id() then idxB = i end
    end

    if not idxA or not idxB then return false end

    -- Update logical order (primary slot etc.) then swap pixel frames directly.
    order[idxA], order[idxB] = order[idxB], order[idxA]
    local frameA = win:frame()
    local frameB = target:frame()
    win:setFrame(frameB)
    target:setFrame(frameA)
    win:focus()
    return true
end

function M.tileScreen(screen)
    local screenId   = screen:getUUID()
    local config     = M.screenLayouts[screenId]
    local layoutName = (config and config.layout) or 'columns'

    tiledScreens[screenId] = true

    if layoutName == 'deck' then
        local eligible = filterWindows(screen)
        if #eligible == 0 then return end
        local ordered = reconcileDeck(screen, eligible)
        layoutDeck(ordered, screen, config)
        return
    end

    local layoutFn = layouts[layoutName]
    if not layoutFn then
        hs.alert.show('Unknown tiling layout: ' .. tostring(layoutName))
        return
    end

    local windows = getTileableWindows(screen)
    if #windows == 0 then return end
    layoutFn(windows, screen, config)
end

function M.tileAll()
    for _, screen in ipairs(hs.screen.allScreens()) do
        M.tileScreen(screen)
    end
end

-- In non-deck mode: moves the window to the primary slot (front of order).
--   Slot frames rotate with the reorder so manually-adjusted tile proportions
--   are preserved: the promoted window takes slot 1's frame, and each window
--   between the old position and slot 1 shifts one slot downward.
-- In deck mode: swaps the focused window into the current cursor position,
--   making it the card facing up without shifting the deck cursor.
function M.promoteToPrimary(win)
    local screen     = win:screen()
    local screenId   = screen:getUUID()
    local config     = M.screenLayouts[screenId]
    local layoutName = (config and config.layout) or 'columns'

    if layoutName == 'deck' then
        local state = deckState[screenId]
        if not state then M.tileScreen(screen); return end

        local primaryIdx, winIdx = nil, nil
        for i, id in ipairs(state.order) do
            if id == state.primaryId then primaryIdx = i end
            if id == win:id()        then winIdx     = i end
        end
        if winIdx and primaryIdx and winIdx ~= primaryIdx then
            state.order[primaryIdx], state.order[winIdx] =
                state.order[winIdx], state.order[primaryIdx]
        end
        state.primaryId = win:id()
        M.tileScreen(screen)
        win:focus()
        return
    end

    -- Capture current slot frames before reordering.
    local currentWindows = getTileableWindows(screen)
    local winId          = win:id()

    local slotFrames = {}
    for i, w in ipairs(currentWindows) do
        slotFrames[i] = w:frame()
    end

    -- Move win to position 1; everything else follows in original order.
    local newOrder = { winId }
    for _, id in ipairs(windowOrder[screenId] or {}) do
        if id ~= winId then table.insert(newOrder, id) end
    end
    windowOrder[screenId] = newOrder

    -- Apply slot frames to windows in their new positions so sizes are kept.
    local byId = {}
    for _, w in ipairs(currentWindows) do byId[w:id()] = w end
    for i, id in ipairs(newOrder) do
        local w = byId[id]
        if w and slotFrames[i] then w:setFrame(slotFrames[i]) end
    end

    win:focus()
end

-- Advance the deck cursor one step forward (wraps around).
-- No-op when deckState for the screen is not initialised.
function M.deckNext(screen)
    local screenId = screen:getUUID()
    local state    = deckState[screenId]
    if not state or #state.order == 0 then return end

    local primaryIdx = nil
    for i, id in ipairs(state.order) do
        if id == state.primaryId then primaryIdx = i; break end
    end
    if not primaryIdx then return end

    local n = #state.order
    state.primaryId = state.order[(primaryIdx % n) + 1]

    M.tileScreen(screen)

    local byId = {}
    for _, w in ipairs(hs.window.allWindows()) do byId[w:id()] = w end
    local primaryWin = byId[state.primaryId]
    if primaryWin then primaryWin:focus() end
end

-- Retreat the deck cursor one step backward (wraps around).
function M.deckPrev(screen)
    local screenId = screen:getUUID()
    local state    = deckState[screenId]
    if not state or #state.order == 0 then return end

    local primaryIdx = nil
    for i, id in ipairs(state.order) do
        if id == state.primaryId then primaryIdx = i; break end
    end
    if not primaryIdx then return end

    local n = #state.order
    state.primaryId = state.order[((primaryIdx - 2) % n) + 1]

    M.tileScreen(screen)

    local byId = {}
    for _, w in ipairs(hs.window.allWindows()) do byId[w:id()] = w end
    local primaryWin = byId[state.primaryId]
    if primaryWin then primaryWin:focus() end
end

-- Called after a manual resize to redistribute the other windows around the
-- resized one, keeping its new size intact. No-op when screen is not tiled.
-- In deck mode simply retiles (resizing primary widens/narrows the peek strip).
function M.retileAfterResize(win)
    local screen = win:screen()
    if not M.isScreenTiled(screen) then return end

    local screenId   = screen:getUUID()
    local config     = M.screenLayouts[screenId]
    local layoutName = (config and config.layout) or 'columns'

    if layoutName == 'deck' then
        M.tileScreen(screen)
        return
    end

    local windows = getTileableWindows(screen)
    if #windows <= 1 then return end

    local frame = hs.grid.get(win)
    if not frame then return end

    local primaryWin = windows[1]
    local isPrimary  = (win:id() == primaryWin:id())

    if layoutName == 'primary_stack' then
        -- Use the resized window's actual width to derive the column split.
        -- If a secondary window was resized, keep primary's existing width.
        local primaryCols
        if isPrimary then
            primaryCols = math.floor(frame.w)
        else
            local mf = hs.grid.get(primaryWin)
            primaryCols = mf and math.floor(mf.w)
                or math.floor(GRID_W * ((config and config.primaryRatio) or 0.6))
        end
        primaryCols = math.max(1, math.min(GRID_W - 1, primaryCols))

        local rest = {}
        for i = 2, #windows do table.insert(rest, windows[i]) end
        hs.grid.set(primaryWin, string.format('0,0 %dx%d', primaryCols, GRID_H), screen)
        placeRest_stack(primaryCols, rest, screen)

    elseif layoutName == 'primary_wide' then
        local primaryRows
        if isPrimary then
            primaryRows = math.floor(frame.h)
        else
            local mf = hs.grid.get(primaryWin)
            primaryRows = mf and math.floor(mf.h)
                or math.floor(GRID_H * ((config and config.primaryRatio) or 0.55))
        end
        primaryRows = math.max(1, math.min(GRID_H - 1, primaryRows))

        local rest = {}
        for i = 2, #windows do table.insert(rest, windows[i]) end
        hs.grid.set(primaryWin, string.format('0,0 %dx%d', GRID_W, primaryRows), screen)
        placeRest_wide(primaryRows, rest, screen)

    elseif layoutName == 'columns' then
        -- Keep resized window's width; redistribute neighbours in remaining space.
        local resizedX = math.floor(frame.x)
        local resizedW = math.floor(frame.w)
        hs.grid.set(win, string.format('%d,0 %dx%d', resizedX, resizedW, GRID_H), screen)

        local before, after = {}, {}
        for _, w in ipairs(windows) do
            if w:id() ~= win:id() then
                local f = hs.grid.get(w)
                if f and math.floor(f.x) < resizedX then
                    table.insert(before, w)
                else
                    table.insert(after, w)
                end
            end
        end
        if #before > 0 then
            local bW = math.floor(resizedX / #before)
            for i, w in ipairs(before) do
                local x   = (i - 1) * bW
                local bww = (i == #before) and (resizedX - x) or bW
                hs.grid.set(w, string.format('%d,0 %dx%d', x, bww, GRID_H), screen)
            end
        end
        local afterX = resizedX + resizedW
        if #after > 0 then
            local aW = math.floor((GRID_W - afterX) / #after)
            for i, w in ipairs(after) do
                local x   = afterX + (i - 1) * aW
                local aww = (i == #after) and (GRID_W - x) or aW
                hs.grid.set(w, string.format('%d,0 %dx%d', x, aww, GRID_H), screen)
            end
        end

    elseif layoutName == 'rows' then
        -- Symmetric to columns, but vertical.
        local resizedY = math.floor(frame.y)
        local resizedH = math.floor(frame.h)
        hs.grid.set(win, string.format('0,%d %dx%d', resizedY, GRID_W, resizedH), screen)

        local before, after = {}, {}
        for _, w in ipairs(windows) do
            if w:id() ~= win:id() then
                local f = hs.grid.get(w)
                if f and math.floor(f.y) < resizedY then
                    table.insert(before, w)
                else
                    table.insert(after, w)
                end
            end
        end
        if #before > 0 then
            local bH = math.floor(resizedY / #before)
            for i, w in ipairs(before) do
                local y   = (i - 1) * bH
                local bhh = (i == #before) and (resizedY - y) or bH
                hs.grid.set(w, string.format('0,%d %dx%d', y, GRID_W, bhh), screen)
            end
        end
        local afterY = resizedY + resizedH
        if #after > 0 then
            local aH = math.floor((GRID_H - afterY) / #after)
            for i, w in ipairs(after) do
                local y   = afterY + (i - 1) * aH
                local ahh = (i == #after) and (GRID_H - y) or aH
                hs.grid.set(w, string.format('0,%d %dx%d', y, GRID_W, ahh), screen)
            end
        end
    end
end

return M
