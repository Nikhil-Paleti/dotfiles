-- Space e / Space E: the Snacks file explorer as a centered popup, the same layout as Space /,
-- with a preview of the highlighted file. It closes once you open a file or click away.
-- Inside it (list focused):
--   j/k move, l or Enter opens a file or folder, h closes a folder, Backspace goes up a folder
--   a add a file (end the name with / for a folder), r rename, m move, c copy, d delete,
--   y yank and p paste, / or i type to filter the tree by name, Esc closes
--   Space / searches the highlighted folder's contents (or the file's folder): with scout
--   when its repo is indexed, else with Snacks grep in that folder.

--- Search the folder under the cursor: scout if that repo has an index, else Snacks grep.
local function search_folder(picker, item)
  if not item then
    return
  end
  local dir = Snacks.picker.util.dir(item)
  picker:close()
  local ok, scout = pcall(require, "scout")
  if ok then
    local util = require("scout.util")
    local root = util.git_root(dir)
    if root and require("scout.daemon").indexed(root) then
      local real = util.uv.fs_realpath(dir) or dir
      if real == root then
        return scout.live({ root = root })
      elseif real:sub(1, #root + 1) == root .. "/" then
        return scout.live({ root = root, dir = real:sub(#root + 2) })
      end
    end
  end
  Snacks.picker.grep({ cwd = dir })
end

return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          explorer = {
            -- Snacks' own default picker layout: preview on the right, or below on a narrow
            -- window. The explorer's stock layout is the sidebar.
            layout = {
              preset = function()
                return vim.o.columns >= 120 and "default" or "vertical"
              end,
              preview = true,
            },
            auto_close = true,
            jump = { close = true },
            actions = { search_folder = search_folder },
            win = {
              list = {
                keys = {
                  ["<leader>/"] = { "search_folder", desc = "Search Folder (scout)" },
                },
              },
            },
          },
        },
      },
    },
  },
}
