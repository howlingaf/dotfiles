local config = require("sticky-peek.config")

local M = {}

---@type { mode: string, lhs: string }[]
local active_global_keymaps = {}

---@param api { pin: fun(), close: fun(), toggle: fun() }
function M.setup(api)
  vim.api.nvim_create_user_command("StickyPeekPin", function()
    api.pin()
  end, { desc = "Snapshot the current buffer into the sticky-peek split" })

  vim.api.nvim_create_user_command("StickyPeekClose", function()
    api.close()
  end, { desc = "Close the active sticky-peek pin" })

  vim.api.nvim_create_user_command("StickyPeekToggle", function()
    api.toggle()
  end, { desc = "Toggle the sticky-peek pin (pin if absent, close if present)" })

  -- Tear down any keymaps from a prior setup() call so changing config doesn't
  -- leave orphaned mappings.
  for _, km in ipairs(active_global_keymaps) do
    pcall(vim.keymap.del, km.mode, km.lhs)
  end
  active_global_keymaps = {}

  local km = config.options.keymaps
  if not km then return end

  if km.pin and km.pin ~= "" then
    vim.keymap.set("n", km.pin, "<cmd>StickyPeekToggle<CR>", {
      silent = true,
      desc = "sticky-peek: toggle pin",
    })
    table.insert(active_global_keymaps, { mode = "n", lhs = km.pin })
  end

  if km.close and km.close ~= "" then
    vim.keymap.set("n", km.close, "<cmd>StickyPeekClose<CR>", {
      silent = true,
      desc = "sticky-peek: close pin",
    })
    table.insert(active_global_keymaps, { mode = "n", lhs = km.close })
  end
end

return M
