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

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.opt.number = true -- Show line numbers.
vim.opt.relativenumber = false -- Relative line numbers for easy movement.
vim.g.have_nerd_font = false
vim.opt.mouse = 'a' -- Enable mouse in all modes.
vim.opt.showmode = false -- Don't show "-- INSERT --" since statusline usually does.
vim.opt.cmdheight = 0 -- Collapse cmdline when idle so statusline sits flush with tmux.
vim.opt.winborder = 'single' -- Default border for floats (LSP hover, signature, etc.)
vim.opt.breakindent = true -- Preserve indent when wrapping lines.
vim.opt.undofile = true -- Persistent undo between sessions.
vim.opt.ignorecase = true -- Case-insensitive searching...
vim.opt.smartcase = true -- ...unless capital letters are used.
vim.opt.updatetime = 250 -- Faster diagnostics updates.
vim.opt.timeoutlen = 300 -- Shorter mapping timeout.
vim.opt.splitright = true -- Open vertical splits to the right.
vim.opt.splitbelow = true -- Open horizontal splits below.
vim.opt.signcolumn = 'yes' -- Always show the sign column (no text shift).
vim.opt.scrolloff = 0 -- Centering is done by the zz autocmd below.
vim.opt.exrc = true -- Load project-local .nvim.lua (prompts to trust on first use).

-- Keep the cursor vertically centered: zz on every move (scrolls past EOF,
-- unlike scrolloff=999; the top half-screen stays uncentered). Mirrors
-- vim-classic's CenterCursor autocmd.
local wheel_scrolling = false
vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
  group = vim.api.nvim_create_augroup('center_cursor', {}),
  callback = function()
    local bt = vim.bo.buftype
    if (bt ~= '' and bt ~= 'help') or vim.fn.pumvisible() ~= 0 or wheel_scrolling then
      return
    end
    -- In insert mode the cursor may sit past EOL (e.g. after `A`); the
    -- normal-mode round trip of :normal clamps it onto the last char.
    local curpos = vim.api.nvim_win_get_cursor(0)
    vim.cmd 'normal! zz'
    vim.api.nvim_win_set_cursor(0, curpos)
  end,
})

-- Let the mouse wheel scroll the view freely instead of fighting the centering
-- autocmd above. Guard the wheel's native scroll so CursorMoved skips re-centering
-- while scrolling; the cursor is left where the scroll leaves it, and the next
-- keyboard move re-centers as usual.
for _, key in ipairs { '<ScrollWheelUp>', '<ScrollWheelDown>' } do
  vim.keymap.set({ 'n', 'i', 'v' }, key, function()
    wheel_scrolling = true
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), 'n', false)
    vim.schedule(function()
      wheel_scrolling = false
    end)
  end)
end

vim.opt.tabstop = 2 -- Display tabs as 2 spaces.
vim.opt.softtabstop = 2 -- Insert 2 spaces per <Tab>.
vim.opt.expandtab = true -- Use spaces instead of tabs.
vim.opt.shiftwidth = 2 -- Indent with 2 spaces.
vim.opt.smartindent = true -- Add indent for new blocks in C-like syntax.
vim.opt.textwidth = 80 -- Line wrap limit.
vim.opt.colorcolumn = '80' -- Draw a vertical line at column 80.
vim.opt.completeopt = 'menuone,noselect' -- Better completion behavior.
vim.opt.cursorline = true -- Highlight current line.
vim.opt.list = true -- Show invisible characters.
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
vim.opt.conceallevel = 1

-- Use ripgrep for :grep, results into the quickfix list (file:line:col:text).
-- <leader>sg / <leader>sw (init.lua) prefill a :grep command from here.
if vim.fn.executable 'rg' == 1 then
  vim.opt.grepprg = 'rg --vimgrep --smart-case'
  vim.opt.grepformat = '%f:%l:%c:%m'
end
-- Quickfix is the temp buffer for <leader>sg / sw: <CR> jumps AND closes, Esc/q
-- close without jumping -- pick-and-dismiss like the other search UIs.
-- Still there to browse with j/k; :cnext/:cprev step without reopening it.
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('qf_jump_close', { clear = true }),
  pattern = 'qf',
  callback = function(ev)
    vim.keymap.set('n', '<CR>', '<CR><cmd>cclose<CR>', { buffer = ev.buf, desc = 'Jump and close quickfix' })
    -- Esc (or q) dismisses the list without jumping, like the other temp UIs.
    vim.keymap.set('n', '<Esc>', '<cmd>cclose<CR>', { buffer = ev.buf, desc = 'Close quickfix' })
    vim.keymap.set('n', 'q', '<cmd>cclose<CR>', { buffer = ev.buf, desc = 'Close quickfix' })
  end,
})

