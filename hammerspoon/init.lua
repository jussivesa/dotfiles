-- Imports

local MiddleClickDragScroll = hs.loadSpoon("MiddleClickDragScroll"):start()
local tiling = require('tiling')

local AutoEject = hs.loadSpoon("AutoEject"):configure{
    ejectDailyAt = "14:00"
}:start()

-- local MicSensitivityLevel = hs.loadSpoon("MicSensitivityLevel"):start()

-- Grid and window management stuff

-- Settings
hs.window.animationDuration = 0.00

-- Keys
hyper = {'shift', 'alt'}
hyperCtrl = {'shift', 'alt', 'ctrl'}
hyperCmd = {'shift', 'alt', 'cmd'}

-- Grid and screens
local gridSize = '12x12'
local verticalScreenId = '57BBF425-1226-486A-94BD-C3BE400B7933' -- LEN P27q-10 (2)
local mainScreenId = '541435B5-950D-4597-BC98-EDDE4D94E161' -- LEN P27q-10 (1)
local laptopScreenId = '37D8832A-2D66-02CA-B9F7-8F30A301B230' -- Built-in Retina Display
local homeScreenId = 'D259E9F4-DC63-4DA4-BB7A-E9F22A875638'

-- Tiling layout per screen
tiling.screenLayouts[mainScreenId]     = { layout = 'deck',          peekWidth    = 1    }
tiling.screenLayouts[verticalScreenId] = { layout = 'rows' }
tiling.screenLayouts[laptopScreenId]   = { layout = 'columns' }
tiling.screenLayouts[homeScreenId]     = { layout = 'primary_stack', primaryRatio = 0.60 }

-- Grid
hs.grid.setMargins(hs.geometry.size(5,5))
hs.grid.setGrid(gridSize)
hs.hotkey.bind(hyper,'g',function()
  hs.grid.show()
end)

-- Move between screens
hs.hotkey.bind(hyper, 'tab', function()
    local win        = hs.window.focusedWindow()
    local srcScreen  = win:screen()
    local nextScreen = srcScreen:next()
    hs.grid.set(win, '0,0 12x12', nextScreen)
    if tiling.isScreenTiled(srcScreen)  then tiling.tileScreen(srcScreen)  end
    if tiling.isScreenTiled(nextScreen) then tiling.tileScreen(nextScreen) end
end)
hs.hotkey.bind(hyperCtrl, 'tab', function()
    local win        = hs.window.focusedWindow()
    local nextScreen = win:screen():next()
    win:moveToScreen(nextScreen)
end)

