-- Start screen: a pixel-art landscape picked at random each time Neovim starts (see
-- lua/scenes/), this folder's recent files, and the repo's status with its bookmark (jj) or
-- branch (git).

-- One landscape and variation per Neovim session, so resizing keeps the same picture.
-- Set vim.g.dashboard_scene to a name from lua/scenes/init.lua to always show that one.
math.randomseed(vim.uv.hrtime())
local scene_names = require("scenes").names
local scene_name = scene_names[math.random(#scene_names)]
local scene_seed = math.random(1, 100000)

-- The scene is drawn with "▀" (upper half block): each character cell shows two pixels, the
-- top one as the text color and the bottom one as the background color.
local pixel_hl = {} -- "rrggbb_rrggbb" -> highlight group name, created on first use

local function hl_for(top, bottom)
  local key = string.format("%02x%02x%02x_%02x%02x%02x", top[1], top[2], top[3], bottom[1], bottom[2], bottom[3])
  local name = pixel_hl[key]
  if not name then
    name = "DashboardPixel_" .. key
    vim.api.nvim_set_hl(0, name, {
      fg = string.format("#%02x%02x%02x", top[1], top[2], top[3]),
      bg = string.format("#%02x%02x%02x", bottom[1], bottom[2], bottom[3]),
    })
    pixel_hl[key] = name
  end
  return name
end
-- A colorscheme change clears highlight groups; recreate them on the next draw.
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    pixel_hl = {}
  end,
})

-- Render the scene at `cols` x `rows` cells and turn it into dashboard lines, merging runs of
-- cells with the same pair of colors.
local function scene_lines(cols, rows)
  local px = require("scenes").render(vim.g.dashboard_scene or scene_name, cols, rows * 2, scene_seed)
  local lines = {}
  for r = 0, rows - 1 do
    local chunks, run, run_hl = {}, "", nil
    for x = 0, cols - 1 do
      local hl = hl_for(px[2 * r][x], px[2 * r + 1][x])
      if hl ~= run_hl and run ~= "" then
        chunks[#chunks + 1] = { run, hl = run_hl }
        run = ""
      end
      run, run_hl = run .. "▀", hl
    end
    chunks[#chunks + 1] = { run, hl = run_hl }
    lines[#lines + 1] = { text = chunks, align = "center", padding = r == rows - 1 and 1 or 0 }
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
