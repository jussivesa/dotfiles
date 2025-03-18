-- Imports

local MiddleClickDragScroll = hs.loadSpoon("MiddleClickDragScroll"):start()

local AutoEject = hs.loadSpoon("AutoEject"):configure{
    ejectDailyAt = "14:00"
}:start()

-- Grid and window management stuff

-- Settings
hs.window.animationDuration = 0.00

-- Keys
hyper = {'shift', 'alt'}
local gridSize = '12x12'
local verticalScreenId = '57BBF425-1226-486A-94BD-C3BE400B7933' -- LEN P27q-10 (2)
local mainScreenId = '541435B5-950D-4597-BC98-EDDE4D94E161' -- LEN P27q-10 (1)
local laptopScreenId = '37D8832A-2D66-02CA-B9F7-8F30A301B230' -- Built-in Retina Display

-- Grid
hs.grid.setMargins(hs.geometry.size(0,0))
hs.grid.setGrid(gridSize)
hs.hotkey.bind(hyper,'g',function()
  hs.grid.show()
end)

-- Move between screens
hs.hotkey.bind(hyper, 'tab', function()
	local win = hs.window.focusedWindow()
	local nextScreen = win:screen():next()
	win:moveToScreen(nextScreen)
end)

-- Flow (general)
hs.hotkey.bind(hyper, 'return', function()

    -- print all screen names
    for i, screen in ipairs(hs.screen.allScreens()) do
        print(screen:name() .. " " .. screen:getUUID())
    end

    -- Main screen
    -- We have multiple possible layouts based on active Flashspace workspace
    -- Dev workspace
    adjustWindowsOfAppInScreen(mainScreenId, 'Rider', '0,0 ' .. gridSize)
    adjustWindowsOfAppInScreen(mainScreenId, 'Firefox', '0,0 6x12')
    adjustWindowsOfAppInScreen(mainScreenId, 'Docker Desktop', '6,0 6x12')
    -- Browse workspace
    adjustWindowsOfAppInScreen(mainScreenId, 'Tidal', '0,0 4x12')
    adjustWindowsOfAppInScreen(mainScreenId, 'Arc', '4,0 8x12')
    -- Terminal workspace
    adjustWindowsOfAppInScreen(mainScreenId, 'iTerm', '0,0 ' .. gridSize)

    -- Vertical screen
    -- Top 2/3 of the screen is Slack
    adjustWindowsOfAppInScreen(verticalScreenId, 'Slack', '0,0 12x6')
    -- Bottom 1/6 of the screen is Teams
    adjustWindowsOfAppInScreen(verticalScreenId, 'Microsoft Teams', '0,6 12x3')
    -- Botton 1/6 of the screen is CotEditor
    adjustWindowsOfAppInScreen(verticalScreenId, 'CotEditor', '0,9 12x3')

    -- Laptop: all other apps to be fullscreen in here
    fullscreenWindowsOfScreen(laptopScreenId)
end)

local windowSizesCache = {}
function saveWindowSizes()
    windowSizesCache = {}
    for i, win in ipairs(hs.window:allWindows()) do
        windowSizesCache[win:id()] = win:frame()
    end
end

-- Window management
hs.hotkey.bind(hyper, 'f', function()
    local win = hs.window.focusedWindow()
    -- Save size to restore later
    saveWindowSizes()
    hs.grid.maximizeWindow(win)
end)
hs.hotkey.bind(hyper, 'c', function()
    local win = hs.window.focusedWindow()
    -- Save size to restore later
    saveWindowSizes()
    -- adjust to center of screen with reasonable size
    hs.grid.set(win, '2,2 8x8')
end)
hs.hotkey.bind(hyper, 'r', function()
    local win = hs.window.focusedWindow()
    -- Restore window size from cache
    local frame = windowSizesCache[win:id()]
    if frame then
        win:setFrame(frame)
        -- remove from cache
        windowSizesCache[win:id()] = nil
    else
        -- adjust to center of screen with reasonable size
        hs.grid.set(win, '2,2 8x8')
    end
end)

-- Mouse
function scrollUp()
	hs.mouse.setAbsolutePosition(hs.window.focusedWindow():frame().center)
	hs.eventtap.scrollWheel({0, 40}, {}, 'pixel')
