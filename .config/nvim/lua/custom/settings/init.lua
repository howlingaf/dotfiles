vim.api.nvim_create_autocmd('BufReadPost', {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
      vim.schedule(function()
        vim.cmd 'normal! zz'
      end)
    end
  end,
})

vim.opt.undodir = vim.fn.stdpath 'state' .. '/undo/'
vim.opt.undofile = true

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.opt.number = true -- Show line numbers.
vim.opt.relativenumber = true -- Relative line numbers for easy movement.
vim.g.have_nerd_font = false
vim.opt.mouse = 'a' -- Enable mouse in all modes.
vim.opt.showmode = false -- Don't show "-- INSERT --" since statusline usually does.
vim.opt.breakindent = true -- Preserve indent when wrapping lines.
vim.opt.undofile = true -- Persistent undo between sessions.
vim.opt.ignorecase = true -- Case-insensitive searching...
vim.opt.smartcase = true -- ...unless capital letters are used.
vim.opt.incsearch = true -- Show matches while typing.
vim.opt.hlsearch = false -- Don't highlight matches after search ends.
vim.opt.updatetime = 250 -- Faster diagnostics updates.
vim.opt.timeoutlen = 300 -- Shorter mapping timeout.
vim.opt.splitright = true -- Open vertical splits to the right.
vim.opt.splitbelow = true -- Open horizontal splits below.
vim.opt.signcolumn = 'yes' -- Always show the sign column (no text shift).
vim.opt.scrolloff = 18 -- Keep 18 lines of context above/below cursor.
vim.opt.tabstop = 4 -- Display tabs as 4 spaces.
vim.opt.softtabstop = 4 -- Insert 4 spaces per <Tab>.
vim.opt.expandtab = true -- Use spaces instead of tabs.
vim.opt.shiftwidth = 2 -- Indent with 2 spaces.
vim.opt.textwidth = 80 -- Line wrap limit.
vim.opt.colorcolumn = '80' -- Draw a vertical line at column 80.
vim.opt.completeopt = 'menuone,noselect' -- Better completion behavior.
vim.opt.cursorline = true -- Highlight current line.
vim.opt.list = true -- Show invisible characters.
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
vim.opt.fileformat = 'unix'
vim.opt.conceallevel = 1

vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })
vim.keymap.set('n', '<leader>r', vim.diagnostic.open_float, { desc = 'Open floating diagnostic message' })

-- Normalize CRLF -> LF when pasting from clipboard
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function()
    local reg = vim.fn.getreg '"'
    if reg:find '\r' then
      vim.fn.setreg('"', reg:gsub('\r', ''))
    end
  end,
})

vim.api.nvim_create_autocmd('BufReadPost', {
  callback = function()
    local path = vim.fn.expand '%:p'
    local home = os.getenv 'HOME'
    local file_name = vim.fn.fnamemodify(path, ':t')
    if file_name:find '^%.zshrc' then
      return
    end
    if vim.fn.filereadable(path) == 1 and vim.fn.isdirectory(path) == 0 then
      local content = vim.fn.system('grep -v "^' .. path .. '$" ~/.edit_history')
      vim.fn.writefile(vim.split(content, '\n', { trimempty = true }), vim.fn.expand '~/.edit_history')
      vim.fn.writefile({ path }, vim.fn.expand '~/.edit_history', 'a')
    end
  end,
})

vim.api.nvim_set_keymap('i', 'jk', '<Esc>', { noremap = true })
vim.opt.clipboard = 'unnamedplus'

vim.keymap.set('n', '<leader>cr', function()
  local path = vim.fn.expand '%:p'
  vim.fn.setreg('+', path)
  print('Copied path to clipboard: ' .. path)
end, { desc = 'Copy full path of current file to clipboard' })

vim.keymap.set('n', '<leader>rc', function()
  vim.cmd('tabedit ' .. vim.fn.expand '$HOME/.zshrc')
end, { desc = 'Open ~/.zshrc' })

vim.keymap.set('n', '<leader>cd', ':cd %:p:h<CR>:pwd<CR>', { noremap = true, silent = true })

vim.keymap.set('n', '<leader>rr', function()
  for name, _ in pairs(package.loaded) do
    if name:match '^my_config' then
      package.loaded[name] = nil
    end
  end
  vim.cmd 'source $MYVIMRC'
  print 'Neovim config fully reloaded!'
end, { noremap = true, silent = true })

-- ----- Plugin-Specific Shortcuts -----
vim.keymap.set('n', '<leader>c', ':CsvViewToggle<CR>', { noremap = true, silent = true }) -- Toggle CSV view plugin.
vim.opt.inccommand = 'split' -- Live preview for substitute (:%s).

-- ----- Navigation Quality of Life -----
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true }) -- Prevent accidental leader trigger.
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true }) -- Move up visual lines.
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true }) -- Move down visual lines.

-- Move selected lines up and down in visual mode.
vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv")
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv")

-- Disable recording and suspend keys.
vim.keymap.set('n', 'Q', '<nop>')
vim.keymap.set('n', 'q', '<nop>')
vim.api.nvim_set_keymap('n', '<C-z>', '<Nop>', { noremap = true, silent = true })

-- Enable full color support.
vim.opt.termguicolors = true

vim.keymap.set('n', '<leader>wr', ':set wrap!<CR>', { noremap = true, silent = true })

vim.keymap.set('n', '<leader><leader>', '<cmd>set rnu!<CR>', { desc = 'Toggle relative line numbers' })

vim.keymap.set('n', '<leader>cl', function()
  vim.fn.system "tmux split-window -h -c '#{pane_current_path}' 'claude -c'"
end, { desc = 'Open Claude (continue) in tmux vertical split' })

-- Highlight text momentarily after yanking.
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Load machine-local overrides if present (colorscheme, etc.)
pcall(require, 'local')
