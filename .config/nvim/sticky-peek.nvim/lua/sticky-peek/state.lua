---@class StickyPeekState
---@field buf integer|nil scratch buffer holding the snapshot
---@field win integer|nil top split window displaying the snapshot

local M = {
  buf = nil,
  win = nil,
}

---@return boolean
function M.is_active()
  return M.win ~= nil and vim.api.nvim_win_is_valid(M.win)
end

function M.reset()
  M.buf = nil
  M.win = nil
end

return M
