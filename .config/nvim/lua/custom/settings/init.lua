-- =============================
-- 🌙  Custom Neovim Settings
-- =============================

-- ----- Leader Keys -----
-- Set <Space> as the main leader key and local leader key.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- ----- General Keymaps -----
-- Clear search highlights with <Esc> in normal mode.
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostic shortcuts.
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })
vim.keymap.set('n', '<leader>r', vim.diagnostic.open_float, { desc = 'Open floating diagnostic message' })

-- Indicate whether Nerd Fonts are available (used by some plugins).
vim.g.have_nerd_font = false

-- Exit insert mode quickly by typing 'jk'.
vim.api.nvim_set_keymap('i', 'jk', '<Esc>', { noremap = true })

-- ----- Clipboard Integration -----
-- Use the system clipboard for all yank, delete, paste operations.
vim.opt.clipboard = 'unnamedplus'

-- Ensure clipboard integration persists even after startup delay or focus regain.
vim.defer_fn(function()
  vim.opt.clipboard = 'unnamedplus'
end, 100)

-- Get path of current buffer and copy it to clipboard
vim.keymap.set('n', '<leader>cr', function()
  local path = vim.fn.expand '%:p'
  vim.fn.setreg('+', path) -- copy to system clipboard
  print('Copied path to clipboard: ' .. path)
end, { desc = 'Copy full path of current file to clipboard' })

vim.api.nvim_create_autocmd({ 'BufEnter', 'FocusGained' }, {
  callback = function()
    vim.opt.clipboard = 'unnamedplus'
  end,
})

-- <leader>zs → open ~/.zshrc in a new tab
vim.keymap.set('n', '<leader>zs', function()
  vim.cmd('tabedit ' .. vim.fn.expand '$HOME/.zshrc')
end, { desc = 'Open ~/.zshrc' })
-- ----- Text Display -----
-- Controls how concealed text (like markdown links) is displayed.
vim.opt.conceallevel = 1

-- ----- Custom "gf" Behavior -----
-- Map 'gf' to open URLs or local files
function OpenFileOrURL()
  local word = vim.fn.expand '<cfile>'
  if word == '' then
    return
  end

  -- Check if it's a URL
  if word:match '^https?://' or word:match '^ftp://' then
    -- Open URL in default browser
    local cmd = 'open ' .. vim.fn.shellescape(word)
    vim.fn.system(cmd)
  else
    -- Try to open as file (default gf behavior)
    vim.cmd('normal! gf')
  end
end

vim.api.nvim_set_keymap('n', 'gf', ':lua OpenFileOrURL()<CR>', { noremap = true, silent = true })

-- ----- Utility Keymaps -----
-- Insert current date at cursor.
vim.keymap.set('n', '<leader>dt', function()
  vim.api.nvim_put({ os.date '%Y-%m-%d' }, 'c', true, true)
end, { noremap = true, silent = true })

-- Change current working directory to current file's folder.
vim.keymap.set('n', '<leader>cd', ':cd %:p:h<CR>:pwd<CR>', { noremap = true, silent = true })

-- Reload the entire Neovim config live without restarting.
vim.keymap.set('n', '<leader>rr', function()
  for name, _ in pairs(package.loaded) do
    if name:match '^my_config' then
      package.loaded[name] = nil
    end
  end
  vim.cmd 'source $MYVIMRC'
  print 'Neovim config fully reloaded!'
end, { noremap = true, silent = true })

-- ----- UI & Behavior Settings -----
vim.opt.number = true -- Show line numbers.
vim.opt.relativenumber = true -- Relative line numbers for easy movement.
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

-- ----- Plugin-Specific Shortcuts -----
vim.keymap.set('n', '<leader>c', ':CsvViewToggle<CR>', { noremap = true, silent = true }) -- Toggle CSV view plugin.
vim.opt.inccommand = 'split' -- Live preview for substitute (:%s).

-- ----- Navigation Quality of Life -----
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true }) -- Prevent accidental leader trigger.
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true }) -- Move up visual lines.
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true }) -- Move down visual lines.

-- Disable bracket-based motions (useful if you map them elsewhere).
for _, key in ipairs { '{', '}', '[', ']' } do
  vim.api.nvim_set_keymap('n', key, '<Nop>', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('v', key, '<Nop>', { noremap = true, silent = true })
end

-- Move selected lines up and down in visual mode.
vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv")
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv")

-- Disable recording and suspend keys.
vim.keymap.set('n', 'Q', '<nop>')
vim.keymap.set('n', 'q', '<nop>')
vim.api.nvim_set_keymap('n', '<C-z>', '<Nop>', { noremap = true, silent = true })

-- Enable full color support.
vim.opt.termguicolors = true

-- =============================
-- 📘  Dictionary Popup Function
-- =============================

-- Function: Show definition of word under cursor using `dict` command.
function show_dict_definition()
  local word = vim.fn.expand '<cword>'
  if word == '' then
    print 'No word under cursor'
    return
  end

  -- Run `dict` CLI command to fetch definition.
  local cmd = 'dict ' .. vim.fn.shellescape(word)
  local output = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    print('Dict command failed or no definition found for: ' .. word)
    return
  end

  -- Display definition in a centered floating window.
  local lines = vim.split(output, '\n')
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.7)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' Dictionary: ' .. word .. ' ',
    title_pos = 'center',
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  -- Close popup with 'q' or <Esc>.
  for _, key in ipairs { 'q', '<Esc>' } do
    vim.api.nvim_buf_set_keymap(buf, 'n', key, '', {
      callback = function()
        vim.api.nvim_win_close(win, true)
      end,
      noremap = true,
      silent = true,
    })
  end
end

-- Keymap to trigger dictionary lookup.
vim.keymap.set('n', '<leader>d', show_dict_definition, {
  desc = 'Show dictionary definition for word under cursor',
})

-- ----- Misc Keymaps -----
-- Toggle line wrapping.
vim.keymap.set('n', '<leader>wr', ':set wrap!<CR>', { noremap = true, silent = true })

-- Open your main TODO file.
vim.keymap.set('n', '<leader>td', function()
  vim.cmd('edit ' .. vim.fn.expand '/Volumes/Development/arketa-notes/.todo.md')
end, { noremap = true, silent = true, desc = 'Open todo.md' })

-- Highlight text momentarily after yanking.
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})
