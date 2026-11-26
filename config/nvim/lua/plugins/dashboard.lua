-- Start screen: mountains under a night sky over a moonlit lake, this folder's recent
-- files, and the repo's status with its bookmark (jj) or branch (git).

-- Large scene: only for very large windows.
local art_large = {
  "      .            *                  .                  *          .",
  "  *          .              .                    ☾               .",
  "                 .                  *                      .           *",
  "         .                .                .         *",
  "              /\\                                          /\\",
  "             /  \\                  /\\                    /  \\",
  "            /    \\        /\\      /  \\        /\\        /    \\",
  "           /      \\      /  \\    /    \\      /  \\      /      \\",
  "          /        \\    /    \\  /      \\    /    \\    /        \\",
  "  _______/          \\__/      \\/        \\__/      \\__/          \\__________",
  "  ~    ~     ~   ~       ~    ~     ~       ~    ☾    ~     ~     ~   ~",
  "     ~    ~        ~   ~     ~    ~    ~      ~       ~   ~        ~      ~",
  "  ~     ~    ~  ~        ~       ~     ~   ~      ~        ~    ~     ~",
}

-- Medium scene: the usual size.
local art_medium = {
  "     .          *              .               *        .",
  "  *        .             .              ☾            .",
  "              .               *                .          *",
  "           /\\                                    /\\",
  "          /  \\             /\\                   /  \\",
  "         /    \\      /\\   /  \\      /\\         /    \\",
  "  ______/      \\____/  \\_/    \\____/  \\_______/      \\______",
  "  ~   ~    ~  ~     ~    ~   ~     ~    ☾   ~    ~   ~    ~",
  "     ~   ~      ~    ~     ~    ~    ~     ~    ~      ~",
}

-- Small scene for narrow or short windows.
local art_small = {
  "      .        *          .            *      ",
  "            *          .        *        ☾    ",
  "       /\\        /\\                 .        ",
  "      /  \\  /\\  /  \\      /\\                 ",
  "   __/    \\/  \\/    \\____/  \\________________",
  "   ~  ~ ~   ~    ~  ~  ~   ~  ~ ~  ~  ~  ☾ ~  ",
  "     ~   ~   ~   ~     ~   ~    ~    ~    ~  ",
}

-- Each character class gets its own color; spaces take no color.
local char_hl = {
  ["*"] = "DashboardStar",
  ["."] = "DashboardStar",
  ["☾"] = "DashboardMoon",
  ["/"] = "DashboardMountain",
  ["\\"] = "DashboardMountain",
  ["_"] = "DashboardMountain",
  ["~"] = "DashboardWater",
}

local function set_colors()
  local hl = vim.api.nvim_set_hl
  hl(0, "DashboardStar", { fg = "#f2f4f8" })
  hl(0, "DashboardMoon", { fg = "#ffd866" })
  hl(0, "DashboardMountain", { fg = "#6b7a99" })
  hl(0, "DashboardWater", { fg = "#2a6f9e" })
end
set_colors()
vim.api.nvim_create_autocmd("ColorScheme", { callback = set_colors })

-- One dashboard line per art line, split into runs of same-colored characters.
local function header_lines(art)
  -- Pad every line to the same width, so centering keeps the columns lined up.
  local width = 0
  for _, line in ipairs(art) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  local lines = {}
  for i, line in ipairs(art) do
    line = line .. string.rep(" ", width - vim.fn.strdisplaywidth(line))
    local chunks, run, run_hl = {}, "", nil
    for _, ch in ipairs(vim.fn.split(line, "\\zs")) do
      local hl = char_hl[ch] or run_hl -- spaces join whatever run they're in
      if hl ~= run_hl and run ~= "" then
        chunks[#chunks + 1] = { run, hl = run_hl }
        run = ""
      end
      run, run_hl = run .. ch, hl
    end
    chunks[#chunks + 1] = { run, hl = run_hl }
    lines[#lines + 1] = { text = chunks, align = "center", padding = i == #art and 1 or 0 }
  end
  return lines
end

-- jj: the nearest bookmark at or below the working copy, then `jj st`.
-- git: the current branch, then the short status.
local repo_status_cmd = [[
if jj root >/dev/null 2>&1; then
  b=$(jj log --no-graph --no-pager --color never -r 'latest(::@ & bookmarks())' -T 'local_bookmarks.map(|b| b.name()).join(" ")' 2>/dev/null)
  printf '\033[35m󰘬 %s\033[0m\n\n' "${b:-no bookmark}"
  jj st --no-pager
else
  printf '\033[35m %s\033[0m\n\n' "$(git branch --show-current)"
  git status --short --renames
fi
# Stay alive (quietly) so the terminal never prints "[Process exited 0]" under short output.
exec sleep infinity
]]

-- Called on every redraw (snacks redraws on resize), so the art follows the window size.
-- It also sets the dashboard's column width to fit the chosen art.
local function header(dashboard)
  local size = dashboard._size or { width = vim.o.columns, height = vim.o.lines }
  local art
  if size.width >= 200 and size.height >= 55 then
    art = art_large
  elseif size.width >= 70 and size.height >= 30 then
    art = art_medium
  elseif size.width >= 50 then
    art = art_small
  end
  dashboard.opts.width = art == art_large and 76 or 62 -- snacks default: 60
  return art and header_lines(art) or {}
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
          { pane = 2, section = "recent_files", cwd = true, limit = 8, indent = 2, padding = 1 },
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
