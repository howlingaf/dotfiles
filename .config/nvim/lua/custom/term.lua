-- Terminals: the persistent toggle terminals (<C-Space> Claude, <S-Space>
-- shell), throwaway command splits (:Sh / M.run), opening files from inside a
-- terminal (M.open_file, called from the zsh nvim() wrapper over RPC), the
-- terminal-mode "vim" key maps, and gf inside terminals (term_goto).
local M = {}

-- Terminal-mode "vim" maps (jk escape) intercept keys that shells and TUIs
-- want for themselves. They're applied buffer-locally on TermOpen so <C-q>
-- can toggle them per terminal, and a terminal can opt out at creation by
-- setting vim.b.term_vim = false before termopen (the shell scratchpad does
-- this — it types like a plain terminal by default).
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

-- Terminal toggles. Each instance has its own persistent buffer;
-- killed only when its command `exit`s or the buffer is :bd!'d.
local Term -- forward declared so closures in write_parent_state can reference it

-- Registry of all toggle terminals, so each toggle can detect a sibling that
-- is currently shown and switch/hide instead of stacking a second one.
local terms = {}
local function visible_term()
  for _, t in ipairs(terms) do
    if t.win and vim.api.nvim_win_is_valid(t.win) then
      return t
    end
  end
end

-- Path the claude shell reads to learn what file/line/col the parent was on.
-- Per-nvim-instance so multiple nvims don't clobber each other.
local parent_state_path = vim.fn.stdpath 'run' .. '/nvim-term-parent-' .. vim.fn.getpid()

local function write_parent_state()
  if not Term or not Term.caller_file then
    return
  end
  local fd = io.open(parent_state_path, 'w')
  if not fd then
    return
  end
  local line = Term.caller_pos and Term.caller_pos[1] or 0
  local col = Term.caller_pos and (Term.caller_pos[2] + 1) or 0
  fd:write(Term.caller_file .. '\n' .. line .. '\n' .. col .. '\n')
  fd:close()
end

-- Env a toggle terminal's child inherits so it can find the parent cursor:
-- NVIM_PARENT_STATE points at the live state file (refreshed on every cursor
-- move); the FILE/LINE/COL vars are the snapshot from when the float opened.
local function parent_env(T)
  return {
    NVIM_PARENT_STATE = parent_state_path,
    NVIM_PARENT_FILE = T.caller_file or '',
    NVIM_PARENT_LINE = tostring(T.caller_pos and T.caller_pos[1] or 0),
    NVIM_PARENT_COL = tostring(T.caller_pos and (T.caller_pos[2] + 1) or 0),
  }
end

-- Keep the parent-state file live: refresh on cursor move / buffer switch in
-- any real file buffer, so the shell sees the user's current position even
-- while the terminal is open. The position is always tracked in
-- memory, but the file is only written once the Claude terminal exists --
-- otherwise every cursor move would do file I/O for a reader that isn't there.
vim.api.nvim_create_autocmd({ 'BufEnter', 'CursorMoved', 'CursorMovedI', 'InsertLeave' }, {
  group = vim.api.nvim_create_augroup('TermParentState', { clear = true }),
  callback = function(ev)
    if not Term then
      return
    end
    if vim.bo[ev.buf].buftype ~= '' then
      return
    end
    local name = vim.api.nvim_buf_get_name(ev.buf)
    if name == '' then
      return
    end
    Term.caller_file = name
    Term.caller_pos = vim.api.nvim_win_get_cursor(0)
    if Term.buf and vim.api.nvim_buf_is_valid(Term.buf) then
      write_parent_state()
    end
  end,
})

-- Bottom split, :Man-style: full width along the bottom, `frac` of the
-- screen tall (min 10 rows). Returns the new window (current afterwards).
local function bottom_split(frac)
  vim.cmd(('botright %dsplit'):format(math.max(10, math.floor(vim.o.lines * (frac or 0.4)))))
  return vim.api.nvim_get_current_win()
