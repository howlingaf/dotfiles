return {
  dir = vim.fn.stdpath 'config' .. '/sticky-peek.nvim',
  name = 'sticky-peek.nvim',
  event = 'VeryLazy',
  config = function()
    require('sticky-peek').setup {}
  end,
}
