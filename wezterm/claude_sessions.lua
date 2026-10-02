-- ================================================================================
-- Claude Code session picker
-- ================================================================================
--
-- Shows a fuzzy list of Claude Code sessions, like `claude --resume`.
-- The list starts with the sessions of the current project. The first entry
-- shows the sessions of all projects.
-- The selected session opens in a new tab with `claude --resume <id>`.
--
-- Claude Code stores one session per file:
--   ~/.claude/projects/<encoded cwd>/<session id>.jsonl
-- Each line is one JSON record. The picker reads these records:
--   agent-name / custom-title  name set with /rename
--   ai-title                   title that Claude Code generates
--   summary                    summary from older Claude Code versions
--   user                       first typed prompt, used when no title exists
-- Files can be several MB. Parsed metadata is cached by file mtime and size,
-- so a file is read again only after it changes.

local wezterm = require("wezterm")
local act = wezterm.action

local M = {}

M.opts = {
    projects_dir = wezterm.home_dir .. "/.claude/projects",
    claude_path = "claude",
    -- Shell that runs claude. The tab keeps this shell after claude exits.
    shell = "/opt/homebrew/bin/fish",
    -- Maximum number of characters of the title in a list entry.
    title_width = 70,
}

local CACHE_VERSION = 1

-- ================================================================================
-- Helpers
-- ================================================================================

