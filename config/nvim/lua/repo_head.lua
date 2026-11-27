-- Status bar repo text: jj's nearest bookmark at or below @ plus @'s change ID, or git's branch
-- plus short commit. Fetched in the background on the events below, never on redraw (jj with
-- --ignore-working-copy, so it never snapshots or locks). :BranchRefresh refetches now.
local M = {}

-- Shared with the start screen.
M.jj_bookmark_revset = "latest(::@ & bookmarks())"
M.jj_bookmark_template = 'local_bookmarks.map(|b| b.name()).join(" ")'

-- Events that refetch. Add or drop any autocommand event here (:h autocmd-events).
local refresh_events = {
  "BufWritePost", -- you saved a file
  "FileChangedShellPost", -- a file changed on disk and Neovim reloaded it
  "ShellCmdPost", -- a :! command finished, such as :!jj new
  "TermClose", -- a terminal closed, such as lazygit or jj in :terminal
  "TermLeave", -- you left terminal mode
  "DirChanged", -- :cd to another folder
  "FocusGained", -- you came back from another window, where jj or git may have run
}
-- Switching buffers also refetches (another buffer may be in another repo), at most once per
-- this many milliseconds per repo.
local buffer_switch_gap_ms = 1000

-- Nerd Font icons, written as bytes so editors and tools can't drop them: 󰘬 (U+F062C, as on
-- the start screen) for jj, and lualine's branch icon (U+E0A0) for git.
M.jj_icon = "\243\176\152\172 "
M.git_icon = "\238\130\160 "

local uv = vim.uv or vim.loop
local roots = {} -- folder -> repo root, or false when the folder is in no repo
local repos = {} -- repo root -> { text, dirty, running, last_run }
local has_jj

local function repo_root(dir)
  local root = roots[dir]
  if root == nil then
    local marker = vim.fs.find({ ".jj", ".git" }, { path = dir, upward = true, limit = 1 })[1]
    root = marker and vim.fs.dirname(marker) or false
    roots[dir] = root
  end
  return root
end

-- The current buffer's folder, or the working directory for terminals, pickers and the like.
local function current_dir()
  local name = vim.bo.buftype == "" and vim.api.nvim_buf_get_name(0) or ""
  if name ~= "" then
    return vim.fs.dirname(name)
  end
  return vim.fn.getcwd()
end

local function redraw()
  local ok, lualine = pcall(require, "lualine")
  if ok then
    lualine.refresh({ place = { "statusline" } })
  else
    vim.cmd.redrawstatus()
  end
end

-- Run both commands at once in `root`; call done(first_line_a, first_line_b) once both exit.
local function run_pair(root, cmd_a, cmd_b, done)
  local out, left = {}, 2
  local function finish(i)
    return function(res)
      out[i] = res.code == 0 and vim.trim(res.stdout or ""):match("^[^\n]*") or ""
      left = left - 1
      if left == 0 then
        vim.schedule(function()
          done(out[1], out[2])
        end)
      end
    end
  end
  for i, cmd in ipairs({ cmd_a, cmd_b }) do
    local ok = pcall(vim.system, cmd, { cwd = root, text = true }, finish(i))
    if not ok then
      finish(i)({ code = 1 })
    end
  end
end

local function fetch(root, done)
  if has_jj == nil then
    has_jj = vim.fn.executable("jj") == 1
  end
  if has_jj and uv.fs_stat(root .. "/.jj") then
    local jj = { "jj", "log", "--no-graph", "--no-pager", "--ignore-working-copy", "--color", "never", "-r" }
    local bookmark = vim.list_extend(vim.deepcopy(jj), { M.jj_bookmark_revset, "-T", M.jj_bookmark_template })
    local change = vim.list_extend(vim.deepcopy(jj), { "@", "-T", "change_id.shortest(8)" })
    run_pair(root, bookmark, change, function(name, id)
      done((name ~= "" or id ~= "") and M.jj_icon .. vim.trim(name .. " " .. id) or "")
    end)
  else
    local git = { "git", "--no-optional-locks" }
    local branch = vim.list_extend(vim.deepcopy(git), { "branch", "--show-current" })
    local commit = vim.list_extend(vim.deepcopy(git), { "rev-parse", "--short=6", "HEAD" })
    run_pair(root, branch, commit, function(name, id)
      done((name ~= "" or id ~= "") and M.git_icon .. vim.trim(name .. " " .. id) or "")
    end)
  end
end

local function refresh(root)
  local repo = repos[root]
  if repo.running then
    return -- a change while it runs leaves it dirty, so it runs once more after
  end
  repo.running, repo.dirty, repo.last_run = true, false, uv.now()
  fetch(root, function(text)
    repo.running = false
    local changed = text ~= repo.text
    repo.text = text
    if repo.dirty then
      refresh(root)
    elseif changed then
      redraw()
    end
  end)
end

-- Status bar text for the current buffer's repo; "" outside one. Never blocks.
function M.get()
  local root = repo_root(current_dir())
  if not root then
    return ""
  end
  local repo = repos[root]
  if not repo then
    repo = { text = "", dirty = true }
    repos[root] = repo
  end
  if repo.dirty and not repo.running then
    vim.schedule(function()
      refresh(root)
    end)
  end
  return repo.text
end

-- Mark every repo as stale and forget which folder is in which repo (one may have been created
-- or removed); the repo on screen refetches right away.
local function invalidate()
  roots = {}
  for _, repo in pairs(repos) do
    repo.dirty = true
  end
  M.get()
end

function M.setup()
  if M._setup then
    return
  end
  M._setup = true
  local group = vim.api.nvim_create_augroup("repo_head", { clear = true })
  vim.api.nvim_create_autocmd(refresh_events, { group = group, callback = invalidate })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function()
      local root = repo_root(current_dir())
      local repo = root and repos[root]
      if repo and uv.now() - (repo.last_run or 0) >= buffer_switch_gap_ms then
        repo.dirty = true
      end
      M.get()
    end,
  })
  vim.api.nvim_create_user_command("BranchRefresh", invalidate, { desc = "Refetch the branch in the status bar" })
end

return M
