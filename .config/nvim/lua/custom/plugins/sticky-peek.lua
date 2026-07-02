return {
  dir = vim.fn.stdpath 'config' .. '/sticky-peek.nvim',
  name = 'sticky-peek.nvim',
  -- plugin/sticky-peek.lua runs setup() with defaults on load; add opts here
  -- only when overriding them.
  event = 'VeryLazy',
}
