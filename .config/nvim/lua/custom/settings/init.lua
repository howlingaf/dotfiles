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

-- Diagnostic display. Neovim 0.11+ ships with virtual_text OFF by default, so
-- errors only showed as a faint underline + gutter sign with no inline message --
-- which is why problems were so easy to miss. Turn on inline messages, sort by
-- severity, and give each severity a clear sign in the gutter.
vim.diagnostic.config {
  virtual_text = {
    spacing = 2,
    source = false, -- don't prefix inline messages with the source (clangd/clang-tidy)
    prefix = '●', -- shown before each inline message on the right of the line
  },
  underline = true, -- squiggle under the offending span
  severity_sort = true, -- errors sort above warnings on the same line
  update_in_insert = false, -- don't churn diagnostics while typing
  float = {
    border = 'single',
    source = 'if_many',
  },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = 'E',
      [vim.diagnostic.severity.WARN] = 'W',
      [vim.diagnostic.severity.INFO] = 'I',
      [vim.diagnostic.severity.HINT] = 'H',
    },
  },
}

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

-- Terminal-mode "vim" maps (jk escape, <C-h/j/k/l> window nav) intercept keys
-- that shells and TUIs want for themselves. They're applied buffer-locally on
-- TermOpen so <C-q> can toggle them per terminal, and a terminal can opt out
-- at creation by setting vim.b.term_vim = false before termopen (the shell
-- scratchpad float does this — it types like a plain terminal by default).
-- The built-in <C-\><C-n> escape works regardless of the toggle state.
local term_vim_maps = {}
local function term_vim_map(lhs, rhs, opts)
  table.insert(term_vim_maps, { lhs = lhs, rhs = rhs, opts = opts })
end
local function apply_term_vim(buf, on)
  for _, m in ipairs(term_vim_maps) do
    if on then
      vim.keymap.set('t', m.lhs, m.rhs, vim.tbl_extend('force', m.opts, { buffer = buf }))
    else
      pcall(vim.keymap.del, 't', m.lhs, { buffer = buf })
    end
  end
end
vim.api.nvim_create_autocmd('TermOpen', {
  group = vim.api.nvim_create_augroup('TermVimMaps', { clear = true }),
  callback = function(ev)
    if vim.b[ev.buf].term_vim == nil then
      vim.b[ev.buf].term_vim = true
    end
    apply_term_vim(ev.buf, vim.b[ev.buf].term_vim)
  end,
})
local function toggle_term_vim()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].buftype ~= 'terminal' then
    vim.notify('Not a terminal buffer', vim.log.levels.WARN)
    return
  end
  local on = not vim.b[buf].term_vim
  vim.b[buf].term_vim = on
  apply_term_vim(buf, on)
  vim.notify('Terminal vim maps: ' .. (on and 'on' or 'off'))
end
vim.keymap.set({ 'n', 't' }, '<C-q>', toggle_term_vim, { desc = 'Toggle vim maps in this terminal' })

term_vim_map('jk', [[<C-\><C-n>]], { noremap = true })

-- Floating terminal toggles. Each instance has its own persistent buffer;
-- killed only when its command `exit`s or the buffer is :bd!'d.
local Term -- forward declared so closures in write_parent_state can reference it

-- Registry of all floating terminals, so each toggle can detect a sibling that
-- is currently shown and switch/hide instead of stacking a second float on top.
local floating_terms = {}
local function visible_floating_term()
  for _, t in ipairs(floating_terms) do
    if t.win and vim.api.nvim_win_is_valid(t.win) then
      return t
    end
  end
end

-- Path the claude shell reads to learn what file/line/col the parent was on.
-- Per-nvim-instance so multiple nvims don't clobber each other.
local parent_state_path = (vim.fn.stdpath 'run' or '/tmp') .. '/nvim-term-parent-' .. vim.fn.getpid()

local function write_parent_state()
  if not Term or not Term.caller_file then return end
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
    if not Term then return end
    if vim.bo[ev.buf].buftype ~= '' then return end
    local name = vim.api.nvim_buf_get_name(ev.buf)
    if name == '' then return end
    Term.caller_file = name
    Term.caller_pos = vim.api.nvim_win_get_cursor(0)
    write_parent_state()
  end,
})

