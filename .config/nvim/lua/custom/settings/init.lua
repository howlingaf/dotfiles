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
vim.opt.cmdheight = 0 -- Collapse cmdline when idle so statusline sits flush with tmux.
vim.opt.winborder = 'single' -- Default border for floats (LSP hover, signature, etc.)
vim.opt.breakindent = true -- Preserve indent when wrapping lines.
vim.opt.undofile = true -- Persistent undo between sessions.
vim.opt.ignorecase = true -- Case-insensitive searching...
vim.opt.smartcase = true -- ...unless capital letters are used.
vim.opt.incsearch = true -- Show matches while typing.
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
vim.opt.autoindent = true -- Copy indent from current line on new line.
vim.opt.smartindent = true -- Add indent for new blocks in C-like syntax.
vim.opt.textwidth = 80 -- Line wrap limit.
vim.opt.colorcolumn = '80' -- Draw a vertical line at column 80.
vim.opt.completeopt = 'menuone,noselect' -- Better completion behavior.
vim.opt.cursorline = true -- Highlight current line.
vim.opt.list = true -- Show invisible characters.
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
vim.opt.fileformat = 'unix'
vim.opt.conceallevel = 1
vim.opt.title = true -- Set terminal/pane title (OSC 2)...
vim.opt.titlestring = '%F' -- ...to full path of current buffer.

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
vim.keymap.set('t', 'jk', [[<C-\><C-n>]], { noremap = true })

-- Floating terminal toggle. Buffer persists across toggles; killed only when
-- the shell `exit`s or the buffer is :bd!'d.
local Term = { buf = nil, win = nil, last_view = nil, last_mode = nil }

-- Path the shell reads to learn what file/line/col the parent was on at the
-- last toggle. Per-nvim-instance so multiple nvims don't clobber each other.
local parent_state_path = (vim.fn.stdpath 'run' or '/tmp') .. '/nvim-term-parent-' .. vim.fn.getpid()

local function write_parent_state()
  if not Term.caller_file then return end
  local fd = io.open(parent_state_path, 'w')
  if not fd then return end
  local line = Term.caller_pos and Term.caller_pos[1] or 0
  local col = Term.caller_pos and (Term.caller_pos[2] + 1) or 0
  fd:write(Term.caller_file .. '\n' .. line .. '\n' .. col .. '\n')
  fd:close()
end

-- Keep the parent-state file live: refresh on cursor move / buffer switch in
-- any real file buffer, so the shell sees the user's current position even
-- while the floating terminal is open.
vim.api.nvim_create_autocmd({ 'BufEnter', 'CursorMoved', 'CursorMovedI', 'InsertLeave' }, {
  group = vim.api.nvim_create_augroup('TermParentState', { clear = true }),
  callback = function(ev)
    if vim.bo[ev.buf].buftype ~= '' then return end
    local name = vim.api.nvim_buf_get_name(ev.buf)
    if name == '' then return end
    Term.caller_file = name
    Term.caller_pos = vim.api.nvim_win_get_cursor(0)
    write_parent_state()
  end,
})

function Term.open()
  local w = math.floor(vim.o.columns * 0.75)
  local h = math.floor(vim.o.lines * 0.95)
  local fresh = not (Term.buf and vim.api.nvim_buf_is_valid(Term.buf))
  if fresh then
    Term.buf = vim.api.nvim_create_buf(false, true)
  end
  Term.win = vim.api.nvim_open_win(Term.buf, true, {
    relative = 'editor',
    width = w,
    height = h,
    row = math.floor((vim.o.lines - h) / 2),
    col = math.floor((vim.o.columns - w) / 2),
    border = 'single',
  })
  vim.wo[Term.win].scrolloff = 999
  if fresh or vim.bo[Term.buf].buftype ~= 'terminal' then
    vim.fn.termopen(vim.o.shell, {
      env = {
        NVIM_PARENT_STATE = parent_state_path,
        NVIM_PARENT_FILE = Term.caller_file or '',
        NVIM_PARENT_LINE = tostring(Term.caller_pos and Term.caller_pos[1] or 0),
        NVIM_PARENT_COL = tostring(Term.caller_pos and (Term.caller_pos[2] + 1) or 0),
      },
    })
    vim.cmd 'startinsert'
    return
  end
  vim.api.nvim_set_current_win(Term.win)
  -- If caller was in insert in their buffer, vim auto-enters terminal-job
  -- mode when focus lands on a terminal buffer, which auto-follows the
  -- terminal cursor (bottom). Force terminal-normal before restoring view.
  if Term.last_mode ~= 't' then vim.cmd 'stopinsert' end
  if Term.last_view then
    vim.fn.winrestview(Term.last_view)
  end
  if Term.last_mode == 't' then vim.cmd 'startinsert' end
end

function Term.hide()
  if Term.win and vim.api.nvim_win_is_valid(Term.win) then
    vim.api.nvim_set_current_win(Term.win)
    Term.last_view = vim.fn.winsaveview()
    Term.last_mode = vim.api.nvim_get_mode().mode == 't' and 't' or 'n'
    vim.api.nvim_win_close(Term.win, true)
    Term.win = nil
  end
end

