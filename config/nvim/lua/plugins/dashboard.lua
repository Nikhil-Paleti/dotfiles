-- Start screen: a pixel-art landscape from scenery (github.com/Nikhil-Paleti/scenery), picked at
-- random each time Neovim starts, this folder's recent files, and the repo's status with its
-- bookmark (jj) or branch (git).

-- One landscape and variation per Neovim session, picked on the first draw, so resizing keeps
-- the same picture. Set vim.g.dashboard_scene to a name from require("scenery").names to always
-- show that one.
math.randomseed(vim.uv.hrtime())
local scene_name, scene_seed

-- Render the scene at `cols` x `rows` cells as dashboard lines. Without scenery (not installed
-- yet, or offline on first start) the header is left empty.
local function scene_lines(cols, rows)
  local ok, scenery = pcall(require, "scenery")
  if not ok then
    return {}
  end
  if not scene_name then
    scene_name = scenery.names[math.random(#scenery.names)]
    scene_seed = math.random(1, 100000)
  end
  local lines = {}
  for r, row in ipairs(scenery.lines(vim.g.dashboard_scene or scene_name, cols, rows, scene_seed)) do
    local text = {}
    for i, chunk in ipairs(row) do
      text[i] = { chunk[1], hl = chunk[2] }
    end
    lines[r] = { text = text, align = "center", padding = r == rows and 1 or 0 }
  end
  return lines
end

-- jj: the nearest bookmark at or below the working copy (the same lookup as the status bar, in
-- lua/repo_head.lua), then `jj st`. git: the current branch, then the short status.
local head = require("repo_head")
local bookmark_revset = vim.fn.shellescape(head.jj_bookmark_revset)
local bookmark_template = vim.fn.shellescape(head.jj_bookmark_template)
local repo_status_cmd = [[
if jj root >/dev/null 2>&1; then
  b=$(jj log --no-graph --no-pager --color never -r ]] .. bookmark_revset .. [[ -T ]] .. bookmark_template .. [[ 2>/dev/null)
  printf '\033[35m]] .. head.jj_icon .. [[%s\033[0m\n\n' "${b:-no bookmark}"
  jj st --no-pager
else
  printf '\033[35m]] .. head.git_icon .. [[%s\033[0m\n\n' "$(git branch --show-current)"
  git status --short --renames
fi
# Stay alive (quietly) so the terminal never prints "[Process exited 0]" under short output.
exec sleep infinity
]]

-- Called on every redraw (snacks redraws on resize), so the scene follows the window size.
-- It also sets the dashboard's column width to fit the scene.
local function header(dashboard)
  local size = dashboard._size or { width = vim.o.columns, height = vim.o.lines }
  if size.width < 40 or size.height < 20 then
    return {}
  end
  local cols = math.min(76, size.width - 4)
  local rows = math.max(8, math.min(16, math.floor(size.height * 0.32)))
  dashboard.opts.width = math.max(cols, 60) -- snacks default: 60
  return scene_lines(cols, rows)
end

-- Recent Files: this folder's open buffers first (most recently used first), then files from
-- earlier sessions, 8 in all with no repeats. vim.v.oldfiles is only read at startup, so without
-- the buffers, files opened this session would never show. Rebuilt on every open and redraw.
local recent_limit = 8

-- Order buffers by when they were last entered (buffer info's `lastused` is only to the second).
local entered, tick = {}, 0
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function(ev)
    tick = tick + 1
    entered[ev.buf] = tick
  end,
})

local function in_dir(file, root)
  return file:sub(1, #root) == root and file:sub(#root + 1, #root + 1):find("[/\\]") ~= nil
end

local function recent_files()
  local root = vim.fs.normalize(vim.fn.getcwd())
  local items, seen = {}, {}
  local function add(file)
    if seen[file] or #items >= recent_limit then
      return
    end
    seen[file] = true
    items[#items + 1] = { file = file, icon = "file", action = ":e " .. vim.fn.fnameescape(file), autokey = true }
  end

  local bufs = vim.fn.getbufinfo({ buflisted = 1 })
  table.sort(bufs, function(a, b)
    local ea, eb = entered[a.bufnr] or 0, entered[b.bufnr] or 0
    if ea ~= eb then
      return ea > eb
    end
    return a.lastused > b.lastused
  end)
  for _, info in ipairs(bufs) do
    local file = info.name ~= "" and vim.fs.normalize(info.name) or nil
    local stat = file and vim.bo[info.bufnr].buftype == "" and vim.uv.fs_stat(file)
    if stat and stat.type == "file" and in_dir(file, root) then
      add(file)
    end
  end
  for file in Snacks.dashboard.oldfiles({ filter = { [root] = true } }) do
    if #items >= recent_limit then
      break
    end
    add(file)
  end
  return items
end

local function in_repo()
  return Snacks.git.get_root() ~= nil
end

return {
  -- Pure Lua, so lazy.nvim installs and updates it like any other plugin. It loads on the first
  -- require("scenery") above. No lazy-lock.json entry: a fresh install takes main's latest.
  { "Nikhil-Paleti/scenery", lazy = true },
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        sections = {
          header,
          { pane = 2, icon = " ", title = "Recent Files", padding = 1 },
          { pane = 2, indent = 2, padding = 1, recent_files },
          { pane = 2, icon = " ", title = "Repo Status", padding = 1, enabled = in_repo },
          {
            pane = 2,
            section = "terminal",
            enabled = in_repo,
            -- trimmed: snacks appends "; sleep .1", which a trailing newline would break
            cmd = vim.trim(repo_status_cmd),
            height = 10,
            padding = 1,
            ttl = 0, -- always fresh (snacks only caches output of commands that exit)
            indent = 3,
          },
          { section = "startup" },
        },
      },
    },
  },
}
