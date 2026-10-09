#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Setup Work Environment
# @raycast.mode silent
# @raycast.packageName Window Layouts

# Optional parameters:
# @raycast.icon 🪟
# @raycast.description Select the FlashSpace profile for the connected screens, launch apps, place windows.

# Runs setupWorkEnvironment() in ~/.hammerspoon/init.lua. Prints the profile name.
profile=$(/opt/homebrew/bin/hs -t 5 -q -c 'return setupWorkEnvironment()') || { echo "Hammerspoon did not respond"; exit 1; }
echo "Setup: $profile"