end
hs.hotkey.bind(hyper, 'i', scrollUp, nil, scrollUp)

function scrollDown()
	hs.mouse.setAbsolutePosition(hs.window.focusedWindow():frame().center)
	hs.eventtap.scrollWheel({0, -40}, {}, 'pixel')
end
hs.hotkey.bind(hyper, 'u', scrollDown, nil, scrollDown)

hs.hotkey.bind(hyper, 'y', function()
	hs.eventtap.leftClick(hs.mouse.getAbsolutePosition())
end)

-- Application mappings
appMaps = {
	s = 'Slack',
}
for appKey, appName in pairs(appMaps) do
	hs.hotkey.bind(hyper, appKey, function()
		hs.application.launchOrFocus(appName)
	end)
end

function fullscreenWindowsOfScreen(screenName)
    for i, win in ipairs(hs.window:allWindows()) do
        if win:screen():name() == screenName then
            hs.grid.set(win, '0,0 ' .. gridSize, screenName)
        end
    end
end

function adjustWindowsOfAppInScreen(screenName, appName, gridSettings)
    local app = hs.application.get(appName)
	if not app then
		hs.alert.show("App not found: " .. appName)
	end

    hs.application.launchOrFocus(appName)

    local wins
    if app then
        wins = app:allWindows()
    end
    if wins then
        for i, win in ipairs(wins) do
            local screen = hs.screen.find(screenName)
            if not screen then
                hs.alert.show("Screen not found: " .. screenName)
                return
            end
            hs.grid.set(win, gridSettings, screenName)
        end
    end
end

function focusIfLaunched(appName)
	local app = hs.application.get(appName)
	if app then
		app:activate()
	end
end

-- Resize
-- local function resizeAndAdjust(delta)
--     local win = hs.window.focusedWindow()
--     if not win then return end
  
--     local screen = win:screen()
--     local screenRect = screen:frame()
--     local winRect = win:frame()
  
--     local isVertical = screenRect.w < screenRect.h
  
--     if isVertical then
--       winRect.h = winRect.h + delta
--       if winRect.h < 10 then winRect.h = 10 end -- minimal height
--       if winRect.y + winRect.h > screenRect.y + screenRect.h then
--         winRect.h = screenRect.y + screenRect.h - winRect.y
--       end
--     else
--       winRect.w = winRect.w + delta
--       if winRect.w < 10 then winRect.w = 10 end -- minimal width
--       if winRect.x + winRect.w > screenRect.x + screenRect.w then
--         winRect.w = screenRect.x + screenRect.w - winRect.x
--       end
--     end
  
--     win:setFrame(winRect)
  
--     local otherWindows = {}
--     for _, w in ipairs(hs.window.visibleWindows()) do
--       if w ~= win and w:screen() == screen then
--         table.insert(otherWindows, w)
--       end
--     end
  
--     if isVertical then
--       local remainingHeight = screenRect.h - winRect.h
--       local remainingY = winRect.y + winRect.h
  
--       local otherWindowCount = #otherWindows
--       if otherWindowCount > 0 then
--         local otherWindowHeight = remainingHeight / otherWindowCount
--         for i, w in ipairs(otherWindows) do
--           local otherRect = w:frame()
--           otherRect.y = remainingY
--           otherRect.height = otherWindowHeight
--           w:setFrame(otherRect)
--           remainingY = remainingY + otherWindowHeight
--         end
--       end
--     else
--       local remainingWidth = screenRect.w - winRect.w
--       local remainingX = winRect.x + winRect.w
  
--       local otherWindowCount = #otherWindows
--       if otherWindowCount > 0 then
--         local otherWindowWidth = remainingWidth / otherWindowCount
--         for i, w in ipairs(otherWindows) do
--           local otherRect = w:frame()
--           otherRect.x = remainingX
--           otherRect.width = otherWindowWidth
--           w:setFrame(otherRect)
--           remainingX = remainingX + otherWindowWidth
--         end
--       end
--     end
--   end
  
--   hs.hotkey.bind(hyper, "h", function()
--     resizeAndAdjust(50)
--   end)
  
--   hs.hotkey.bind(hyper, "l", function()
--     resizeAndAdjust(-50)
--   end)