end

-- A toggleable, persistent terminal in a bottom split. opts.height is the
-- split's fraction of the screen (default 0.4); opts.tui forces a repaint on
-- every re-show (for full-screen TUIs like Claude).
local function make_term(cmd, opts)
  opts = opts or {}
  local T = { buf = nil, win = nil, last_view = nil, last_mode = nil }

  function T.open()
    local fresh = not (T.buf and vim.api.nvim_buf_is_valid(T.buf))
    if fresh then
      T.buf = vim.api.nvim_create_buf(false, true)
    end
    T.win = bottom_split(type(opts.height) == 'function' and opts.height(T) or opts.height)
    vim.api.nvim_win_set_buf(T.win, T.buf)
    vim.wo[T.win].scrolloff = 999
    if fresh or vim.bo[T.buf].buftype ~= 'terminal' then
      if opts.term_vim == false then
        vim.b[T.buf].term_vim = false
      end
      T.job = vim.fn.jobstart(cmd, { term = true, env = opts.env and opts.env(T) or nil })
      vim.cmd 'startinsert'
      return
    end
    vim.api.nvim_set_current_win(T.win)
    if opts.tui then
      -- A full-screen TUI (Claude's Ink UI) redraws in place and keeps
      -- streaming while the buffer had no window; nothing tells it to repaint
      -- on re-show and stale/partial frames result. Nudge the pty size by one
      -- column and back: the SIGWINCH makes it redraw from scratch. The TUI
      -- owns its screen, so there's no scroll position worth restoring.
      local rows, cols = vim.api.nvim_win_get_height(T.win), vim.api.nvim_win_get_width(T.win)
      pcall(vim.fn.jobresize, T.job, cols - 1, rows)
      vim.defer_fn(function()
        pcall(vim.fn.jobresize, T.job, cols, rows)
      end, 30)
      vim.cmd 'startinsert'
      return
    end
    -- If caller was in insert in their buffer, vim auto-enters terminal-job
    -- mode when focus lands on a terminal buffer, which auto-follows the
    -- terminal cursor (bottom). Force terminal-normal before restoring view.
    if T.last_mode ~= 't' then
      vim.cmd 'stopinsert'
    end
    if T.last_view then
      vim.fn.winrestview(T.last_view)
    end
    if T.last_mode == 't' then
      vim.cmd 'startinsert'
    end
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
          if vim.bo.buftype ~= '' then
            return
          end
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
      local sibling = visible_term()
      if sibling and sibling ~= T then
        -- Another terminal is up. Inherit ITS real-editor caller (not the
        -- sibling's window) so hiding T later returns to the editor instead of
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
      if opts.on_open then
        opts.on_open(T)
      end
      T.open()
    end
  end

  table.insert(terms, T)
  return T
end

Term = make_term({ 'claude', '-c' }, {
  tui = true, -- force a repaint on re-show (see make_term)
  height = 0.6, -- Claude's UI wants more room than the 40% shell split
  term_vim = false,
  env = parent_env,
  on_open = function()
    write_parent_state()
  end,
})

for _, key in ipairs { '<C-Space>', '<C-@>', '<NUL>' } do
  vim.keymap.set({ 'n', 'i', 't' }, key, Term.toggle, { desc = 'Toggle bottom Claude terminal' })
end
-- Shell split height: 60% (same as Claude) while gdb is running in it, else
-- the usual 40%. Checked on each show, so toggle the shell away and back
-- after starting gdb to get the room (Ctrl-w _ maximises on the spot).
local BIG_PROCS = { 'gdb' }
local function shell_height(T)
  local ok, pid = pcall(vim.fn.jobpid, T.job or -1)
  if not ok or not pid or pid <= 0 then
    return 0.4
  end
  local kids = vim.fn.systemlist { 'ps', '-o', 'args=', '--ppid', tostring(pid) }
  for _, line in ipairs(kids) do
    for _, name in ipairs(BIG_PROCS) do
      if line:find(name, 1, true) then
        return 0.6
      end
    end
  end
  return 0.4
end

local ShellTerm = make_term({ vim.o.shell }, {
  term_vim = false,
  height = shell_height,
  env = parent_env,
  on_open = function()
    write_parent_state()
  end,
})
vim.keymap.set({ 'n', 'i', 't' }, '<S-Space>', ShellTerm.toggle, { desc = 'Toggle bottom shell terminal' })

-- Open a file from inside a terminal (the nvim() wrapper in .zshrc calls
-- M.open_file over $NVIM when it's run in a :terminal): hide whichever terminal is
-- visible, go back to the window it was toggled from, and edit the file
-- there -- so picking a file with ^S in the shell lands you in it directly.
-- :Sh <cmd> (M.run) -- run a command directly in a throwaway bottom split, with no
-- interactive shell in between, so it starts instantly (a fresh zsh with
-- oh-my-zsh takes a few hundred ms, which is the <leader>sd lag). The command
-- runs via `sh -c` so pipes/globs work. Esc kills it and closes the split;
-- when the command exits on its own the output stays up until Esc/q/<CR>,
-- so a one-shot `make` isn't lost the instant it finishes.
--   :Sh ./watcher.sh prod      :Sh make test      :Sh zsh   (interactive)
--   :70Sh gdb ./a.out          (count = height as a percentage of the screen)
-- opts.close_on_exit: tear the split down as soon as the command exits
-- (for pickers whose result comes back another way); default keeps output up.
-- opts.height: fraction of the screen (default 0.4).
function M.run(cmd, opts)
  opts = opts or {}
  local caller = vim.api.nvim_get_current_win()
  local win = bottom_split(opts.height)
  vim.cmd 'enew'
  local buf = vim.api.nvim_get_current_buf()
  vim.b[buf].term_vim = false
  vim.b[buf].__is_temp_shell = true
  vim.b[buf].__temp_caller = caller
  vim.wo[win].scrolloff = 0
  vim.fn.jobstart({ 'sh', '-c', cmd }, { term = true })
  vim.cmd.startinsert()
  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
    if vim.api.nvim_win_is_valid(caller) then
      vim.api.nvim_set_current_win(caller)
    end
  end
  vim.keymap.set('t', '<Esc>', close, { buffer = buf, desc = 'Kill and close' })
  vim.keymap.set('n', '<Esc>', close, { buffer = buf, desc = 'Close' })
  -- After exit, drop to normal mode (output readable, scrollable) and let
  -- q / <CR> close as well as Esc.
  vim.api.nvim_create_autocmd('TermClose', {
    buffer = buf,
    once = true,
    callback = function()
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(buf) then
          return
        end
        if opts.close_on_exit then
          close()
          return
        end
        vim.cmd.stopinsert()
        vim.keymap.set('n', 'q', close, { buffer = buf })
        vim.keymap.set('n', '<CR>', close, { buffer = buf })
      end)
    end,
  })
end

vim.api.nvim_create_user_command('Sh', function(o)
  M.run(o.args, { height = o.count > 0 and math.min(o.count, 95) / 100 or nil })
end, { nargs = '+', count = 0, complete = 'shellcmd', desc = 'Run a command in a throwaway split (:NSh = N% tall)' })

function M.open_file(path)
  vim.schedule(function()
    local curbuf = vim.api.nvim_get_current_buf()
    local target
    if vim.b[curbuf].__is_temp_shell then
      -- Ran from a throwaway shell (e.g. <leader>sf ^S): close it entirely.
      target = vim.b[curbuf].__temp_caller
      local curwin = vim.api.nvim_get_current_win()
      if vim.api.nvim_win_is_valid(curwin) then
        vim.api.nvim_win_close(curwin, true)
      end
      pcall(vim.api.nvim_buf_delete, curbuf, { force = true })
    else
      -- Persistent toggle terminal: hide it, keep the session.
      local t = visible_term()
      if t then
        target = t.caller_win
        t.hide()
      end
    end
    if target and vim.api.nvim_win_is_valid(target) then
      vim.api.nvim_set_current_win(target)
    end
    vim.cmd.edit(vim.fn.fnameescape(path))
  end)
end

-- Strip wrapping punctuation/brackets from a token (shared by term_goto's
-- classifier and the URL copiers in custom/settings).
local function clean_token(tok)
  tok = tok:gsub('^[%(%[%{\'"`]+', ''):gsub('[%)%]%}\'",;:%.]+$', '')
  return tok
end

-- In a :terminal buffer, `gf` and `gd` resolve the token under the cursor
-- (URL, or path with optional :LINE:COL) and open it in the underlying
-- real editor window — the toggle terminal hides itself first. No LSP
-- lookup happens here; the terminal buffer has no client.
local function term_goto()
  local buf = vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  -- Only a window of scrollback around the cursor -- the wrap-stitching below
  -- never reaches further, and a terminal can hold tens of thousands of lines.
  local first = math.max(0, row - 100)
  local lines = vim.api.nvim_buf_get_lines(buf, first, row + 100, false)
  row = row - first
  local line = lines[row]

  -- A terminal hard-wraps long output across buffer lines with no separator, so
  -- a path can be split across rows. The reliable wrap signal is that the source
  -- line is full-width (filled to the window width); a shorter line ended for
  -- real. The continuation may carry a leading margin -- shells wrap flush to
  -- column 1, but a TUI like Claude indents every line -- so on each next/prev
  -- line we skip leading whitespace before taking its content run. filereadable()
  -- below still confirms the result and we fall back to the single-line token, so
  -- non-wrapped output behaves exactly as before.
  local width = vim.api.nvim_win_get_width(0)
  local function full(l)
    return l ~= nil and #l >= width
  end

  local s, e = col, col
  while s > 1 and not line:sub(s - 1, s - 1):match '%s' do
    s = s - 1
  end
  while e <= #line and not line:sub(e, e):match '%s' do
    e = e + 1
  end
  local single = line:sub(s, e - 1)

  local joined = single
  -- forward: token reaches the end of a full-width line -> the next line is a
  -- wrap continuation; skip its leading margin and append its content run.
  local r, endcol = row, e - 1
  while endcol == #lines[r] and full(lines[r]) and lines[r + 1] do
    local nxt = lines[r + 1]
    local a = 1
    while a <= #nxt and nxt:sub(a, a):match '%s' do
      a = a + 1
    end
    if a > #nxt then
      break
    end
    local j = a
    while j <= #nxt and nxt:sub(j, j):match '%S' do
      j = j + 1
    end
    joined = joined .. nxt:sub(a, j - 1)
    r, endcol = r + 1, j - 1
  end
  -- backward: token sits at the content start of its line (only margin before
  -- it) and the previous line is full-width -> prepend that line's content run.
  local r2, tline, tstart = row, line, s
  while full(lines[r2 - 1]) and tline:sub(1, tstart - 1):match '^%s*$' do
    local prv = lines[r2 - 1]
    local a = 1
    while a <= #prv and prv:sub(a, a):match '%s' do
      a = a + 1
    end
    joined = prv:sub(a) .. joined
    r2, tline, tstart = r2 - 1, prv, a
  end

  local stripped = single:gsub('^[%(%[%{\'"`]+', '')
  if stripped:match '^https?://' or stripped:match '^www%.' then
    copy_url(clean_token(joined))
    return
  end

  -- Resolve a token to a readable file (with optional :LINE:COL); nil if not.
  local function classify(tok)
    tok = clean_token(tok)
    local p, lnum, cnum = tok:match '^(.-):(%d+):(%d+)$'
    if not p then
      p, lnum = tok:match '^(.-):(%d+)%-%d+$'
    end
    if not p then
      p, lnum = tok:match '^(.-):(%d+)$'
    end
    if not p then
      p = tok
    end
    if p:sub(1, 1) == '~' then
      p = vim.fn.expand(p)
    end
    if p:sub(1, 1) ~= '/' then
      p = vim.fn.getcwd() .. '/' .. p
    end
    p = vim.fn.fnamemodify(p, ':p')
    if vim.fn.filereadable(p) ~= 1 then
      return nil
    end
    return { path = p, lnum = tonumber(lnum), cnum = tonumber(cnum) }
  end

  -- Prefer the stitched token; fall back to the single cursor line.
  local res = classify(joined) or classify(single)
  if not res then
    vim.notify('Not a file: ' .. joined, vim.log.levels.WARN)
    return
  end
  local path, lnum, cnum = res.path, res.lnum, res.cnum

  local target
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if (vim.api.nvim_win_get_config(w).relative or '') == '' then
      target = w
      break
    end
  end
  -- Hide whichever toggle terminal is up -- gf is mapped in every terminal
  -- (Claude, shell, plain :terminal), not just the Claude one.
  local float = visible_term()
  if float then
    float.hide()
  end
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

-- Read-only scratch buffer in a bottom split, for pickers and rendered text
-- (tag-stack picker, :Man picker, tidydoc). `lines` fill it; opts.height is
-- rows (default #lines), opts.filetype and opts.cursorline are optional.
-- q / <Esc> close it and return to the window you came from. Returns
-- buf, win, close so callers can add their own keys.
function M.scratch_split(name, lines, opts)
  opts = opts or {}
  local origin = vim.api.nvim_get_current_win()
  vim.cmd(('botright %dnew'):format(opts.height or #lines))
  local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  if opts.filetype then
    vim.bo[buf].filetype = opts.filetype
  end
  vim.api.nvim_buf_set_name(buf, name)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'
  vim.wo[win].list = false
  vim.wo[win].cursorline = opts.cursorline or false
  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if vim.api.nvim_win_is_valid(origin) then
      vim.api.nvim_set_current_win(origin)
    end
  end
  local kopts = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set('n', 'q', close, kopts)
  vim.keymap.set('n', '<Esc>', close, kopts)
  return buf, win, close
end

-- Scroll the terminal window that process `pid` is running in so the last
-- line containing `marker` sits at the top of the window. watcher.sh calls
-- this over RPC after every pass, so its output is read from the top without
-- scrolling back. The window is dropped out of terminal mode first: in
-- terminal mode the view follows new output; in normal mode it stays put.
function M.scroll_to_marker(pid, marker)
  local anc = {}
  local p = tonumber(pid)
  while p and p > 1 do
    anc[p] = true
    local f = io.open('/proc/' .. p .. '/status')
    if not f then
      break
    end
    p = tonumber(f:read('*a'):match 'PPid:%s*(%d+)')
    f:close()
  end
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buftype == 'terminal' then
      local ok, jp = pcall(vim.fn.jobpid, vim.bo[b].channel)
      if ok and anc[jp] then
        local win = vim.fn.bufwinid(b)
        if win == -1 then
          return
        end
        local lines = vim.api.nvim_buf_get_lines(b, 0, -1, false)
        for i = #lines, 1, -1 do
          if lines[i]:find(marker, 1, true) then
            if vim.api.nvim_get_current_win() == win then
              vim.cmd.stopinsert()
            end
            vim.api.nvim_win_set_cursor(win, { i, 0 })
            vim.api.nvim_win_call(win, function()
              vim.cmd 'normal! zt'
            end)
            return
          end
        end
        return
      end
    end
  end
end

M.bottom_split = bottom_split
M.visible = visible_term
M.clean_token = clean_token
M.shell = ShellTerm
M.claude = Term

return M
