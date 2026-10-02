-- ================================================================================
-- WezTerm Configuration
-- ================================================================================

local wezterm = require("wezterm")

-- Initialize configuration
local config = wezterm.config_builder and wezterm.config_builder() or {}

-- ================================================================================
-- Configuration Variables
-- ================================================================================

local TAB_STYLE = "square" -- "rounded" or "square"
local LEADER_PREFIX = utf8.char(0x1f30a) -- Ocean wave emoji

-- Light and dark themes. LEADER + ' switches between them.
--
-- background_color is the window wash. It covers the scheme background, so it
-- must follow the theme. opacity multiplies the alpha in background_color.
-- The light theme stays close to opaque, because a translucent light window
-- lets the blurred desktop show through and makes the background uneven.
--
-- Ef-Maris-Light was measured against every built-in light scheme. Its worst
-- chromatic color reaches 4.97:1 against its own background, which is better
-- than Catppuccin Frappe's worst of 4.65:1. Catppuccin Latte drops to 2.31:1
-- and washes out yellow, magenta, green, and cyan.
local THEMES = {
    dark = {
        color_scheme = "Catppuccin Frappe",
        background_color = "rgba(0, 0, 0, 0.83)",
        opacity = 0.83,
    },
    light = {
        color_scheme = "Ef-Maris-Light",
        background_color = "rgba(237, 244, 248, 1.0)", -- #edf4f8, the scheme background
        opacity = 0.95,
    },
}

-- Theme to use when WezTerm starts.
local DEFAULT_THEME = "dark"

-- Global scratch session (toggleable).
-- The session lives in its own workspace, so it is reachable from every
-- project workspace and keeps running while it is hidden.
local TOGGLEABLE = {
    workspace = "toggleable",
    -- Command to start in the workspace. Set to nil to start the default shell.
    -- Wrap the remote side in tmux to keep the toggleable alive after WezTerm quits:
    --   args = { "/usr/bin/ssh", "-t", "HOST", "tmux new -A -s toggleable" },
    args = nil,
}

-- ================================================================================
-- Plugins
-- ================================================================================

local workspace_switcher = wezterm.plugin.require("https://github.com/MLFlexer/smart_workspace_switcher.wezterm")
workspace_switcher.zoxide_path = "/opt/homebrew/bin/zoxide"

local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")

-- Resurrect encryption
resurrect.state_manager.set_encryption({
  enable = true,
  method = "age",
  private_key = "/Users/vesa/.config/wezterm/resurrect_key.txt",
  public_key = "age1flrdsp82c4wykez3kf58xytq4cpv49ha8nwdjry5cv7usfmscqes9rhxad",
  method = "/opt/homebrew/bin/age"
})

-- ================================================================================
-- Basic Configuration
-- ================================================================================

-- Environment
config.set_environment_variables = {
    PATH = "/opt/homebrew/bin:" .. os.getenv("PATH"),
}

-- Shell
config.default_prog = { "/opt/homebrew/bin/fish" }

-- Performance
config.max_fps = 120
config.animation_fps = 120

-- ================================================================================
-- Appearance
-- ================================================================================

-- Font
config.font = wezterm.font_with_fallback({ "JetbrainsMono Nerd Font Mono" })
config.font_size = 16

-- Window
local function background_layers(theme)
    return {
	{
        opacity = theme.opacity,
		source = {
			Color = theme.background_color,
		},
		height = "100%",
		width = "100%",
	},
}
end
config.macos_window_background_blur = 100
config.window_decorations = "RESIZE"
config.pane_focus_follows_mouse = false

-- Pane Management
config.inactive_pane_hsb = {
    hue = 1.0,
    saturation = 1.0,
    brightness = 0.7,
}

-- Colors
-- wezterm.GLOBAL keeps the selected theme through a config reload.
local theme_name = wezterm.GLOBAL.theme_name
if not THEMES[theme_name] then
    theme_name = DEFAULT_THEME
end
wezterm.GLOBAL.theme_name = theme_name

config.color_scheme = THEMES[theme_name].color_scheme
config.background = background_layers(THEMES[theme_name])

-- Read by the tab bar and the leader indicator. toggle_theme reassigns it.
local colors = wezterm.color.get_builtin_schemes()[THEMES[theme_name].color_scheme]

-- Tab Bar
config.hide_tab_bar_if_only_one_tab = false
config.tab_bar_at_bottom = true
config.use_fancy_tab_bar = false
config.tab_max_width = 250
config.tab_and_split_indices_are_zero_based = false

