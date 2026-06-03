return {
  'mfussenegger/nvim-lint',
  event = { 'BufReadPre', 'BufNewFile' },
  config = function()
    local lint = require 'lint'

    -- Configure linters by filetype
    -- Note: ESLint requires .eslintrc config in your project root to work
    lint.linters_by_ft = {
      -- JS/TS linting is now handled live by the ESLint LSP (see init.lua),
      -- inline as you type. eslint_d-on-save removed to avoid duplicates.
      -- Python linting is now handled live by the ruff LSP (see init.lua),
      -- which is faster and inline. pylint-on-save removed to avoid duplicates.
      -- lua = { 'luacheck' }, -- Disabled: lua_ls LSP provides better diagnostics
      -- markdown = { 'markdownlint' }, -- Optional: enable if needed
      -- go = { 'golangci-lint' }, -- Uncomment if you have Go installed
    }

    -- Create autocommand to lint on save and when entering buffer
    local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
    vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
      group = lint_augroup,
      callback = function()
        -- Only lint if file exists and is not too large
        if vim.fn.filereadable(vim.fn.expand '%') == 1 and vim.fn.getfsize(vim.fn.expand '%') < 1024 * 1024 then
          -- Wrap in pcall to prevent errors if linter is not installed
          pcall(function()
            lint.try_lint()
          end)
        end
      end,
    })
  end,
}
