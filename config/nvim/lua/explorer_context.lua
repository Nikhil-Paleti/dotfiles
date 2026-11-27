-- Sticky folder names for the Snacks explorer, like nvim-treesitter-context does for code.
-- When you scroll into a folder whose own row has gone off the top, that folder and the
-- folders around it stay pinned at the top of the list, outermost first. The explorer's own
-- root row is never pinned (every row is inside it).
--
-- Snacks has no option for this, so it is a small overlay: after each list render it looks
-- at the first row under the overlay, walks up item.parent, and draws those folder rows (with
-- the explorer's own icons and indent) in a floating window over the top of the list.
-- Wired up from plugins/explorer.lua (on_show). Every Snacks call is guarded; if the
-- explorer's internals change, the overlay just stops showing.

local M = {}

-- Same cap as LazyVim's treesitter-context (max_lines = 3); the innermost folders are kept.
M.max_lines = 3

local ns = vim.api.nvim_create_namespace("explorer_context")

local function set_highlights()
  local base = vim.fn.hlexists("TreesitterContext") == 1 and "TreesitterContext" or "NormalFloat"
  vim.api.nvim_set_hl(0, "SnacksExplorerContext", { link = base, default = true })
  local bottom = vim.fn.hlexists("TreesitterContextBottom") == 1 and "TreesitterContextBottom" or nil
  if bottom then
    vim.api.nvim_set_hl(0, "SnacksExplorerContextBottom", { link = bottom, default = true })
  else
    vim.api.nvim_set_hl(0, "SnacksExplorerContextBottom", { underline = true, default = true })
  end
end

-- Folders that contain `item`, outermost first, leaving out the explorer root.
local function ancestors(item)
  local chain = {}
  local p = item and item.parent
  while p and p.parent do -- p.parent == nil means p is the root row
    table.insert(chain, 1, p)
    p = p.parent
  end
  return chain
end

-- The innermost `n` entries of `chain` (treesitter-context's trim_scope = "outer").
local function innermost(chain, n)
  return vim.list_slice(chain, #chain - n + 1, #chain)
end

-- Folders to pin for a list scrolled to `top`. With n pinned rows the first row you can
-- see is top + n, and the pinned rows are always the folders that row sits in, so the
-- header never names a folder you are not in. Pick the n where all of them fit (up to
-- `max`). Where a folder ends under the header no n fits exactly; then pin as many of the
-- innermost folders as still fit, so the header shrinks one row at a time.
local function context_for(list, max)
  local count = list:count()
  local chains = {}
  for n = 0, max do
    if list.top + n > count then
      break
    end
    local chain = ancestors(list:get(list.top + n))
    chains[n] = chain
    if math.min(#chain, max) == n then
      return innermost(chain, n)
    end
  end
  for n = max, 1, -1 do
    if chains[n] and #chains[n] >= n then
      return innermost(chains[n], n)
    end
  end
  return {}
end

---@param state {win?: integer, buf?: integer}
local function close(state)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    pcall(vim.api.nvim_win_close, state.win, true)
  end
  state.win = nil
end

local function update(picker, state)
  local list = picker.list
  local lwin = list and list.win and list.win.win
  if not (lwin and vim.api.nvim_win_is_valid(lwin)) or list.top <= 1 then
    return close(state)
  end

  -- Never cover the cursor row: pin at most the rows between the top and the cursor.
  local max = math.min(M.max_lines, (list.cursor or list.top) - list.top, vim.api.nvim_win_get_height(lwin) - 1)
  local chain = max > 0 and context_for(list, max) or {}
  if #chain == 0 then
    return close(state)
  end

  local lines, marks = {}, {}
  for i, item in ipairs(chain) do
    local text, extmarks = list:format(item)
    lines[i] = (text:gsub("\n", " "))
    marks[i] = extmarks
  end

  if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
    state.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[state.buf].bufhidden = "wipe"
  end
  local buf = state.buf
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for row, extmarks in ipairs(marks) do
    for _, em in ipairs(extmarks) do
      local col = em.col
      local opts = vim.deepcopy(em)
      opts.col, opts.row, opts.field = nil, nil, nil
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, row - 1, col, opts)
    end
  end
  pcall(vim.api.nvim_buf_set_extmark, buf, ns, #lines - 1, 0, {
    line_hl_group = "SnacksExplorerContextBottom",
    priority = 1,
  })

  local lcfg = vim.api.nvim_win_get_config(lwin)
  local cfg = {
    relative = "win",
    win = lwin,
    row = 0,
    col = 0,
    width = vim.api.nvim_win_get_width(lwin),
    height = #lines,
    focusable = false,
    style = "minimal",
    border = "none",
    zindex = (lcfg.zindex or 50) + 1,
  }
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_set_config(state.win, cfg)
  else
    cfg.noautocmd = true
    state.win = vim.api.nvim_open_win(buf, false, cfg)
    vim.wo[state.win].winhighlight = "Normal:SnacksExplorerContext"
    vim.wo[state.win].wrap = false
  end
end

--- Attach to an explorer picker (call from the source's on_show).
function M.attach(picker)
  local list = picker and picker.list
  if not (list and type(list.render) == "function" and type(list.get) == "function") then
    return
  end
  if list._explorer_context then
    return
  end
  set_highlights()
  local state = {}
  list._explorer_context = state
  local render = list.render
  list.render = function(self, ...)
    local ret = { render(self, ...) }
    local ok = pcall(update, picker, state)
    if not ok then
      pcall(close, state)
    end
    return unpack(ret)
  end

  local group = vim.api.nvim_create_augroup("explorer_context_" .. tostring(state):gsub("%W", ""), { clear = true })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(ev)
      local lwin = list.win and list.win.win
      if not lwin or tonumber(ev.match) == lwin or not vim.api.nvim_win_is_valid(lwin) then
        close(state)
        pcall(vim.api.nvim_del_augroup_by_id, group)
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "WinResized", "ColorScheme" }, {
    group = group,
    callback = function(ev)
      if ev.event == "ColorScheme" then
        set_highlights()
      end
      pcall(update, picker, state)
    end,
  })
end

M._context_for = context_for -- for .github/ci/smoke.sh

return M
