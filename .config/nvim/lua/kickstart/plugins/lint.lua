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

    -- C/C++ const-correctness on save.
    --
    -- clangd runs clang-tidy live, but it hard-blocklists a few checks that need
    -- whole-function dataflow (too slow per-keystroke) -- misc-const-correctness
    -- (the "can be declared const" hint) is the notable one. So run JUST that
    -- check as a separate on-save pass. `--config` overrides ~/.clang-tidy so we
    -- enable ONLY const-correctness here -> no overlap with clangd's live checks.
    -- clang-tidy auto-reads compile_flags.txt / compile_commands.json for flags.
    local pattern = [=[([^:]*):(%d+):(%d+): (%w+): ([^[]+) %[(.*)%]]=]
    local groups = { 'file', 'lnum', 'col', 'severity', 'message', 'code' }
    local severity_map = {
      ['error'] = vim.diagnostic.severity.WARN, -- show as a hint-ish warning, never block
      ['warning'] = vim.diagnostic.severity.WARN,
      ['note'] = vim.diagnostic.severity.HINT,
    }
    lint.linters.clangtidy_const = {
      cmd = 'clang-tidy',
      stdin = false,
      ignore_exitcode = true,
      args = {
        '--quiet',
        '--checks=-*,misc-const-correctness',
        '--config={}', -- ignore ~/.clang-tidy so ONLY the check above runs
      },
      parser = require('lint.parser').from_pattern(
        pattern,
        groups,
        severity_map,
        { ['source'] = 'clang-tidy (const)' }
      ),
    }

    -- On open and on save -- NOT on every keystroke/InsertLeave: clang-tidy
    -- recompiles the whole translation unit (~0.85s here), so it runs async in
    -- the background on BufReadPost/BufWritePost only. The const squiggle appears
    -- ~1s after a C/C++ file opens, then refreshes on each save.
    vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost' }, {
      group = lint_augroup,
      pattern = { '*.c', '*.cc', '*.cpp', '*.cxx', '*.h', '*.hpp', '*.hxx' },
      callback = function()
        if vim.fn.executable 'clang-tidy' == 1 then
          pcall(function()
            lint.try_lint 'clangtidy_const'
          end)
        end
      end,
    })
  end,
}