-- Pop the quickfix window open automatically after a :grep.
vim.api.nvim_create_autocmd('QuickFixCmdPost', {
  group = vim.api.nvim_create_augroup('grep_quickfix', { clear = true }),
  pattern = { 'grep', 'grepadd' },
  callback = function()
    if vim.fn.getqflist({ size = 0 }).size == 0 then
      vim.notify('no matches', vim.log.levels.INFO)
    else
      vim.cmd 'botright cwindow'
    end
  end,
})
vim.opt.title = true -- Set terminal/pane title (OSC 2)...
vim.opt.titlestring = '%F' -- ...to full path of current buffer.

vim.keymap.set('n', '<leader>dq', vim.diagnostic.setloclist, { desc = 'Open [d]iagnostic [q]uickfix list' })
vim.keymap.set('n', '<leader>r', vim.diagnostic.open_float, { desc = 'Open floating diagnostic message' })

vim.keymap.set('n', '<leader>w', '<cmd>w<CR>', { desc = '[W]rite buffer' })
vim.keymap.set('n', '<leader>q', '<cmd>q<CR>', { desc = '[Q]uit window' })

-- Diagnostic display: message inline at end of line (virtual_text),
-- underline + gutter sign; <leader>r opens the full float on demand.
vim.diagnostic.config {
  virtual_text = true,
  underline = true, -- squiggle under the offending span
  severity_sort = true, -- errors sort above warnings on the same line
  update_in_insert = false, -- don't churn diagnostics while typing
  float = {
    source = 'if_many', -- border comes from the global winborder above
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

-- Normalize CRLF -> LF in yanked/deleted text (e.g. yanks from CRLF files) so
-- putting it back never introduces ^M. Note: fires on yank, not on paste, so
-- text arriving straight from the system clipboard is not touched.
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function()
    local reg = vim.fn.getreg '"'
    if reg:find '\r' then
      vim.fn.setreg('"', reg:gsub('\r', ''))
    end
  end,
})

-- Keep ~/.edit_history as a most-recent-last list of opened files (dedup in
-- Lua; no shell round-trip, so paths with regex/shell metachars are safe).
vim.api.nvim_create_autocmd('BufReadPost', {
  callback = function()
    local path = vim.fn.expand '%:p'
    if vim.fn.fnamemodify(path, ':t'):find '^%.zshrc' then
      return
    end
    if vim.fn.filereadable(path) ~= 1 then
      return
    end
    local hist = vim.fn.expand '~/.edit_history'
    local lines = vim.fn.filereadable(hist) == 1 and vim.fn.readfile(hist) or {}
    lines = vim.tbl_filter(function(l)
      return l ~= path
    end, lines)
    table.insert(lines, path)
    vim.fn.writefile(lines, hist)
  end,
})

vim.keymap.set('i', 'jk', '<Esc>')

-- Terminals (toggle terminals, :Sh, gf in terminals): lua/custom/term.lua.
require 'custom.term'

-- Note: `K` (LSP hover) and `<leader>K` (definition peek) are mapped per-buffer
-- on LspAttach in init.lua, so they only bind where an LSP is active.
--
-- Neutralize keyword-lookup (`keywordprg`, default `:Man`) where clangd is
-- still attached (objc/objcpp): with `K` bound to LSP hover there, the
-- default :Man handler was opening a man-page split behind the hover float.
-- C/C++ set their own keywordprg in after/plugin/c-tags.lua.
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'objc', 'objcpp' },
  group = vim.api.nvim_create_augroup('NoManKeywordprg', { clear = true }),
  callback = function(ev)
    vim.bo[ev.buf].keywordprg = ''
  end,
})

local clean_token = require('custom.term').clean_token

-- Copy a URL-ish token to the system clipboard, prepending https:// if bare.
local function copy_url(tok)
  local url = tok:match '^https?://' and tok or ('https://' .. tok)
  vim.fn.setreg('+', url)
  vim.notify('URL copied to clipboard: ' .. url, vim.log.levels.INFO)
end

-- Reload files Claude (or anything else) edits on disk while open in nvim
-- ('autoread' is on by default; checktime is what actually polls).
vim.api.nvim_create_autocmd({ 'CursorHold', 'FocusGained', 'BufEnter' }, {
  callback = function()
    if vim.fn.mode() ~= 'c' then
      pcall(vim.cmd, 'checktime')
    end
  end,
})

-- Clipboard provider selection.
-- Over SSH, force OSC 52 so yanks land on the local machine's clipboard.
-- Without this a remote host with its own clipboard tool (pbcopy on the mac)
-- wins provider detection and yanks get stranded in that machine's clipboard.
--
-- Locally inside tmux (no X display here, so xclip is dead and neovim would
-- otherwise auto-fall-back to the OSC 52 provider), route through tmux's own
-- buffer instead. neovim forwards a terminal child's OSC 52 copy (e.g. claude's
-- mouse selection) through this provider; with the OSC 52 provider it re-emits
-- the sequence mid-redraw and the raw escape codes leak into the buffer.
-- `tmux load-buffer -w` writes via a subprocess -- no escape sequence is ever
-- emitted -- and still pushes to the system clipboard via `set-clipboard on`.
if vim.env.SSH_TTY then
  vim.g.clipboard = 'osc52'
