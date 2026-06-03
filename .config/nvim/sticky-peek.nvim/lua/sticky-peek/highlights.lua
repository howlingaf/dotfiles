local M = {}

---@type table<string, vim.api.keyset.highlight>
local base = {
  StickyPeekNormal = { link = "NormalFloat", default = true },
  StickyPeekQuoteBar = { link = "Comment", default = true },
  StickyPeekLineNr = { link = "LineNr", default = true },
  StickyPeekModeBadge = { link = "StatusLine", default = true },
}

---@param overrides table<string, vim.api.keyset.highlight>|nil
local function apply(overrides)
  for name, spec in pairs(base) do
    vim.api.nvim_set_hl(0, name, spec)
  end
  if overrides then
    for name, spec in pairs(overrides) do
      local copy = vim.deepcopy(spec)
      copy.default = nil
      vim.api.nvim_set_hl(0, name, copy)
    end
  end
end

---@param overrides table<string, vim.api.keyset.highlight>|nil
function M.setup(overrides)
  apply(overrides)
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("StickyPeekHighlights", { clear = true }),
    callback = function() apply(overrides) end,
  })
end

return M
