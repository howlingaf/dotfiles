local config = require("sticky-peek.config")

local M = {}

-- statuscolumn: left-edge quote bar in the configured purple, then a right-aligned
-- line number in the dimmed group, then a trailing space for breathing room.
local STATUSCOLUMN = "%#StickyPeekQuoteBar#▎%#StickyPeekLineNr#%=%l "

---@param rows integer
---@return integer
local function compute_height(rows)
  return math.max(3, math.floor(rows * config.options.height_pct))
end

---Open `buf` in a horizontal split anchored at the absolute top of the tabpage,
---configure its window-local options for the read-only-reference look, and
---restore focus to the source window.
---@param buf integer
---@return integer pin_win
function M.open(buf)
  local source_win = vim.api.nvim_get_current_win()

  -- topleft anchors the split at the top of the entire tabpage layout, not
  -- merely above the current window. sbuffer skips the empty-buffer-then-swap
  -- dance that plain `:split` would require.
  vim.cmd("noautocmd topleft sbuffer " .. buf)
  local pin_win = vim.api.nvim_get_current_win()

  vim.api.nvim_win_set_height(pin_win, compute_height(vim.o.lines))

  vim.wo[pin_win].winhighlight = table.concat({
    "Normal:StickyPeekNormal",
    "NormalNC:StickyPeekNormal",
    "SignColumn:StickyPeekNormal",
    "LineNr:StickyPeekLineNr",
    "CursorLineNr:StickyPeekLineNr",
    "EndOfBuffer:StickyPeekNormal",
    -- Mode badges in this window's statusline use the pin's purple so the
    -- bottom bar reinforces the "read-only context" cue.
    "MiniStatuslineModeNormal:StickyPeekModeBadge",
    "MiniStatuslineModeInsert:StickyPeekModeBadge",
    "MiniStatuslineModeVisual:StickyPeekModeBadge",
    "MiniStatuslineModeReplace:StickyPeekModeBadge",
    "MiniStatuslineModeCommand:StickyPeekModeBadge",
    "MiniStatuslineModeOther:StickyPeekModeBadge",
  }, ",")
  vim.wo[pin_win].statuscolumn = STATUSCOLUMN
  vim.wo[pin_win].signcolumn = "no"
  vim.wo[pin_win].cursorline = false
  vim.wo[pin_win].colorcolumn = ""
  vim.wo[pin_win].number = true
  vim.wo[pin_win].relativenumber = false
  vim.wo[pin_win].wrap = false
  vim.wo[pin_win].winfixheight = true

  if vim.fn.has("nvim-0.10") == 1 then
    pcall(function() vim.wo[pin_win].winfixbuf = true end)
  end

  vim.api.nvim_set_current_win(source_win)

  return pin_win
end

---@param win integer
function M.resize(win)
  if not vim.api.nvim_win_is_valid(win) then return end
  vim.api.nvim_win_set_height(win, compute_height(vim.o.lines))
end

---@param win integer|nil
function M.close(win)
  if win and vim.api.nvim_win_is_valid(win) then
    pcall(vim.api.nvim_win_close, win, true)
  end
end

return M