function Term.toggle()
  if Term.win and vim.api.nvim_win_is_valid(Term.win) then
    local resume_insert = Term.caller_insert
    local caller_win = Term.caller_win
    local caller_pos = Term.caller_pos
    Term.hide()
    if resume_insert then
      vim.defer_fn(function()
        if caller_win and vim.api.nvim_win_is_valid(caller_win) then
          vim.api.nvim_set_current_win(caller_win)
        end
        if vim.bo.buftype ~= '' then return end
        -- If saved cursor was past end-of-line (insert append), use startinsert!
        -- so it lands after the last char without clamping.
        local at_eol = false
        if caller_pos then
          local row, col = caller_pos[1], caller_pos[2]
          local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ''
          at_eol = col >= #line
          if not at_eol then
            pcall(vim.api.nvim_win_set_cursor, 0, caller_pos)
          else
            pcall(vim.api.nvim_win_set_cursor, 0, { row, math.max(0, #line - 1) })
          end
        end
        vim.cmd(at_eol and 'startinsert!' or 'startinsert')
      end, 10)
    end
  else
    Term.caller_insert = vim.api.nvim_get_mode().mode:sub(1, 1) == 'i'
    Term.caller_win = vim.api.nvim_get_current_win()
    Term.caller_pos = vim.api.nvim_win_get_cursor(0)
    Term.caller_file = vim.api.nvim_buf_get_name(0)
    write_parent_state()
    Term.open()
  end
end

for _, key in ipairs { '<C-Space>', '<C-@>', '<NUL>' } do
  vim.keymap.set({ 'n', 'i', 't' }, key, Term.toggle, { desc = 'Toggle floating terminal' })
end

-- In a :terminal buffer, `gf` opens the file under cursor in the underlying
-- non-floating window (so the floating terminal stays put). Parses optional
-- trailing :LINE:COL.
vim.api.nvim_create_autocmd('TermOpen', {
  callback = function(ev)
    vim.keymap.set('n', 'gf', function()
      local line = vim.api.nvim_get_current_line()
      local col = vim.api.nvim_win_get_cursor(0)[2] + 1
      local s, e = col, col
      while s > 1 and not line:sub(s - 1, s - 1):match('%s') do s = s - 1 end
      while e <= #line and not line:sub(e, e):match('%s') do e = e + 1 end
      local token = line:sub(s, e - 1)
      token = token:gsub('^[%(%[%{\'"`]+', ''):gsub('[%)%]%}\'",;:%.]+$', '')

      local path, lnum, cnum = token:match('^(.-):(%d+):(%d+)$')
      if not path then path, lnum = token:match('^(.-):(%d+)%-%d+$') end
      if not path then path, lnum = token:match('^(.-):(%d+)$') end
      if not path then path = token end
      lnum = tonumber(lnum)
      cnum = tonumber(cnum)

      if path:sub(1, 1) == '~' then path = vim.fn.expand(path) end
      if path:sub(1, 1) ~= '/' then path = vim.fn.getcwd() .. '/' .. path end
      path = vim.fn.fnamemodify(path, ':p')
      if vim.fn.filereadable(path) ~= 1 then
        vim.notify('Not a file: ' .. path, vim.log.levels.WARN)
        return
      end

      local target
      for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if (vim.api.nvim_win_get_config(w).relative or '') == '' then
          target = w
          break
        end
      end
      Term.hide()
      if target and vim.api.nvim_win_is_valid(target) then
        vim.api.nvim_set_current_win(target)
      else
        vim.cmd 'wincmd p'
      end

      vim.cmd('edit ' .. vim.fn.fnameescape(path))
      if lnum then
        pcall(vim.api.nvim_win_set_cursor, 0, { lnum, math.max(0, (cnum or 1) - 1) })
        vim.cmd 'normal! zz'
      end
    end, { buffer = ev.buf, desc = 'Open file under cursor in main window' })
  end,
})

-- Reload files Claude (or anything else) edits on disk while open in nvim.
vim.opt.autoread = true
vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI', 'FocusGained', 'BufEnter' }, {
  callback = function()
    if vim.fn.mode() ~= 'c' then
      pcall(vim.cmd, 'checktime')
    end
  end,
})

vim.opt.clipboard = 'unnamedplus'

vim.keymap.set('n', '<leader>cr', function()
  local path = vim.fn.expand '%:p'
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local entry = path .. ':' .. line
  vim.fn.setreg('+', entry)
  print('Copied: ' .. entry)
end, { desc = 'Copy full path:line of current file to clipboard' })

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

-- :Q (and :Q!) quits the entire nvim instance, not just the current window.
vim.api.nvim_create_user_command('Q', function(opts)
  vim.cmd(opts.bang and 'qall!' or 'qall')
end, { bang = true, desc = 'Quit all windows (kill nvim)' })

-- ----- Plugin-Specific Shortcuts -----
vim.keymap.set('n', '<leader>cc', ':CsvViewToggle<CR>', { noremap = true, silent = true }) -- Toggle CSV view plugin.
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

-- Window navigation: <C-h/j/k/l> for native nvim splits in normal mode, and
-- the same keys in terminal mode (exit term mode then navigate). Replaces the
-- vim-tmux-navigator setup since panes are now nvim-managed only.
vim.keymap.set('n', '<C-h>', '<C-w>h', { silent = true, desc = 'Window: left' })
vim.keymap.set('n', '<C-j>', '<C-w>j', { silent = true, desc = 'Window: down' })
vim.keymap.set('n', '<C-k>', '<C-w>k', { silent = true, desc = 'Window: up' })
vim.keymap.set('n', '<C-l>', '<C-w>l', { silent = true, desc = 'Window: right' })

vim.keymap.set('t', '<C-h>', [[<C-\><C-n><cmd>wincmd h<cr>]], { silent = true })
vim.keymap.set('t', '<C-j>', [[<C-\><C-n><cmd>wincmd j<cr>]], { silent = true })
vim.keymap.set('t', '<C-k>', [[<C-\><C-n><cmd>wincmd k<cr>]], { silent = true })
vim.keymap.set('t', '<C-l>', [[<C-\><C-n><cmd>wincmd l<cr>]], { silent = true })

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
