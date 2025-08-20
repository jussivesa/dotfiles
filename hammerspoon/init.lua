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
hyperCtrl = {'shift', 'alt', 'ctrl'}
hyperCtrlCmd = {'shift', 'alt', 'ctrl', 'cmd'}

-- Grid and screens
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
	hs.grid.set(win, '0,0 12x12', nextScreen)
end)

-- Flow (general)
hs.hotkey.bind(hyper, 'return', function()

    -- print all screen names
    for i, screen in ipairs(hs.screen.allScreens()) do
        print(screen:name() .. " " .. screen:getUUID())
    end

    -- Send apps to grid based on available screens.
    -- Use fallback screens depending on the physical work environment.

    -- Main screen
    -- We have multiple possible layouts based on active Flashspace workspace
    -- Dev workspace
    adjustWindowsOfAppInScreen('Rider', {
        {mainScreenId, '0,0 ' .. gridSize},
        {laptopScreenId, '0,0 ' .. gridSize} -- Fallback
    })
    adjustWindowsOfAppInScreen('Firefox', {
        {mainScreenId, '0,0 6x12'},
        {laptopScreenId, '0,0 ' .. gridSize} -- Fallback
    })
    adjustWindowsOfAppInScreen('Docker Desktop', {
        {mainScreenId, '6,0 6x12'},
        {laptopScreenId, '0,0 ' .. gridSize} -- Fallback
    })
    -- Browse workspace
    adjustWindowsOfAppInScreen('Spotify', {
        {mainScreenId, '0,0 4x12'},
        {laptopScreenId, '0,0 ' .. gridSize} -- Fallback
    })
    adjustWindowsOfAppInScreen('Arc', {
        {mainScreenId, '4,0 8x12'},
        {laptopScreenId, '0,0 ' .. gridSize} -- Fallback
    })
    -- Terminal workspace
    adjustWindowsOfAppInScreen('iTerm', {
        {mainScreenId, '0,0 ' .. gridSize},
        {laptopScreenId, '0,0 ' .. gridSize} -- Fallback
    })

    -- Vertical screen
    -- Top 2/3 of the screen is Slack
    adjustWindowsOfAppInScreen('Slack', {
        {verticalScreenId, '0,0 12x6'},
        {laptopScreenId, '0,0 ' .. gridSize} -- Fallback
    })
    -- Bottom 1/6 of the screen is Teams
    adjustWindowsOfAppInScreen('Microsoft Teams', {
        {verticalScreenId, '0,6 12x3'},
        {laptopScreenId, '0,0 ' .. gridSize} -- Fallback
    })
    -- Botton 1/6 of the screen is CotEditor
    adjustWindowsOfAppInScreen('CotEditor', {
        {verticalScreenId, '0,9 12x3'},
        {laptopScreenId, '0,0 ' .. gridSize} -- Fallback
    })

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

-- Window resize
hs.hotkey.bind(hyper, 'h', function()
    local win = hs.window.focusedWindow()
    hs.grid.resizeWindowThinner(win)
end)
hs.hotkey.bind(hyper, 'l', function()
    local win = hs.window.focusedWindow()
    hs.grid.resizeWindowWider(win)
end)
hs.hotkey.bind(hyper, 'k', function()
    local win = hs.window.focusedWindow()
    hs.grid.resizeWindowShorter(win)
end)
hs.hotkey.bind(hyper, 'j', function()
    local win = hs.window.focusedWindow()
    hs.grid.resizeWindowTaller(win)
end)

-- Window move
hs.hotkey.bind(hyperCtrl, 'h', function()
    local win = hs.window.focusedWindow()
    hs.grid.pushWindowLeft(win)
end)
hs.hotkey.bind(hyperCtrl, 'l', function()
    local win = hs.window.focusedWindow()
    hs.grid.pushWindowRight(win)
end)
hs.hotkey.bind(hyperCtrl, 'k', function()
    local win = hs.window.focusedWindow()
    hs.grid.pushWindowUp(win)
end)
hs.hotkey.bind(hyperCtrl, 'j', function()
    local win = hs.window.focusedWindow()
    hs.grid.pushWindowDown(win)
end)

-- Window move to grid
hs.hotkey.bind(hyperCtrlCmd, 'left', function()
    local win = hs.window.focusedWindow()
    hs.grid.set(win, '0,0 6x12')
end)
hs.hotkey.bind(hyperCtrlCmd, 'right', function()
    local win = hs.window.focusedWindow()
    hs.grid.set(win, '6,0 6x12')
end)
hs.hotkey.bind(hyperCtrlCmd, 'up', function()
    local win = hs.window.focusedWindow()
    hs.grid.set(win, '0,0 12x6')
end)
hs.hotkey.bind(hyperCtrlCmd, 'down', function()
    local win = hs.window.focusedWindow()
    hs.grid.set(win, '0,6 12x6')
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

function adjustWindowsOfAppInScreen(appName, screenConfigs)
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
            local screen = nil
            local targetScreenName = nil
            local targetGridSettings = nil
            
            -- Try each screen configuration in order until we find one that exists
            for j, config in ipairs(screenConfigs) do
                local screenId = config[1]
                local gridSettings = config[2]
screen = hs.screen.find(screenId)
                if screen then
                    targetScreenName = screenId
                    targetGridSettings = gridSettings
                    break
                end
            end
            
            if not screen then
local screenNames = {}
                for j, config in ipairs(screenConfigs) do
                    table.insert(screenNames, config[1])
                end
                hs.alert.show("No screens found from: " .. table.concat(screenNames, ", "))
                return
            end
            hs.grid.set(win, targetGridSettings, targetScreenName)
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
