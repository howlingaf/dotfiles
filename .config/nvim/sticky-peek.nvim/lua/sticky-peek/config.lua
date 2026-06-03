---@class StickyPeekKeymaps
---@field pin string|nil
---@field close string|nil
---@field close_in_pin string|nil

---@class StickyPeekConfig
---@field height_pct number fraction of editor height the pin split occupies
---@field keymaps StickyPeekKeymaps|false
---@field highlights table<string, vim.api.keyset.highlight>

local M = {}

---@type StickyPeekConfig
M.defaults = {
  height_pct = 0.25,
  keymaps = {
    pin = "<leader>sp",
    close = "<leader>sx",
    close_in_pin = "q",
  },
  highlights = {},
}

---@type StickyPeekConfig
M.options = vim.deepcopy(M.defaults)

---@param user_opts table|nil
---@return StickyPeekConfig
function M.merge(user_opts)
  user_opts = user_opts or {}
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), user_opts)
  if user_opts.keymaps == false then
    M.options.keymaps = false
  end
  return M.options
end

return M
