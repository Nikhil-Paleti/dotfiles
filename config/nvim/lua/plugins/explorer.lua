-- Space e / Space E: the Snacks file explorer as a centered popup, the same layout as Space /,
-- with a preview of the highlighted file. It closes once you open a file or click away.
-- Inside it (list focused):
--   j/k move, l or Enter opens a file or folder, h closes a folder, Backspace goes up a folder
--   a add a file (end the name with / for a folder), r rename, m move, c copy, d delete,
--   y yank and p paste, / or i type to filter the tree by name, Esc closes
--   Space / searches the highlighted folder's contents (or the file's folder). scout takes this
--   key over in indexed repos (see plugins/scout.lua); elsewhere it is Snacks grep in that folder.
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
          },
        },
      },
    },
  },
}