elseif vim.env.TMUX then
  vim.g.clipboard = {
    name = 'tmux',
    copy = {
      ['+'] = { 'tmux', 'load-buffer', '-w', '-' },
      ['*'] = { 'tmux', 'load-buffer', '-w', '-' },
    },
    paste = {
      ['+'] = { 'tmux', 'save-buffer', '-' },
      ['*'] = { 'tmux', 'save-buffer', '-' },
    },
    cache_enabled = 0,
  }
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

-- gf: if <cfile> looks like a URL, copy it to the clipboard; otherwise fall
-- back to built-in gf. <cfile> already does the right span detection and is
-- more forgiving than a hand-rolled cursor-overlap regex.
vim.keymap.set('n', 'gf', function()
  local cfile = vim.fn.expand '<cfile>'
  if cfile:match '^https?://' or cfile:match '^www%.' then
    copy_url(clean_token(cfile))
    return
  end
  vim.cmd 'normal! gf'
end, { desc = 'gf: open URL or file under cursor' })

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
vim.keymap.set('n', '<C-z>', '<Nop>', { silent = true })

-- Enable full color support.
vim.opt.termguicolors = true

vim.keymap.set('n', '<leader>wr', ':set wrap!<CR>', { noremap = true, silent = true })

-- Highlight text momentarily after yanking.
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- tidydoc renders into a man-style read-only bottom split.
local function open_man_scratch(name, lines)
  require('custom.term').scratch_split(name, lines, { filetype = 'man', height = math.floor(vim.o.lines / 2) })
end

-- Shift+M: open the man page for the symbol under the cursor via :Man. C++
-- stdlib pages come from stdman (cppreference as man3, /usr/local/man shadows
-- gcc's doxygen pages); C library symbols hit the regular man-pages set. The
-- symbol grab includes `::` qualifiers so std::vector resolves whole.
local function man_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  -- Expand left/right over identifier chars plus ':' so std::vector is whole.
  local s, e = col, col
  local function is_sym(c)
    return c:match '[%w_:]' ~= nil
  end
  while s > 1 and is_sym(line:sub(s - 1, s - 1)) do
    s = s - 1
  end
  while e <= #line and is_sym(line:sub(e, e)) do
    e = e + 1
  end
  local sym = line:sub(s, e - 1):gsub('^:+', ''):gsub(':+$', '')
  if sym == '' then
    vim.notify('No symbol under cursor', vim.log.levels.WARN)
    return
  end

  -- :Man (after/plugin/man-lang.lua) does the lookup: renders natively, and
  -- for a bare name ranks C-library vs std:: pages by buffer language and
  -- offers a picker when ambiguous.
  vim.cmd.Man(sym)
end
vim.keymap.set('n', '<S-m>', man_under_cursor, { desc = 'man page for symbol under cursor' })

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
    'curl -fsSL --compressed %s '
      .. '| pandoc -f html -t man '
      .. "| sed -e 's/¶//g' -e 's/\\\\[|]/ /g' "
      .. '| { printf \'.TH "%s" "clang-tidy" "" "" ""\\n\'; cat; } '
      .. '| MANWIDTH=%d man -l - '
      .. '| col -bx',
    vim.fn.shellescape(url),
    check,
    width
  )

  local out = vim.fn.systemlist { 'sh', '-c', sh }
  if vim.v.shell_error ~= 0 or #out == 0 then
    vim.notify('tidydoc: failed to render ' .. check, vim.log.levels.WARN)
    return
  end

  open_man_scratch('tidydoc://' .. check, out)
end
vim.keymap.set('n', '<leader>td', tidydoc_under_cursor, { desc = 'clang-[t]idy [d]oc for diagnostic on line' })

-- Sticky full path at the top of each buffer (winbar), relative to the repo root.
local function winbar_path(buf)
  local full = vim.api.nvim_buf_get_name(buf)
  if full == '' then
    return ''
  end
  full = vim.fn.fnamemodify(full, ':p')
  -- The upward .git walk never changes for a buffer; cache it (false = no repo).
  local root = vim.b[buf].winbar_git_root
  if root == nil then
    root = vim.fs.root(full, '.git') or false
    vim.b[buf].winbar_git_root = root
  end
  local rel
  if root then
    rel = vim.fs.relpath(root, full) or full
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
    if vim.api.nvim_win_get_config(win).relative ~= '' then
      return
    end -- skip floats
    if vim.bo[ev.buf].buftype ~= '' then
      return
    end -- skip terminal/help/nofile/qf
    if vim.api.nvim_buf_get_name(ev.buf) == '' then
      return
    end -- skip unnamed
    if ev.event == 'BufFilePost' then
      vim.b[ev.buf].winbar_git_root = nil
    end -- rename: re-walk
    vim.wo[win].winbar = winbar_path(ev.buf)
  end,
})

-- Load machine-local overrides if present (colorscheme, etc.)
pcall(require, 'local')