-- Flow (general)
hs.hotkey.bind(hyper, 'return', function()

    -- print all screen names
    for i, screen in ipairs(hs.screen.allScreens()) do
        print(screen:name() .. " " .. screen:getUUID())
    end

    -- Select correct Flashspace profile depending on physical work environment
    -- If home screen is available, use different profile
    local homeScreenAvailable = false
    for i, screen in ipairs(hs.screen.allScreens()) do
        if screen:getUUID() == homeScreenId then
            homeScreenAvailable = true
            break
        end
    end
    if homeScreenAvailable then
        hs.execute("flashspace profile 'Remote Work'", true)
    else
        hs.execute("flashspace profile 'Default'", true)
    end

    -- Send apps to grid based on available screens.
    -- Use fallback screens depending on the physical work environment.

    -- Main screen
    -- We have multiple possible layouts based on active Flashspace workspace
    -- Dev workspace
    adjustWindowsOfAppInScreen('Rider', {
        {mainScreenId, '0,0 ' .. gridSize},
        {homeScreenId, '0,0 ' .. gridSize},
        {laptopScreenId, '0,0 ' .. gridSize} -- Fallback
    })
    adjustWindowsOfAppInScreen('DataGrip', {
        {mainScreenId, '0,0 ' .. gridSize},
        {homeScreenId, '0,0 ' .. gridSize},
        {laptopScreenId, '0,0 ' .. gridSize} -- Fallback
    })
    adjustWindowsOfAppInScreen('Firefox', {
        {mainScreenId, '0,0 6x12'},
        {homeScreenId, '0,0 6x12'},
        {laptopScreenId, '0,0 ' .. gridSize} -- Fallback
    })
    adjustWindowsOfAppInScreen('Docker Desktop', {
        {mainScreenId, '6,0 6x12'},
        {homeScreenId, '6,0 6x12'},
        {laptopScreenId, '0,0 ' .. gridSize} -- Fallback
    })
    -- Browse workspace
    adjustWindowsOfAppInScreen('Spotify', {
        {mainScreenId, '0,0 4x12'},
        {homeScreenId, '0,0 4x12'},
        {laptopScreenId, '0,0 ' .. gridSize} -- Fallback
    })
    adjustWindowsOfAppInScreen('Arc', {
        {mainScreenId, '4,0 8x12'},
        {homeScreenId, '4,0 8x12'},
        {laptopScreenId, '0,0 ' .. gridSize} -- Fallback
    })
    -- Terminal workspace
    adjustWindowsOfAppInScreen('WezTerm', {
        {mainScreenId, '0,0 ' .. gridSize},
        {homeScreenId, '0,0 ' .. gridSize},
        {laptopScreenId, '0,0 ' .. gridSize} -- Fallback
    })

    -- Vertical screen
    adjustWindowsOfAppInScreen('Slack', {
        {verticalScreenId, '0,0 12x5'}, -- Top ~~ 2/3 of the screen is Slack
        {homeScreenId, '0,0 5x12'},
        {laptopScreenId, '0,0 ' .. gridSize} -- Fallback
    })
    adjustWindowsOfAppInScreen('Microsoft Teams', {
        {verticalScreenId, '0,5 12x4'}, -- Bottom ~~ 1/6 of the screen is Teams
        {homeScreenId, '5,0 4x12'},
        {laptopScreenId, '0,0 ' .. gridSize} -- Fallback
    })
    adjustWindowsOfAppInScreen('CotEditor', {
        {verticalScreenId, '0,9 12x3'}, -- Botton 1/6 of the screen is CotEditor
        {homeScreenId, '9,0 3x12'},
        {laptopScreenId, '0,0 ' .. gridSize} -- Fallback
    })

    -- Laptop: all other apps to be fullscreen in here
    fullscreenWindowsOfScreen(laptopScreenId)
end)

local windowSizesCache = {}

-- Window management
hs.hotkey.bind(hyper, 'f', function()
    tiling.fullscreenToggle(hs.window.focusedWindow())
end)
hs.hotkey.bind(hyper, 'c', function()
    local win = hs.window.focusedWindow()
    windowSizesCache[win:id()] = win:frame()
    hs.grid.set(win, '2,2 8x8')
end)
hs.hotkey.bind(hyper, 'r', function()
    local win = hs.window.focusedWindow()
    local frame = windowSizesCache[win:id()]
    if frame then
        win:setFrame(frame)
        windowSizesCache[win:id()] = nil
    else
        hs.grid.set(win, '2,2 8x8')
    end
end)

-- Window focus (directional) 
hs.hotkey.bind(hyper, 'h', function()
    local win    = hs.window.focusedWindow()
    win:focusWindowWest(nil, false, false)
end)
hs.hotkey.bind(hyper, 'l', function()
    local win    = hs.window.focusedWindow()
    win:focusWindowEast(nil, false, false)
end)
hs.hotkey.bind(hyper, 'k', function()
    hs.window.focusedWindow():focusWindowNorth(nil, false, false)
end)
hs.hotkey.bind(hyper, 'j', function()
    hs.window.focusedWindow():focusWindowSouth(nil, false, false)
end)

-- Window move. On tiled screens swaps with the nearest neighbour in that
-- direction; falls back to a normal grid push when not tiled or no neighbour.
-- Deck navigation when screen is in deck mode instead of moving windows.
hs.hotkey.bind(hyperCtrl, 'h', function()
    local win = hs.window.focusedWindow()
    local screen = win:screen()
    if tiling.isDeckScreen(screen) then
        tiling.deckPrev(screen)
    elseif not tiling.swapWithAdjacent(win, 'left') then
        hs.grid.pushWindowLeft(win)
    end
end)
hs.hotkey.bind(hyperCtrl, 'l', function()
    local win = hs.window.focusedWindow()
    local screen = win:screen()
    if tiling.isDeckScreen(screen) then
        tiling.deckNext(screen)
    elseif not tiling.swapWithAdjacent(win, 'right') then
        hs.grid.pushWindowRight(win)
    end
end)
hs.hotkey.bind(hyperCtrl, 'k', function()
    local win = hs.window.focusedWindow()
    if not tiling.swapWithAdjacent(win, 'up') then
        hs.grid.pushWindowUp(win)
    end
end)
hs.hotkey.bind(hyperCtrl, 'j', function()
    local win = hs.window.focusedWindow()
    if not tiling.swapWithAdjacent(win, 'down') then
        hs.grid.pushWindowDown(win)
    end
end)

