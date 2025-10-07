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

-- ================================================================================
-- Plugins
-- ================================================================================

local workspace_switcher = wezterm.plugin.require("https://github.com/MLFlexer/smart_workspace_switcher.wezterm")
workspace_switcher.zoxide_path = "/opt/homebrew/bin/zoxide"

local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")

-- Resurrect encryption
resurrect.state_manager.set_encryption({
  enable = true,
  method = "gpg",
  public_key = "mDMEaL6DgxYJKwYBBAHaRw8BAQdACLE7Lj7FL9Vyd0MB+Y8pBbJh5L7YXHwjais3zTi5aHW0IUp1c3NpIFZlc2EgPGp1c3NpLnZlc2FAcGluamEuY29tPoiZBBMWCgBBFiEEMd7CdoISHcW16UoEO4Z+V7AQb7sFAmi+g4MCGwMFCQWjmoAFCwkIBwICIgIGFQoJCAsCBBYCAwECHgcCF4AACgkQO4Z+V7AQb7sZZwEA5inaNj525xoU8ZXo0Ek0+rFl9WMAKL3DIzffmH9wlZ0BALfnfHq4t6+oFIS8pSBlT1LPY+rLOEigSNlPXMNvnxkIuDgEaL6DgxIKKwYBBAGXVQEFAQEHQAlxMdswH5/XvFDsTuh41SwvYuvKPlMnS+3FWJ2ZF/0NAwEIB4h+BBgWCgAmFiEEMd7CdoISHcW16UoEO4Z+V7AQb7sFAmi+g4MCGwwFCQWjmoAACgkQO4Z+V7AQb7sOMAEA70EL4djqmesgFthIatgAGIvREM0MaGqZYf4JU5nT6q4A/Rg4BDqNYrocIv3G2d8+UWgaJT9QmAmTFmWnm7df9vYB=8E1P",
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
config.max_fps = 240
config.animation_fps = 240

-- ================================================================================
-- Appearance
-- ================================================================================

-- Font
config.font = wezterm.font_with_fallback({ "JetbrainsMono Nerd Font Mono" })
config.font_size = 16

-- Window
config.window_background_opacity = 0.84
config.macos_window_background_blur = 50
config.window_decorations = "RESIZE"

-- Pane Management
config.inactive_pane_hsb = {
    hue = 1.0,
    saturation = 1.0,
    brightness = 0.6,
}

-- Colors
local COLOR_SCHEME = "Catppuccin Macchiato"
config.color_scheme = COLOR_SCHEME
local colors = wezterm.color.get_builtin_schemes()[COLOR_SCHEME]

-- Tab Bar
config.hide_tab_bar_if_only_one_tab = false
config.tab_bar_at_bottom = true
config.use_fancy_tab_bar = false
config.tab_and_split_indices_are_zero_based = true

-- ================================================================================
-- Key Bindings
-- ================================================================================

config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 2000 }

config.keys = {
    -- Workspace Management
    {
        key = "p",
        mods = "LEADER",
        action = wezterm.action.Multiple({
            wezterm.action_callback(function(window, pane)
                resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
                wezterm.log_info("Session state saved via workspace switcher")
            end),
            workspace_switcher.switch_workspace(),
        }),
    },
    {
        key = "f",
        mods = "LEADER",
        action = wezterm.action.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }),
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

-- Add numbered tab switching (0-9)
for i = 0, 9 do
    table.insert(config.keys, {
        key = tostring(i),
        mods = "LEADER",
        action = wezterm.action.ActivateTab(i),
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

wezterm.on("window-config-reloaded", function(window, pane)
    resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
end)

wezterm.on("gui-exit", function(window, pane)
    resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
end)

-- Workspace Switcher Events
wezterm.on("smart_workspace_switcher.workspace_switcher.created", function(window, path, label)
    local workspace_state = resurrect.workspace_state
    workspace_state.restore_workspace(resurrect.state_manager.load_state(label, "workspace"), {
        window = window,
        relative = true,
        restore_text = true,
        on_pane_restore = resurrect.tab_state.default_on_pane_restore,
    })
end)

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
        return {
            { Background = { Color = colors.tab_bar_active_tab_bg } },
            { Foreground = { Color = colors.tab_bar_active_tab_fg } },
            { Text = left_edge_text },
            { Background = { Color = colors.tab_bar_active_tab_fg } },
            { Foreground = { Color = colors.tab_bar_text } },
            { Text = title },
            { Background = { Color = colors.tab_bar_active_tab_bg } },
            { Foreground = { Color = colors.tab_bar_active_tab_fg } },
            { Text = right_edge_text },
        }
    end
end)

-- Leader Key Status Indicator
wezterm.on("update-status", function(window, _)
    local solid_left_arrow = ""
    local arrow_foreground = { Foreground = { Color = colors.arrow_foreground_leader } }
    local arrow_background = { Background = { Color = colors.arrow_background_leader } }
    local prefix = ""

    if window:leader_is_active() then
        prefix = " " .. LEADER_PREFIX

        if TAB_STYLE == "rounded" then
            solid_left_arrow = wezterm.nerdfonts.ple_right_half_circle_thick
        else
            solid_left_arrow = wezterm.nerdfonts.pl_left_hard_divider
        end

        local tabs = window:mux_window():tabs_with_info()

        if TAB_STYLE ~= "rounded" then
            for _, tab_info in ipairs(tabs) do
                if tab_info.is_active and tab_info.index == 0 then
                    arrow_background = { Foreground = { Color = colors.tab_bar_active_tab_fg } }
                    solid_left_arrow = wezterm.nerdfonts.pl_right_hard_divider
                    break
                end
            end
        end
    end

    window:set_left_status(wezterm.format({
        { Background = { Color = colors.arrow_foreground_leader } },
        { Text = prefix },
        arrow_foreground,
        arrow_background,
        { Text = solid_left_arrow },
    }))
end)

-- ================================================================================
-- Export Configuration
-- ================================================================================

return config