-- ================================================================================
-- Global Toggleable Workspace
-- ================================================================================

local function workspace_exists(name)
    for _, existing in ipairs(wezterm.mux.get_workspace_names()) do
        if existing == name then
            return true
        end
    end
    return false
end

-- Returns the workspace to go back to when leaving the toggleable workspace.
local function toggleable_return_workspace()
    local previous = wezterm.GLOBAL.toggleable_return_workspace

    if previous and previous ~= TOGGLEABLE.workspace and workspace_exists(previous) then
        return previous
    end

    -- The stored workspace is gone (WezTerm restart or closed window).
    -- Use any other open workspace instead.
    for _, name in ipairs(wezterm.mux.get_workspace_names()) do
        if name ~= TOGGLEABLE.workspace then
            return name
        end
    end

    return "default"
end

-- Shows the toggleable workspace, or returns to the workspace it was called from.
local function toggle_toggleable_workspace(window, pane)
    if window:active_workspace() == TOGGLEABLE.workspace then
        window:perform_action(
            wezterm.action.SwitchToWorkspace({ name = toggleable_return_workspace() }),
            pane
        )
        return
    end

    wezterm.GLOBAL.toggleable_return_workspace = window:active_workspace()

    -- spawn applies only when the workspace does not exist yet. An existing
    -- toggleable workspace keeps its running process.
    window:perform_action(
        wezterm.action.SwitchToWorkspace({
            name = TOGGLEABLE.workspace,
            spawn = TOGGLEABLE.args and { args = TOGGLEABLE.args } or nil,
        }),
        pane
    )
end

-- ================================================================================
-- Light/Dark Theme Toggle
-- ================================================================================

-- Applies the selected theme to one window. Config overrides are per window, so
-- a new window starts on the base config and gets the theme from update-status.
local function apply_theme(gui_window)
    local theme = THEMES[wezterm.GLOBAL.theme_name]
    if not theme then
        return
    end

    -- The window already shows this theme. Do not write overrides on every
    -- status update.
    if gui_window:effective_config().color_scheme == theme.color_scheme then
        return
    end

    gui_window:set_config_overrides({
        color_scheme = theme.color_scheme,
        background = background_layers(theme),
    })
end

-- Switches between the light and the dark theme in all open windows.
local function toggle_theme()
    local next_name = wezterm.GLOBAL.theme_name == "light" and "dark" or "light"
    wezterm.GLOBAL.theme_name = next_name

    colors = wezterm.color.get_builtin_schemes()[THEMES[next_name].color_scheme]

    for _, mux_window in ipairs(wezterm.mux.all_windows()) do
        local gui_window = mux_window:gui_window()
        if gui_window then
            apply_theme(gui_window)
        end
    end
end

-- Tab bar and leader indicator colors for the active scheme.
-- Not every built-in scheme defines tab_bar. Ef-Maris-Light does not, so fall
-- back to the scheme foreground and background, which is its own contrast pair.
local function tab_bar_colors()
    local tab_bar = colors.tab_bar or {}
    local active_tab = tab_bar.active_tab or {}

    return {
        bar = tab_bar.background or colors.background,
        accent = active_tab.bg_color or colors.foreground,
        text = active_tab.fg_color or colors.background,
    }
end

-- ================================================================================
-- Key Bindings
-- ================================================================================

config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 2000 }