local function make_floating_term(cmd, opts)
  opts = opts or {}
  local T = { buf = nil, win = nil, last_view = nil, last_mode = nil }

  function T.open()
    local w = math.floor(vim.o.columns * 0.75)
    local h = math.floor(vim.o.lines * 0.95)
    local fresh = not (T.buf and vim.api.nvim_buf_is_valid(T.buf))
    if fresh then
      T.buf = vim.api.nvim_create_buf(false, true)
    end
    T.win = vim.api.nvim_open_win(T.buf, true, {
      relative = 'editor',
      width = w,
      height = h,
      row = math.floor((vim.o.lines - h) / 2),
      col = math.floor((vim.o.columns - w) / 2),
      border = 'single',
    })
    vim.wo[T.win].scrolloff = 999
    if fresh or vim.bo[T.buf].buftype ~= 'terminal' then
      if opts.term_vim == false then
        vim.b[T.buf].term_vim = false
      end
      if opts.env then
        vim.fn.termopen(cmd, { env = opts.env(T) })
      else
        vim.fn.termopen(cmd)
      end
      vim.cmd 'startinsert'
      return
    end
    vim.api.nvim_set_current_win(T.win)
    -- If caller was in insert in their buffer, vim auto-enters terminal-job
    -- mode when focus lands on a terminal buffer, which auto-follows the
    -- terminal cursor (bottom). Force terminal-normal before restoring view.
    if T.last_mode ~= 't' then vim.cmd 'stopinsert' end
    if T.last_view then
      vim.fn.winrestview(T.last_view)
    end
    if T.last_mode == 't' then vim.cmd 'startinsert' end
  end

  function T.hide()
    if T.win and vim.api.nvim_win_is_valid(T.win) then
      vim.api.nvim_set_current_win(T.win)
      T.last_view = vim.fn.winsaveview()
      T.last_mode = vim.api.nvim_get_mode().mode == 't' and 't' or 'n'
      vim.api.nvim_win_close(T.win, true)
      T.win = nil
    end
  end

  function T.toggle()
    if T.win and vim.api.nvim_win_is_valid(T.win) then
      local resume_insert = T.caller_insert
      local caller_win = T.caller_win
      local caller_pos = T.caller_pos
      T.hide()
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
      local sibling = visible_floating_term()
      if sibling and sibling ~= T then
        -- Another float is up. Inherit ITS real-editor caller (not the sibling's
        -- float window) so hiding T later returns to the editor instead of
        -- bouncing back to the sibling, then close the sibling and swap T in.
        T.caller_insert = sibling.caller_insert
        T.caller_win = sibling.caller_win
        T.caller_pos = sibling.caller_pos
        T.caller_file = sibling.caller_file
        sibling.hide()
      else
        T.caller_insert = vim.api.nvim_get_mode().mode:sub(1, 1) == 'i'
        T.caller_win = vim.api.nvim_get_current_win()
        T.caller_pos = vim.api.nvim_win_get_cursor(0)
        T.caller_file = vim.api.nvim_buf_get_name(0)
      end
      if opts.on_open then opts.on_open(T) end
      T.open()
    end
  end

  table.insert(floating_terms, T)
  return T
end

-- A visible floating terminal covers most of the viewport, so there's no
-- reason for focus to land on the editor windows behind it (mouse click,
-- stray <C-w> nav). Bounce focus back to the float. Other floats (e.g.
-- breadcrumbs) may still take focus; hide/swap paths are unaffected because
-- they close the float before focus moves.
vim.api.nvim_create_autocmd('WinEnter', {
  group = vim.api.nvim_create_augroup('TermFloatFocus', { clear = true }),
  callback = function()
    local t = visible_floating_term()
    if not t or t.win == vim.api.nvim_get_current_win() then return end
    if vim.api.nvim_win_get_config(0).relative ~= '' then return end
    vim.schedule(function()
      if t.win and vim.api.nvim_win_is_valid(t.win) then
        vim.api.nvim_set_current_win(t.win)
      end
    end)
  end,
})

Term = make_floating_term({ 'claude', '-c' }, {
  term_vim = false,
  env = function(T)
    return {
      NVIM_PARENT_STATE = parent_state_path,
      NVIM_PARENT_FILE = T.caller_file or '',
      NVIM_PARENT_LINE = tostring(T.caller_pos and T.caller_pos[1] or 0),
      NVIM_PARENT_COL = tostring(T.caller_pos and (T.caller_pos[2] + 1) or 0),
    }
  end,
  on_open = function() write_parent_state() end,
})

