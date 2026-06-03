return {
  'epwalsh/obsidian.nvim',
  version = '*', -- use latest release instead of latest commit
  lazy = true,
  -- Only load while editing markdown files inside the vault.
  event = {
    'BufReadPre ' .. vim.fn.expand '~' .. '/Vault/*.md',
    'BufNewFile ' .. vim.fn.expand '~' .. '/Vault/*.md',
  },
  dependencies = {
    'nvim-lua/plenary.nvim',
  },
  opts = {
    workspaces = {
      {
        name = 'personal',
        path = '~/Vault',
      },
    },
    completion = {
      nvim_cmp = true,
      min_chars = 2,
    },
  },
}
