local lint = require 'lint'

-- No by-filetype linters: JS/TS and Python linting are handled live by the
-- ESLint and ruff LSPs (see init.lua), and lua_ls covers Lua. Clearing this
-- also drops nvim-lint's built-in defaults. The only linter here is the
-- clang-tidy const pass below, triggered by its own autocmd.
lint.linters_by_ft = {}

local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })

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
