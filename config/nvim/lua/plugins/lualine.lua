-- Status bar: in place of LazyVim's "branch" (which shows only a commit hash in jj repos, where
-- git is always detached), show the jj bookmark or git branch with the commit. See
-- lua/repo_head.lua for what it shows and when it refreshes (:BranchRefresh refreshes now).
return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      local head = require("repo_head")
      head.setup()
      local component = { head.get }
      local section = opts.sections.lualine_b
      for i, c in ipairs(section) do
        if c == "branch" or (type(c) == "table" and c[1] == "branch") then
          section[i] = component
          return
        end
      end
      table.insert(section, 1, component)
    end,
  },
}
