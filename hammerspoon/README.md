# Hammerspoon Config

Window positions and window hotkeys are in Raycast. FlashSpace handles workspaces and profiles. Hammerspoon does these tasks:

- One-time setup of apps and windows per FlashSpace profile (`layouts.lua`). Raycast commands do the window moves.
- Mouse hotkeys. Raycast has no mouse commands.
- Spoons: `MiddleClickDragScroll`, `AutoEject`.

`hyper` = `shift + alt`.

---

## Raycast hotkeys

Raycast keeps its hotkeys in an encrypted database, so assign them by hand. Open Raycast Settings → Extensions, select the command, and record the hotkey. The table gives the old Hammerspoon hotkey as the suggested hotkey.

| Old Hammerspoon hotkey | Old function | Raycast command | Note |
|---|---|---|---|
| `hyper + return` | Setup apps and windows | Setup Work Environment (script command) | Same function |
| `hyper + h/l/k/j` | Focus window left/right/up/down | Focus Window Left/Right/Up/Down (script commands) | Run `flashspace focus --direction` |
| `hyper + tab` | Move to next screen, full size | Move to Next Display, then Maximize | Two commands |
| `hyperCtrl + tab` | Move to next screen, keep proportions | Move to Next Display | Turn on "Keep Aspect Ratio" in the command settings |
| `hyper + f` | Fullscreen toggle | Maximize or Toggle Fullscreen | Already in Raycast |
| `hyper + g` | Grid overlay | Toggle Grid Overlay | |
| `hyperCtrl + h/l/k/j` | Swap or push window | Move Left/Right/Top/Bottom | Moves the window to the screen edge. No swap |
| `hyperCmd + l/k` | Resize wider/shorter | Make Larger | One step in both directions |
| `hyperCmd + h/j` | Resize thinner/taller | Make Smaller | One step in both directions |
| `hyperCtrl + ←/→/↑/↓` | Halves | Left/Right/Top/Bottom Half | Already in Raycast |
| `hyper + c` | Centre | Center, Center Half | Already in Raycast |
| `hyper + s` | Launch or focus Slack | Slack (application hotkey) | Set the hotkey on the Slack app in Raycast |
| `hyper + t`, `hyperCtrl + t`, `hyper + m` | Tiling: toggle, tile all, promote | None | Tiling is removed. Use halves and thirds |

### Script commands

The script commands are in `~/.config/raycast/scripts/`:

| File | Raycast title |
|---|---|
| `setup-work-environment.sh` | Setup Work Environment |
| `focus-window-left.sh`, `-right`, `-up`, `-down` | Focus Window Left/Right/Up/Down |

To add them to Raycast:

1. Open Raycast Settings → Extensions.
2. Click `+` → Add Script Directory.
3. Select `~/.config/raycast/scripts`.
4. Assign the hotkeys from the table above.

---

## App layouts (`layouts.lua`)

One-time setup of apps and windows per FlashSpace profile. Raycast moves and resizes the windows. Hammerspoon only launches apps, focuses windows and reads window state.

### Configuration

In `init.lua`, set one rule per app bundle ID: `{ screenUUID, raycastCommand }`.

```lua
layouts.rules['Default'] = {
    ['com.jetbrains.rider']       = { mainScreenId, 'maximize' },
    ['com.tinyspeck.slackmacgap'] = { verticalScreenId, 'top-third' },
}
layouts.fallbackScreen   = laptopScreenId  -- Used when a rule's screen is not connected (maximize)
layouts.maximizeOthersOn = laptopScreenId  -- Windows without a rule on this screen are maximized
```

The command is the title of a built-in Raycast Window Management command in lowercase, with `-` for spaces. Examples: `maximize`, `left-half`, `right-half`, `first-third`, `center-third`, `last-third`, `first-two-thirds`, `last-two-thirds`, `top-third`, `middle-third`, `bottom-third`. These commands are free. Custom positions need Raycast Pro, so the rules use only built-in commands.

To find a bundle ID, run `osascript -e 'id of app "App Name"'`.

### Trigger

The Raycast script command **Setup Work Environment** runs the setup. It calls `setupWorkEnvironment()` in `init.lua` through the `hs` CLI. Use it after a change of work environment. It does these steps in sequence:

1. Activates the FlashSpace profile for the connected screens: `Remote Work` when the home screen is connected, else `Default`. Waits until FlashSpace reports the profile.
2. Launches the apps with a rule that are not running (`open -g`). Waits up to 30 s for their windows.
3. For each window: focuses it, runs Raycast "Move to Next Display" until the window is on the target screen, then runs the rule's command.
4. Focuses the window that was focused before.

Windows do not move at any other time.

### Notes

- Raycast commands act on the focused window. Focusing an app in another FlashSpace workspace activates that workspace, so the screen changes during setup. A setup with 13 windows takes about 15 s.
- All processes of a bundle ID are placed. Example: each Firefox profile runs as a separate `org.mozilla.firefox` process.
- When the launcher bundle is not the window owner, set `launch` in the rule. Example: Docker Desktop windows belong to `com.electron.dockerdesktop`, and `com.docker.docker` launches it.
- Raycast deeplinks are `raycast://extensions/raycast/window-management/<command>`.

---

## Hammerspoon hotkeys

### Mouse

| Key | Action |
|-----|--------|
| `hyper + i` | Scroll up at focused window |
| `hyper + u` | Scroll down at focused window |
| `hyper + y` | Left click at current mouse position |
| `hyper + 6/9/8/7` | Move mouse left/right/up/down |
