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
local mainScreenName = 'LEN P27q-10 (2)'
local verticalScreenName = 'LEN P27q-10 (1)'
local laptopScreenName = 'Built-in Retina Display'

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

    -- Vertical screen
    -- Top 2/3 of the screen is Slack
    adjustWindowsOfAppInScreen(verticalScreenName, 'Slack', '0,0 12x6')
    -- Bottom 1/6 of the screen is Teams
    adjustWindowsOfAppInScreen(verticalScreenName, 'Microsoft Teams', '0,6 12x3')
    -- Botton 1/6 of the screen is CotEditor
    adjustWindowsOfAppInScreen(verticalScreenName, 'CotEditor', '0,9 12x3')
    
    -- Main screen
    -- We have multiple possible layouts based on active Flashspace workspace
    -- Dev workspace
    adjustWindowsOfAppInScreen(mainScreenName, 'Rider', '0,0 ' .. gridSize)
    adjustWindowsOfAppInScreen(mainScreenName, 'Code', '0,0 ' .. gridSize)
    adjustWindowsOfAppInScreen(mainScreenName, 'Firefox', '0,0 6x12')
    adjustWindowsOfAppInScreen(mainScreenName, 'Docker Desktop', '6,0 6x12')
    -- Browse workspace
    adjustWindowsOfAppInScreen(mainScreenName, 'Tidal', '0,0 4x12')
    adjustWindowsOfAppInScreen(mainScreenName, 'Arc', '4,0 8x12')

    -- Laptop: all other apps to be fullscreen in here
    fullscreenWindowsOfScreen(laptopScreenName)
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
            hs.grid.set(win, '0,0 ' .. gridSize)
        end
    end
end

function adjustWindowsOfAppInScreen(screenName, appName, gridSettings)
    local app = hs.application.get(appName)
    local wins
    if app then
        wins = app:allWindows()
    end
    if wins then
        for i, win in ipairs(wins) do
            win:moveToScreen(screenName)
            hs.grid.set(win, gridSettings)
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