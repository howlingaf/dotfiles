local WIDTH_PCT = 0.75
local HEIGHT_PCT = 0.95
local Y_OFFSET = -1 -- negative = shift float up; tweak to taste

local function find_claude_float()
  local ok, term = pcall(require, 'claudecode.terminal')
  if not ok then return end
  local bufnr = term.get_active_terminal_bufnr()
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
      return win
    end
  end
end

local function enforce_size(win)
  local w = math.floor(vim.o.columns * WIDTH_PCT)
  local h = math.floor(vim.o.lines * HEIGHT_PCT)
  vim.api.nvim_win_set_config(win, {
    relative = 'editor',
    width = w,
    height = h,
    row = math.max(0, math.floor((vim.o.lines - h) / 2) + Y_OFFSET),
    col = math.floor((vim.o.columns - w) / 2),
  })
end

local function toggle_claude()
  local was_open = find_claude_float() ~= nil
  vim.cmd 'ClaudeCode -r'
  if not was_open then
    -- Snacks runs additional layout passes after toggle returns; defer long
    -- enough to apply our geometry as the final word. Two passes catch cases
    -- where snacks does extra work between them.
    vim.defer_fn(function()
      local win = find_claude_float()
      if win then enforce_size(win) end
    end, 50)
    vim.defer_fn(function()
      local win = find_claude_float()
      if win then enforce_size(win) end
    end, 200)
  end
end

return {
  'coder/claudecode.nvim',
  dependencies = { 'folke/snacks.nvim' },
  keys = {
    { '<C-Space>', toggle_claude, mode = { 'n', 't' }, desc = 'Toggle Claude' },
    { '<leader>as', '<cmd>ClaudeCodeSend<cr>', mode = 'v', desc = 'Send selection to Claude' },
  },
  opts = {
    terminal = {
      provider = 'snacks',
      snacks_win_opts = {
        position = 'float',
        relative = 'editor',
        width = WIDTH_PCT,
        height = HEIGHT_PCT,
        border = 'single',
        backdrop = false,
        zindex = 100,
        keys = {
          -- Override vim-tmux-navigator's broken float-aware nav with
          -- buffer-local terminal-mode mappings. All four directions land
          -- in the previous window (your source split).
          back_h = {
            '<C-h>',
            function() vim.cmd 'wincmd p' end,
            mode = 't',
            desc = 'Focus source window',
          },
          back_j = {
            '<C-j>',
            function() vim.cmd 'wincmd p' end,
            mode = 't',
            desc = 'Focus source window',
          },
          back_k = {
            '<C-k>',
            function() vim.cmd 'wincmd p' end,
            mode = 't',
            desc = 'Focus source window',
          },
          back_l = {
            '<C-l>',
            function() vim.cmd 'wincmd p' end,
            mode = 't',
            desc = 'Focus source window',
          },
        },
      },
    },
  },
  config = true,
}