-- Window resize. When the screen is tiled, redistributes other windows after each step.
hs.hotkey.bind(hyperCmd, 'h', function()
    local win = hs.window.focusedWindow()
    hs.grid.resizeWindowThinner(win)
    tiling.retileAfterResize(win)
end)
hs.hotkey.bind(hyperCmd, 'l', function()
    local win = hs.window.focusedWindow()
    hs.grid.resizeWindowWider(win)
    tiling.retileAfterResize(win)
end)
hs.hotkey.bind(hyperCmd, 'k', function()
    local win = hs.window.focusedWindow()
    local screen = win:screen()
    if tiling.isDeckScreen(screen) then
        tiling.deckTogglePeek(screen)
        return
    end
    hs.grid.resizeWindowShorter(win)
    tiling.retileAfterResize(win)
end)
hs.hotkey.bind(hyperCmd, 'j', function()
    local win = hs.window.focusedWindow()
    local screen = win:screen()
    if tiling.isDeckScreen(screen) then
        tiling.deckTogglePeek(screen)
        return
    end
    hs.grid.resizeWindowTaller(win)
    tiling.retileAfterResize(win)
end)

-- Tiling
hs.hotkey.bind(hyper, 't', function()
    local screen = hs.window.focusedWindow():screen()
    if tiling.isScreenTiled(screen) then
        tiling.untileScreen(screen)
    else
        tiling.tileScreen(screen)
    end
end)
hs.hotkey.bind(hyperCtrl, 't', tiling.tileAll)
hs.hotkey.bind(hyper, 'm', function()
    tiling.promoteToPrimary(hs.window.focusedWindow())
end)

-- Window snap to half-screen
hs.hotkey.bind(hyperCtrl, 'left', function()
    hs.grid.set(hs.window.focusedWindow(), '0,0 6x12')
end)
hs.hotkey.bind(hyperCtrl, 'right', function()
    hs.grid.set(hs.window.focusedWindow(), '6,0 6x12')
end)
hs.hotkey.bind(hyperCtrl, 'up', function()
    hs.grid.set(hs.window.focusedWindow(), '0,0 12x6')
end)
hs.hotkey.bind(hyperCtrl, 'down', function()
    hs.grid.set(hs.window.focusedWindow(), '0,6 12x6')
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

local mouseMoveSpeed = 20
function moveMouseLeft()
    hs.mouse.setAbsolutePosition(hs.geometry.point(hs.mouse.getAbsolutePosition().x - mouseMoveSpeed, hs.mouse.getAbsolutePosition().y))
end

function moveMouseRight()
    hs.mouse.setAbsolutePosition(hs.geometry.point(hs.mouse.getAbsolutePosition().x + mouseMoveSpeed, hs.mouse.getAbsolutePosition().y))
end

function moveMouseUp()
    hs.mouse.setAbsolutePosition(hs.geometry.point(hs.mouse.getAbsolutePosition().x, hs.mouse.getAbsolutePosition().y - mouseMoveSpeed))
end

function moveMouseDown()
    hs.mouse.setAbsolutePosition(hs.geometry.point(hs.mouse.getAbsolutePosition().x, hs.mouse.getAbsolutePosition().y + mouseMoveSpeed))
end
hs.hotkey.bind(hyper, '6', moveMouseLeft, nil, moveMouseLeft)
hs.hotkey.bind(hyper, '9', moveMouseRight, nil, moveMouseRight)
hs.hotkey.bind(hyper, '8', moveMouseUp, nil, moveMouseUp)
hs.hotkey.bind(hyper, '7', moveMouseDown, nil, moveMouseDown)

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
