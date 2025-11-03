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
config.max_fps = 240
config.animation_fps = 240

-- ================================================================================
-- Appearance
-- ================================================================================

-- Font
config.font = wezterm.font_with_fallback({ "JetbrainsMono Nerd Font Mono" })
config.font_size = 16

-- Window
config.window_background_opacity = 0.77
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
config.tab_and_split_indices_are_zero_based = false

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
        mods = "SUPER",
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
    resurrect.state_manager.save_state(resurrect.get_workspace_state())
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
end

-- Run the helper function every 60 seconds
wezterm.time.call_after(60, update_azure_status)

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
