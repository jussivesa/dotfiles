-- Imports

local MiddleClickDragScroll = hs.loadSpoon("MiddleClickDragScroll"):start()
local layouts = require('layouts')
require('hs.ipc') -- Lets the `hs` CLI (Raycast script commands) call into this config

local AutoEject = hs.loadSpoon("AutoEject"):configure{
    ejectDailyAt = "14:00"
}:start()

-- local MicSensitivityLevel = hs.loadSpoon("MicSensitivityLevel"):start()

-- Window hotkeys are in Raycast. See README.md.

-- Keys
hyper = {'shift', 'alt'}

-- Screens
local verticalScreenId = '57BBF425-1226-486A-94BD-C3BE400B7933' -- LEN P27q-10 (2)
local mainScreenId = '541435B5-950D-4597-BC98-EDDE4D94E161' -- LEN P27q-10 (1)
local laptopScreenId = '37D8832A-2D66-02CA-B9F7-8F30A301B230' -- Built-in Retina Display
local homeScreenId = 'D259E9F4-DC63-4DA4-BB7A-E9F22A875638' -- Acer XB273K S

-- App layouts per FlashSpace profile, applied once by setupWorkEnvironment().
-- Each rule: { screenUUID, Raycast Window Management command }.
-- An app whose screen is not connected is maximized on the laptop screen.
local bundle = {
    rider     = 'com.jetbrains.rider',
    datagrip  = 'com.jetbrains.datagrip',
    firefox   = 'org.mozilla.firefox',
    docker    = 'com.electron.dockerdesktop', -- Window owner; launched via com.docker.docker
    spotify   = 'com.spotify.client',
    arc       = 'company.thebrowser.Browser',
    wezterm   = 'com.github.wez.wezterm',
    slack     = 'com.tinyspeck.slackmacgap',
    teams     = 'com.microsoft.teams2',
    coteditor = 'com.coteditor.CotEditor',
}

layouts.rules['Default'] = {
    -- Main screen: Dev, Browse and Terminal workspaces
    [bundle.rider]     = { mainScreenId, 'maximize' },
    [bundle.datagrip]  = { mainScreenId, 'maximize' },
    [bundle.firefox]   = { mainScreenId, 'last-two-thirds' }, -- All profiles, same as Arc
    [bundle.docker]    = { mainScreenId, 'right-half', launch = 'com.docker.docker' },
    [bundle.spotify]   = { mainScreenId, 'first-third' },
    [bundle.arc]       = { mainScreenId, 'last-two-thirds' },
    [bundle.wezterm]   = { mainScreenId, 'maximize' },
    -- Vertical screen: floating apps, one third each
    [bundle.slack]     = { verticalScreenId, 'top-third' },
    [bundle.teams]     = { verticalScreenId, 'middle-third' },
    [bundle.coteditor] = { verticalScreenId, 'bottom-third' },
}

layouts.rules['Remote Work'] = {
    [bundle.rider]     = { homeScreenId, 'maximize' },
    [bundle.datagrip]  = { homeScreenId, 'maximize' },
    [bundle.firefox]   = { homeScreenId, 'last-two-thirds' }, -- All profiles, same as Arc
    [bundle.docker]    = { homeScreenId, 'right-half', launch = 'com.docker.docker' },
    [bundle.spotify]   = { homeScreenId, 'first-third' },
    [bundle.arc]       = { homeScreenId, 'last-two-thirds' },
    [bundle.wezterm]   = { homeScreenId, 'maximize' },
    -- Floating apps, one third each
    [bundle.slack]     = { homeScreenId, 'first-third' },
    [bundle.teams]     = { homeScreenId, 'center-third' },
    [bundle.coteditor] = { homeScreenId, 'last-third' },
}

layouts.fallbackScreen   = laptopScreenId
layouts.maximizeOthersOn = laptopScreenId

-- One-time setup when the work environment changes: select the FlashSpace
-- profile for the connected screens, launch missing apps, place all windows
-- with Raycast commands. Called by the Raycast script command
-- ~/.config/raycast/scripts/setup-work-environment.sh.
function setupWorkEnvironment()
    if hs.screen.find(homeScreenId) then
        layouts.setup('Remote Work')
        return 'Remote Work'
    end
    layouts.setup('Default')
    return 'Default'
end

-- Mouse (Raycast has no mouse commands)
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