-- Breadcrumbs scratch notes: opens the .md file as a real buffer in a floating
-- window of THIS nvim (no nested nvim, no PTY). Toggling preserves cursor view.
local Breadcrumbs = (function()
  local path = vim.fn.expand '$HOME/Vault/_BREADCRUMBS.md'
  local B = { win = nil, last_view = nil }

  function B.toggle()
    if B.win and vim.api.nvim_win_is_valid(B.win) then
      B.last_view = vim.fn.winsaveview()
      vim.api.nvim_win_close(B.win, true)
      B.win = nil
      return
    end
    local buf = vim.fn.bufadd(path)
    vim.fn.bufload(buf)
    vim.bo[buf].buflisted = true
    local w = math.floor(vim.o.columns * 0.75)
    local h = math.floor(vim.o.lines * 0.95)
    B.win = vim.api.nvim_open_win(buf, true, {
      relative = 'editor',
      width = w,
      height = h,
      row = math.floor((vim.o.lines - h) / 2),
      col = math.floor((vim.o.columns - w) / 2),
      border = 'single',
    })
    if B.last_view then vim.fn.winrestview(B.last_view) end
  end

  return B
end)()

for _, key in ipairs { '<C-Space>', '<C-@>', '<NUL>' } do
  vim.keymap.set({ 'n', 'i', 't' }, key, Term.toggle, { desc = 'Toggle floating Claude terminal' })
end
local ShellTerm = make_floating_term({ vim.o.shell }, { term_vim = false })
vim.keymap.set({ 'n', 'i', 't' }, '<S-Space>', ShellTerm.toggle, { desc = 'Toggle floating shell terminal' })

-- Note: `K` (LSP hover) and `<leader>K` (definition peek) are mapped per-buffer
-- on LspAttach in init.lua, so they only bind where an LSP is active.
--
-- Neutralize keyword-lookup (`keywordprg`, default `:Man`) in C/C++ buffers.
-- cppman's integration and the default :Man handler open a man-page split for
-- symbols like `size_t`; with `K` already bound to LSP hover that man page was
-- leaking in *behind* the hover float. Empty keywordprg here so nothing but the
-- hover ever appears, and the two are fully independent.
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'c', 'cpp', 'objc', 'objcpp' },
  group = vim.api.nvim_create_augroup('NoManKeywordprg', { clear = true }),
  callback = function(ev)
    vim.bo[ev.buf].keywordprg = ''
  end,
})

-- In a :terminal buffer, `gf` and `gd` resolve the token under the cursor
-- (URL, or path with optional :LINE:COL) and open it in the underlying
-- non-floating window — the floating terminal hides itself first. No LSP
-- lookup happens here; the terminal buffer has no client.
local function term_goto()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  local s, e = col, col
  while s > 1 and not line:sub(s - 1, s - 1):match '%s' do s = s - 1 end
  while e <= #line and not line:sub(e, e):match '%s' do e = e + 1 end
  local token = line:sub(s, e - 1)
  token = token:gsub('^[%(%[%{\'"`]+', ''):gsub('[%)%]%}\'",;:%.]+$', '')

  if token:match '^https?://' or token:match '^www%.' then
    local url = token
    if not url:match '^https?://' then url = 'https://' .. url end
    vim.fn.setreg('+', url)
    vim.notify('URL copied to clipboard: ' .. url, vim.log.levels.INFO)
    return
  end

  local path, lnum, cnum = token:match '^(.-):(%d+):(%d+)$'
  if not path then path, lnum = token:match '^(.-):(%d+)%-%d+$' end
  if not path then path, lnum = token:match '^(.-):(%d+)$' end
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
end