local function tilde(path)
    if path:sub(1, #wezterm.home_dir) == wezterm.home_dir then
        return "~" .. path:sub(#wezterm.home_dir + 1)
    end
    return path
end

local function untilde(path)
    if path:sub(1, 1) == "~" then
        return wezterm.home_dir .. path:sub(2)
    end
    return path
end

local function is_dir(path)
    return path ~= nil and pcall(wezterm.read_dir, path)
end

local function shell_quote(text)
    return "'" .. text:gsub("'", "'\\''") .. "'"
end

local function one_line(text)
    return (text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

local function truncate(text, width)
    if utf8.len(text) and utf8.len(text) > width then
        return wezterm.truncate_right(text, width - 1) .. "…"
    end
    return text
end

local function age(mtime)
    local seconds = os.time() - mtime
    if seconds < 3600 then
        return string.format("%dm", math.max(1, seconds // 60))
    elseif seconds < 86400 then
        return string.format("%dh", seconds // 3600)
    elseif seconds < 86400 * 30 then
        return string.format("%dd", seconds // 86400)
    end
    return os.date("%d.%m.%y", mtime)
end

local function parse(line, field)
    local ok, record = pcall(wezterm.json_parse, line)
    if ok and type(record) == "table" then
        return record[field]
    end
    return nil
end

-- ================================================================================
-- Session file parsing
-- ================================================================================

-- Returns the text of a typed user prompt, or nil for tool results, slash
-- commands, and other records that the user did not type.
local function typed_prompt(line)
    local message = parse(line, "message")
    if type(message) ~= "table" then
        return nil
    end

    local content = message.content
    if type(content) == "table" then
        for _, block in ipairs(content) do
            if type(block) == "table" and block.type == "text" then
                content = block.text
                break
            end
        end
    end

    if type(content) ~= "string" or content == "" then
        return nil
    end
    -- Slash commands, command output, and system notes start with a tag.
    if content:sub(1, 1) == "<" or content:sub(1, 7) == "Caveat:" then
        return nil
    end
    return content
end

-- Reads one session file. Returns nil if the file is not an interactive
-- session, for example an SDK session or a session without a prompt.
local function read_session(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end
    local content = file:read("a")
    file:close()

    -- Background SDK sessions use the entrypoint "sdk-cli".
    if not content:find('"entrypoint":"cli"', 1, true) then
        return nil
    end

    local session = {
        cwd = content:match('"cwd":"([^"]*)"'),
        branch = content:match('"gitBranch":"([^"]*)"'),
    }

    -- Only the last title record of each kind is used, so keep the raw line
    -- and parse it after the loop.
    local name_line, ai_title_line, summary_line, prompt

    for line in content:gmatch("[^\n]+") do
        local head = line:sub(1, 24)
        if head:find('^{"type":"agent%-name"') or head:find('^{"type":"custom%-title"') then
            name_line = line
        elseif head:find('^{"type":"ai%-title"') then
            ai_title_line = line
        elseif head:find('^{"type":"summary"') then
            summary_line = line
        elseif not prompt and line:find('"type":"user","message":{"role":"user"', 1, true) then
            prompt = typed_prompt(line)
        end
    end

    session.title = (name_line and (parse(name_line, "agentName") or parse(name_line, "customTitle")))
        or (ai_title_line and parse(ai_title_line, "aiTitle"))
        or (summary_line and parse(summary_line, "summary"))
        or prompt

    if not session.cwd or not session.title then
        return nil
    end
    session.title = one_line(session.title)
    return session
end

-- Returns { path = { mtime, size } } for all session files.
-- Subagent transcripts are in deeper directories, so maxdepth 2 skips them.
local function list_session_files()
    local ok, stdout = wezterm.run_child_process({
        "/usr/bin/find", M.opts.projects_dir,
        "-mindepth", "2", "-maxdepth", "2",
        "-name", "*.jsonl",
        "-exec", "/usr/bin/stat", "-f", "%m %z %N", "{}", "+",
    })

    local files = {}
    if not ok then
        return files
    end
    for mtime, size, path in stdout:gmatch("(%d+) (%d+) ([^\n]+)") do
        files[path] = { mtime = tonumber(mtime), size = tonumber(size) }
    end
    return files
end

-- Returns all sessions, newest first.
-- wezterm.GLOBAL keeps the cache through a config reload.
local function load_sessions()
    local old = wezterm.GLOBAL.claude_sessions_cache
    if not old or old.version ~= CACHE_VERSION then
        old = { version = CACHE_VERSION, entries = {} }
    end

    local cache = { version = CACHE_VERSION, entries = {} }
    local sessions = {}

    for path, stat in pairs(list_session_files()) do
        local entry = old.entries[path]
        if not entry or entry.mtime ~= stat.mtime or entry.size ~= stat.size then
            -- An empty session marks a file without an interactive session, so
            -- the file is not read again until it changes.
            entry = { mtime = stat.mtime, size = stat.size, session = read_session(path) or {} }
        end
        cache.entries[path] = entry

        if entry.session.cwd then
            table.insert(sessions, {
                id = path:match("([^/]+)%.jsonl$"),
                cwd = entry.session.cwd,
                branch = entry.session.branch,
                title = entry.session.title,
                mtime = entry.mtime,
            })
        end
    end

    wezterm.GLOBAL.claude_sessions_cache = cache
    table.sort(sessions, function(a, b)
        return a.mtime > b.mtime
    end)
    return sessions
end

-- ================================================================================
-- Project scope
-- ================================================================================

-- Returns the project directory of the active workspace.
-- smart_workspace_switcher names a workspace after its directory, for example
-- "~/Projects/norsake". For other workspaces, the cwd of the pane is used.
local function project_root(window, pane)
    local workspace = untilde(window:active_workspace())
    if workspace:sub(1, 1) == "/" and is_dir(workspace) then
        return (workspace:gsub("/$", ""))
    end

    local cwd = pane:get_current_working_dir()
    if cwd and cwd.file_path then
        return (cwd.file_path:gsub("/$", ""))
    end
    return nil
end

-- A session belongs to the project if it started in the project directory or
-- in a subdirectory, for example a worktree.
local function in_project(session, root)
    return session.cwd == root or session.cwd:sub(1, #root + 1) == root .. "/"
end

-- ================================================================================
-- Picker
-- ================================================================================

local SHOW_ALL = "show-all"

local function format_choice(session, show_path)
    local elements = {
        { Foreground = { AnsiColor = "Grey" } },
        { Text = string.format("%8s  ", age(session.mtime)) },
        "ResetAttributes",
        { Text = truncate(session.title, M.opts.title_width) },
    }
    if show_path then
        table.insert(elements, { Foreground = { AnsiColor = "Blue" } })
        table.insert(elements, { Text = "  " .. tilde(session.cwd) })
    end
    if session.branch and session.branch ~= "" and session.branch ~= "HEAD" then
        table.insert(elements, { Foreground = { AnsiColor = "Green" } })
        table.insert(elements, { Text = "  " .. wezterm.nerdfonts.dev_git_branch .. " " .. session.branch })
    end
    return wezterm.format(elements)
end

local function resume(window, pane, session)
    local cwd = session.cwd
    if not is_dir(cwd) then
        window:toast_notification("Claude sessions", "Directory not found: " .. cwd .. ". Using home directory.", nil, 4000)
        cwd = wezterm.home_dir
    end

    local command = M.opts.claude_path .. " --resume " .. shell_quote(session.id)
        .. "; exec " .. shell_quote(M.opts.shell)

    window:perform_action(
        act.SpawnCommandInNewTab({
            cwd = cwd,
            args = { M.opts.shell, "-l", "-c", command },
        }),
        pane
    )
end

local function show(window, pane, all)
    local sessions = load_sessions()
    local root = project_root(window, pane)

    local scoped = {}
    if not all and root then
        for _, session in ipairs(sessions) do
            if in_project(session, root) then
                table.insert(scoped, session)
            end
        end
    end
    -- Show all projects if the current project has no sessions.
    if #scoped == 0 then
        all = true
        scoped = sessions
    end

    local by_id = {}
    local choices = {}
    if not all then
        table.insert(choices, {
            id = SHOW_ALL,
            label = wezterm.format({
                { Foreground = { AnsiColor = "Yellow" } },
                { Text = string.format("%8s  Show all projects (%d sessions)", "", #sessions) },
            }),
        })
    end
    for _, session in ipairs(scoped) do
        by_id[session.id] = session
        table.insert(choices, { id = session.id, label = format_choice(session, all) })
    end

    local scope = all and "all projects" or tilde(root)
    window:perform_action(
        act.InputSelector({
            title = "Claude sessions: " .. scope,
            fuzzy = true,
            fuzzy_description = "Claude session (" .. scope .. "): ",
            choices = choices,
            action = wezterm.action_callback(function(inner_window, inner_pane, id)
                if id == SHOW_ALL then
                    show(inner_window, inner_pane, true)
                elseif id and by_id[id] then
                    resume(inner_window, inner_pane, by_id[id])
                end
            end),
        }),
        pane
    )
end

-- Returns the action for a key binding.
function M.pick()
    return wezterm.action_callback(function(window, pane)
        show(window, pane, false)
    end)
end

return M
