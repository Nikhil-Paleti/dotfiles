local M = {}

function M.get()
  local column = LazyVim.statuscolumn()
  local win = vim.g.statusline_winid
  if vim.v.virtnum ~= 0 or not (vim.wo[win].number and vim.wo[win].relativenumber) then
    return column
  end

  local buf = vim.api.nvim_win_get_buf(win)
  local width = math.max(vim.wo[win].numberwidth - 1, #tostring(vim.api.nvim_buf_line_count(buf)))
  local numbers = ("%" .. width .. "d %" .. width .. "d "):format(vim.v.lnum, vim.v.relnum)
  -- Preserve Snacks' signs, folds, highlights and click handlers; leave unfamiliar formats unchanged.
  return (column:gsub("%%=%d+ ", function()
    return "%=" .. numbers
  end, 1))
end

return M