config.keys = {
    -- Workspace Management
    {
        key = "p",
        mods = "LEADER",
        action = workspace_switcher.switch_workspace(),
    },
    {
        key = "f",
        mods = "LEADER",
        action = wezterm.action.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }),
    },

    -- Global toggleable session: show it, or go back to the previous workspace.
    {
        key = "t",
        mods = "LEADER",
        action = wezterm.action_callback(toggle_toggleable_workspace),
    },
    {
        key = "Enter",
        mods = "SUPER|SHIFT",
        action = wezterm.action_callback(toggle_toggleable_workspace),
    },

    -- Light/dark theme
    {
        key = "'",
        mods = "LEADER",
        action = wezterm.action_callback(toggle_theme),
    },

    -- Settings
    {
        key = ",",
        mods = "SUPER",
        action = wezterm.action.SpawnCommandInNewTab({
            cwd = wezterm.home_dir,
            args = { "nvim", wezterm.config_file },
        }),
    },

    -- Resurrect
    {
        key = "r",
        mods = "LEADER",
        action = wezterm.action_callback(function(win, pane)
            resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id, label)
                local type = string.match(id, "^([^/]+)") -- match before '/'
                id = string.match(id, "([^/]+)$") -- match after '/'
                id = string.match(id, "(.+)%..+$") -- remove file extention
                local opts = {
                relative = true,
                restore_text = true,
                on_pane_restore = resurrect.tab_state.default_on_pane_restore,
                }
                if type == "workspace" then
                    local state = resurrect.state_manager.load_state(id, "workspace")
                    resurrect.workspace_state.restore_workspace(state, opts)
                elseif type == "window" then
                    local state = resurrect.state_manager.load_state(id, "window")
                    resurrect.window_state.restore_window(pane:window(), state, opts)
                elseif type == "tab" then
                    local state = resurrect.state_manager.load_state(id, "tab")
                    resurrect.tab_state.restore_tab(pane:tab(), state, opts)
                end
            end)
        end),
    },

    -- Tab Management
    { key = "c", mods = "LEADER", action = wezterm.action.SpawnTab("CurrentPaneDomain") },
    { key = "x", mods = "LEADER", action = wezterm.action.CloseCurrentPane({ confirm = true }) },
    { key = "b", mods = "LEADER", action = wezterm.action.ActivateTabRelative(-1) },
    { key = "n", mods = "LEADER", action = wezterm.action.ActivateTabRelative(1) },

    -- Pane Management
    { key = "|", mods = "LEADER", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { key = "-", mods = "LEADER", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },

    -- Pane Navigation
    { key = "h", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Left") },
    { key = "j", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Down") },
    { key = "k", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Up") },
    { key = "l", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Right") },

    -- Pane Resizing
    { key = "LeftArrow", mods = "LEADER", action = wezterm.action.AdjustPaneSize({ "Left", 5 }) },
    { key = "RightArrow", mods = "LEADER", action = wezterm.action.AdjustPaneSize({ "Right", 5 }) },
    { key = "DownArrow", mods = "LEADER", action = wezterm.action.AdjustPaneSize({ "Down", 5 }) },
    { key = "UpArrow", mods = "LEADER", action = wezterm.action.AdjustPaneSize({ "Up", 5 }) },

}

config.mouse_bindings = {
  {
    event = { Drag = { streak = 1, button = 'Left' } },
    mods = 'SUPER',
    action = wezterm.action.Nop,
  },
  {
    event = { Drag = { streak = 1, button = 'Left' } },
    mods = 'CTRL|SHIFT',
    action = wezterm.action.Nop,
  },
}

-- Add numbered tab switching (1-9)
for i = 1, 9 do
    table.insert(config.keys, {
        key = tostring(i),
        mods = "LEADER",
        action = wezterm.action.ActivateTab(i-1),
    })
end

-- ================================================================================
-- Helper Functions
-- ================================================================================

local function get_tab_title(tab_info)
    local title = tab_info.tab_title
    if title and #title > 0 then
        return title
    end
    return tab_info.active_pane.title
end

-- ================================================================================
-- Event Handlers
-- ================================================================================

-- Session Management Events
wezterm.on("gui-startup", resurrect.state_manager.resurrect_on_gui_startup)

wezterm.on("gui-exit", function(window, pane)
    resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
end)

-- loads the state whenever I create a new workspace
wezterm.on("smart_workspace_switcher.workspace_switcher.created", function(window, path, label)
  local workspace_state = resurrect.workspace_state

  workspace_state.restore_workspace(resurrect.state_manager.load_state(label, "workspace"), {
    window = window,
    relative = true,
    restore_text = true,
    on_pane_restore = resurrect.tab_state.default_on_pane_restore,
  })
end)

-- Saves the state whenever I select a workspace
wezterm.on("smart_workspace_switcher.workspace_switcher.selected", function(window, path, label)
  local workspace_state = resurrect.workspace_state
  resurrect.state_manager.save_state(workspace_state.get_workspace_state())
end)

-- Tab Title Formatting
wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
    local title = " " .. tab.tab_index .. ": " .. get_tab_title(tab) .. " "
    local left_edge_text = ""
    local right_edge_text = ""

    if TAB_STYLE == "rounded" then
        title = tab.tab_index .. ": " .. get_tab_title(tab)
        title = wezterm.truncate_right(title, max_width - 2)
        left_edge_text = wezterm.nerdfonts.ple_left_half_circle_thick
        right_edge_text = wezterm.nerdfonts.ple_right_half_circle_thick
    end

    if tab.is_active then
local c = tab_bar_colors()

        -- The edge glyphs form the ends of the accent block, so they take the
        -- accent as foreground and the bar as background.
        return {
            { Background = { Color = c.bar } },
            { Foreground = { Color = c.accent } },
            { Text = left_edge_text },
            { Background = { Color = c.accent } },
            { Foreground = { Color = c.text } },
            { Text = title },
            { Background = { Color = c.bar } },
            { Foreground = { Color = c.accent } },
            { Text = right_edge_text },
        }
    end
end)

-- Leader Key Status Indicator
wezterm.on("update-status", function(window, _)
    -- A window opened after the last toggle still runs the base config.
    apply_theme(window)

    if not window:leader_is_active() then
        window:set_left_status("")
        return
    end

    local c = tab_bar_colors()

    local divider = wezterm.nerdfonts.pl_right_hard_divider
        if TAB_STYLE == "rounded" then
            divider = wezterm.nerdfonts.ple_right_half_circle_thick
        end

    -- The left status sits directly left of the first tab. When that tab is
    -- active, the divider runs into its accent block, so use the accent as the
    -- divider background to join the two.
    local after_divider = c.bar
            for _, tab_info in ipairs(window:mux_window():tabs_with_info()) do
                if tab_info.is_active and tab_info.index == 0 then
                    after_divider = c.accent
                    break
                        end
    end

    window:set_left_status(wezterm.format({
        { Background = { Color = c.accent } },
        { Foreground = { Color = c.text } },
        { Text = " " .. LEADER_PREFIX .. " " },
        { Background = { Color = after_divider } },
        { Foreground = { Color = c.accent } },
        { Text = divider },
    }))
end)

-- Initialize a global table to cache the Azure status
wezterm.GLOBAL.azure_status = {
  user = nil,
  subscription = nil,
  id = nil,
  error = nil,
}

---
-- 1) Helper function to fetch Azure CLI info
---
local function update_azure_status()
  local ok, stdout, stderr = wezterm.run_child_process { '/opt/homebrew/bin/az', 'account', 'show', '--query', '{user:user.name, subscription:name, id:id}', '-o', 'json' }

  if not ok then
    -- Command not found or other execution error
    wezterm.GLOBAL.azure_status.user = nil
    wezterm.GLOBAL.azure_status.subscription = nil
    wezterm.GLOBAL.azure_status.id = nil
    wezterm.GLOBAL.azure_status.error = 'AZ not found'
  elseif ok then
      -- Command succeeded, try to parse the JSON
      local parse_success, data = pcall(wezterm.json_parse, stdout)
      if parse_success and data then
        -- Successfully parsed, update global cache
        wezterm.GLOBAL.azure_status.user = data.user
        wezterm.GLOBAL.azure_status.subscription = data.subscription
        wezterm.GLOBAL.azure_status.id = data.id
        wezterm.GLOBAL.azure_status.error = nil
      else
        -- Failed to parse JSON output
        wezterm.GLOBAL.azure_status.error = 'AZ JSON Err'
      end
  else
    -- Command failed (e.g., not logged in)
    wezterm.GLOBAL.azure_status.user = nil
    wezterm.GLOBAL.azure_status.subscription = nil
    wezterm.GLOBAL.azure_status.id = nil
    wezterm.GLOBAL.azure_status.error = 'AZ Login?'
  end

  -- Schedule the next update in 60 seconds
  wezterm.time.call_after(60, update_azure_status)
end

-- Run it once immediately on startup
update_azure_status()

---
-- 2) Event handler for the right status bar
---
wezterm.on('update-right-status', function(window, pane)
  -- Get the cached data
  local status = wezterm.GLOBAL.azure_status
  local elements = {}
  
  -- Use a cloud icon (requires a Nerd Font)
  table.insert(elements, { Text = ' ' .. wezterm.nerdfonts.fa_cloud .. ' ' })

  if status.error then
    -- c) Error text if values are not defined (or an error occurred)
    table.insert(elements, { Foreground = { Color = 'Red' } })
    table.insert(elements, { Text = status.error .. ' ' })
  elseif status.user and status.subscription then
    -- a) Azure CLI logged in username
    -- b) Subscription name
    table.insert(elements, { Text = status.user .. ' (' .. status.subscription .. ', ' .. status.id .. ') ' })
  else
    -- c) Placeholder text while loading for the first time
    table.insert(elements, { Foreground = { Color = 'Grey' } })
    table.insert(elements, { Text = 'Loading...' })
  end

  -- Set the formatted text
  window:set_right_status(wezterm.format(elements))
end)

-- ================================================================================
-- Export Configuration
-- ================================================================================

return config
