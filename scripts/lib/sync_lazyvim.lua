-- A headless Neovim exit alone does not prove plugin operations succeeded.
local ok, err = pcall(function()
  assert(vim.v.errmsg == "", "Startup error: " .. vim.v.errmsg)
  require("lazy").sync({ wait = true, show = false })
  local plugins = require("lazy.core.config").plugins
  assert(next(plugins), "No plugins registered")
  for name, plugin in pairs(plugins) do
    if plugin.url then
      assert(plugin._.installed, "Plugin not installed: " .. name)
    end
    for _, task in ipairs(plugin._.tasks or {}) do
      assert(not task:has_errors(), "Plugin task failed: " .. name)
    end
  end
end)
if not ok then
  vim.api.nvim_err_writeln(tostring(err))
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