vim.api.nvim_create_autocmd('TermOpen', {
  callback = function(ev)
    vim.keymap.set('n', 'gf', term_goto, { buffer = ev.buf, desc = 'Open file/URL under cursor in main window' })
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

-- Over SSH, force OSC 52 so yanks land on the local machine's clipboard.
-- Without this a remote host with its own clipboard tool (pbcopy on the mac)
-- wins provider detection and yanks get stranded in that machine's clipboard.
if vim.env.SSH_TTY then
  vim.g.clipboard = 'osc52'
end
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

vim.keymap.set('n', '<leader>bl', function()
  vim.cmd('edit ' .. vim.fn.fnameescape(vim.fn.expand '$HOME/Vault/_BREADCRUMBS.md'))
end, { desc = 'Open [B]readcrumbs file' })

vim.keymap.set('n', '<leader>cd', ':cd %:p:h<CR>:pwd<CR>', { noremap = true, silent = true })

-- gf: if <cfile> looks like a URL, open with system handler; otherwise fall
-- back to built-in gf. <cfile> already does the right span detection and is
-- more forgiving than a hand-rolled cursor-overlap regex.
vim.keymap.set('n', 'gf', function()
  local cfile = vim.fn.expand '<cfile>'
  if cfile:match '^https?://' or cfile:match '^www%.' then
    local url = cfile:gsub('[%.,;:)%]]+$', '')
    if not url:match '^https?://' then url = 'https://' .. url end
    vim.fn.setreg('+', url)
    vim.notify('URL copied to clipboard: ' .. url, vim.log.levels.INFO)
    return
  end
  vim.cmd 'normal! gf'
end, { desc = 'gf: open URL or file under cursor' })

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


-- Window navigation: <C-h/j/k/l> for native nvim splits in normal mode, and
-- the same keys in terminal mode (exit term mode then navigate). Replaces the
-- vim-tmux-navigator setup since panes are now nvim-managed only.
vim.keymap.set('n', '<C-h>', '<C-w>h', { silent = true, desc = 'Window: left' })
vim.keymap.set('n', '<C-j>', '<C-w>j', { silent = true, desc = 'Window: down' })
vim.keymap.set('n', '<C-k>', '<C-w>k', { silent = true, desc = 'Window: up' })
vim.keymap.set('n', '<C-l>', '<C-w>l', { silent = true, desc = 'Window: right' })

term_vim_map('<C-h>', [[<C-\><C-n><cmd>wincmd h<cr>]], { silent = true })
term_vim_map('<C-j>', [[<C-\><C-n><cmd>wincmd j<cr>]], { silent = true })
term_vim_map('<C-k>', [[<C-\><C-n><cmd>wincmd k<cr>]], { silent = true })
term_vim_map('<C-l>', [[<C-\><C-n><cmd>wincmd l<cr>]], { silent = true })

-- Highlight text momentarily after yanking.
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Shift+M: open cppman's interactive pager for the symbol under the cursor in
-- a floating terminal. The symbol grab includes `::` qualifiers so std::vector
-- resolves whole, not just `vector`. Close the pager (q) and the float closes.
local function cppman_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  -- Expand left/right over identifier chars plus ':' so std::vector is whole.
  local s, e = col, col
  local function is_sym(c) return c:match '[%w_:]' ~= nil end
  while s > 1 and is_sym(line:sub(s - 1, s - 1)) do s = s - 1 end
  while e <= #line and is_sym(line:sub(e, e)) do e = e + 1 end
  local sym = line:sub(s, e - 1):gsub('^:+', ''):gsub(':+$', '')
  if sym == '' then
    vim.notify('No symbol under cursor', vim.log.levels.WARN)
    return
  end

  -- cppman already renders to a man page; MANPAGER=cat emits it as text, col -bx
  -- flattens the overstrike bold. Drop it into a :Man-style horizontal split so
  -- it looks/scrolls/closes (q) exactly like the tidydoc and :Man buffers.
  local width = math.min(100, vim.o.columns)
  local out = vim.fn.systemlist {
    'sh', '-c',
    string.format('MANPAGER=cat MANWIDTH=%d cppman %s 2>/dev/null | col -bx', width, vim.fn.shellescape(sym)),
  }
  if vim.v.shell_error ~= 0 or #out == 0 then
    vim.notify('cppman: nothing for "' .. sym .. '"', vim.log.levels.WARN)
    return
  end

  vim.cmd 'botright new'
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'man'
  vim.api.nvim_buf_set_name(buf, 'cppman://' .. sym)
  local win = vim.api.nvim_get_current_win()
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'
  vim.wo[win].list = false
  vim.api.nvim_win_set_cursor(win, { 1, 0 })
  vim.keymap.set('n', 'q', '<cmd>close<CR>', { buffer = buf, nowait = true, silent = true })
end
vim.keymap.set('n', '<S-m>', cppman_under_cursor, { desc = 'cppman docs for symbol under cursor' })

-- <leader>td: open the clang-tidy doc page for the diagnostic on the cursor
-- line, rendered as text in a read-only float via `w3m -dump`. The check name
-- comes from the diagnostic's `code` field (clangd sets it, e.g.
-- modernize-loop-convert); falls back to a [bracketed-name] in the message.
local function tidydoc_under_cursor()
  local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
  local diags = vim.diagnostic.get(0, { lnum = lnum })
  local check
  for _, d in ipairs(diags) do
    local code = d.code
    if type(code) == 'string' and code:match '^[%w]+%-' then
      check = code
      break
    end
    local m = d.message and d.message:match '%[([%w]+%-[%w%-]+)%]'
    if m then
      check = m
      break
    end
  end
  if not check then
    vim.notify('No clang-tidy check found on this line', vim.log.levels.WARN)
    return
  end

  local url = 'https://clang.llvm.org/extra/clang-tidy/checks/' .. check:gsub('%-', '/', 1) .. '.html'

  -- Build a REAL man page and show it exactly like `:Man`: curl the HTML, pandoc
  -- converts to roff (-t man), strip pandoc's ¶ anchors + thin-space escapes,
  -- give it a clean .TH title, render with `man -l`, then `col -bx` flattens the
  -- backspace-overstrike bold into plain text. The result goes into a horizontal
  -- split scratch buffer with filetype=man — same look/scroll/q as :Man grep.
  local width = math.min(100, vim.o.columns)
  local sh = string.format(
    "curl -fsSL --compressed %s "
      .. "| pandoc -f html -t man "
      .. "| sed -e 's/¶//g' -e 's/\\\\[|]/ /g' "
      .. "| { printf '.TH \"%s\" \"clang-tidy\" \"\" \"\" \"\"\\n'; cat; } "
      .. "| MANWIDTH=%d man -l - "
      .. "| col -bx",
    vim.fn.shellescape(url),
    check,
    width
  )

  local out = vim.fn.systemlist { 'sh', '-c', sh }
  if vim.v.shell_error ~= 0 or #out == 0 then
    vim.notify('tidydoc: failed to render ' .. check, vim.log.levels.WARN)
    return
  end

  -- Horizontal split with a man-style scratch buffer, mirroring :Man.
  vim.cmd 'botright new'
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'man'
  vim.api.nvim_buf_set_name(buf, 'tidydoc://' .. check)
  local win = vim.api.nvim_get_current_win()
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'
  vim.wo[win].list = false
  vim.api.nvim_win_set_cursor(win, { 1, 0 })
  -- `q` closes it (buffer-local, overrides the global `q`->`<nop>`).
  vim.keymap.set('n', 'q', '<cmd>close<CR>', { buffer = buf, nowait = true, silent = true })
end
vim.keymap.set('n', '<leader>td', tidydoc_under_cursor, { desc = 'clang-[t]idy [d]oc for diagnostic on line' })

-- Sticky full path at the top of each buffer (winbar), relative to the repo root.
local function winbar_path()
  local full = vim.api.nvim_buf_get_name(0)
  if full == '' then return '' end
  full = vim.fn.fnamemodify(full, ':p')
  local root = vim.fs.root(full, '.git')
  local rel
  if root then
    rel = full:sub(#root + 2)
  else
    rel = vim.fn.fnamemodify(full, ':~:.')
  end
  rel = rel:gsub('%%', '%%%%') -- escape % so paths don't break the format string
  return '  ' .. rel
end

vim.api.nvim_create_autocmd({ 'BufWinEnter', 'BufEnter', 'BufFilePost' }, {
  desc = 'Show repo-relative path in the winbar',
  group = vim.api.nvim_create_augroup('StickyPathWinbar', { clear = true }),
  callback = function(ev)
    local win = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_get_config(win).relative ~= '' then return end -- skip floats
    if vim.bo[ev.buf].buftype ~= '' then return end -- skip terminal/help/nofile/qf
    if vim.api.nvim_buf_get_name(ev.buf) == '' then return end -- skip unnamed
    vim.wo[win].winbar = winbar_path()
  end,
})

-- Load machine-local overrides if present (colorscheme, etc.)
pcall(require, 'local')
