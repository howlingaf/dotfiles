-- Classic ctags workflow for C and C++ (currently OFF: vim.g.use_ctags in
-- init.lua). When on, it runs alongside clangd: gd/K stay LSP, Ctrl-] here
-- becomes the tags jump. Nothing in this file touches other filetypes.
--
--   Ctrl-]      jump to the definition of the word under the cursor (tags)
--   g Ctrl-]    same, but list every match when a name has several
--   Ctrl-t      jump back (pops the tag stack); :tags shows the stack
--   :tselect X  browse matches for X by name
--   :Ctags      (re)generate the tags file by hand
--   K           man page: C -> :Man c <word>; C++ -> :Man <word> (std:: first)
--   <leader>a   tag history -> definitions: q/w/a/s top four, j/k+Enter, Esc
--
-- The tags file is regenerated in the background on every save of a C/C++ file,
-- so it's rarely stale. 'tags' keeps its default "./tags;,tags", which walks
-- up from the file's directory until it finds one.

-- Plain .h files are C here, not C++ (Neovim's default guess). Headers with
-- real C++ content (class, template, namespace...) still detect as cpp.
-- (Independent of the tags workflow, so it stays on either way.)
vim.g.c_syntax_for_h = 1

-- Everything below is gated on vim.g.use_ctags (init.lua); off means no
-- ctags regeneration, no tag maps, no picker, no stack persistence.
if not vim.g.use_ctags then
  return
end

local project_root = require('custom.project').root
local tagstack_picker, save_tagstack -- defined below; used by the FileType autocmd first

-- vim.notify with a Lua/Vim error message trimmed to its E-code.
local function notify_err(err)
  vim.notify((tostring(err):gsub('^.-:E', 'E')), vim.log.levels.ERROR)
end

local function generate(buf, on_done)
  if vim.fn.executable 'ctags' ~= 1 then
    vim.notify('ctags not installed (pacman -S ctags)', vim.log.levels.WARN)
    return
  end
  local root = project_root(buf)
  vim.system({ 'ctags', '-R', '--languages=C,C++', '-f', root .. '/tags', root }, { text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        vim.notify('ctags failed: ' .. (res.stderr or ''), vim.log.levels.ERROR)
      elseif on_done then
        on_done(root)
      end
    end)
  end)
end

vim.api.nvim_create_user_command('Ctags', function()
  generate(0, function(root)
    vim.notify('tags written to ' .. root .. '/tags')
  end)
end, { desc = 'Regenerate the C tags file for this project' })

local group = vim.api.nvim_create_augroup('CTags', { clear = true })

vim.api.nvim_create_autocmd('BufWritePost', {
  group = group,
  pattern = { '*.c', '*.h', '*.cpp', '*.hpp', '*.cc', '*.hh', '*.cxx' },
  callback = function(ev)
    generate(ev.buf)
  end,
})

-- Tag jumps land on the NAME, not column 1. A tags entry is a line pattern
-- (/^void compile(...)$/) with no column info, so Vim stops at the start of
-- the line; after the jump, move to the first whole-word match of the tag on
-- that line. Wraps the jump keys in C buffers plus the picker's forward jump.
local function land_on(name)
  vim.fn.search('\\V\\<' .. vim.fn.escape(name, '\\') .. '\\>', 'c', vim.fn.line '.')
end

local function tag_jump(cmd)
  local word = vim.fn.expand '<cword>'
  if word == '' then
    return
  end
  local ok, err = pcall(vim.cmd, cmd .. ' ' .. word)
  if not ok then
    notify_err(err)
    return
  end
  land_on(word)
end

-- Per-buffer setup for C/C++. K -> man page: C uses the `c` prefix
-- (sections 2/3); C++ the bare form, whose picker ranks stdman's std::
-- pages first in cpp buffers. <leader>a is not a prefix of any other
-- mapping, so it fires with no timeoutlen delay.
vim.api.nvim_create_autocmd('FileType', {
  group = group,
  pattern = { 'c', 'cpp' },
  callback = function(ev)
    local buf = ev.buf
    vim.bo[buf].keywordprg = ev.match == 'c' and ':Man c' or ':Man'
    vim.keymap.set('n', '<leader>a', function()
      tagstack_picker()
    end, { buffer = buf, desc = 'Tag stack picker' })
    vim.keymap.set('n', '<C-]>', function()
      tag_jump 'tag'
    end, { buffer = buf, desc = 'Jump to tag' })
    vim.keymap.set('n', 'g<C-]>', function()
      tag_jump 'tjump'
    end, { buffer = buf, desc = 'Jump to tag (list if several)' })
    vim.keymap.set('n', '<C-w>]', function()
      tag_jump 'stag'
    end, { buffer = buf, desc = 'Jump to tag in split' })
    -- Persist the tag stack (below) on every jump/pop in this buffer.
    vim.api.nvim_create_autocmd('CursorMoved', {
      group = group,
      buffer = buf,
      callback = function()
        save_tagstack()
      end,
    })
  end,
})

-- Tag history in a bottom split (where :tags prints): the definitions you've
-- jumped to, newest first, one row per tag, each with the path of the file
-- it lives in. Picking a row jumps to that definition (a fresh :tag, landing on
-- the name), so the picker is "go back to a definition I looked at", while
-- Ctrl-t remains the way to unwind to where you came from. q/w/a/s pick the
-- top four rows; deeper rows are j/k + Enter. Esc closes.

-- The path of the file a tag is defined in, relative to `root`.
local function tag_location(name, root)
  local t = vim.fn.taglist('^' .. vim.fn.escape(name, '^$.*[]~\\') .. '$')[1]
  if not t then
    return nil
  end
  local path = vim.fn.fnamemodify(t.filename, ':p')
  return vim.fs.relpath(root, path) or path
end

function tagstack_picker()
  local stack = vim.fn.gettagstack(0)
  if stack.length == 0 then
    vim.notify('tag stack empty', vim.log.levels.INFO)
    return
  end
  local hotkeys = { 'q', 'w', 'a', 's' }
  local root = project_root(0)
  local rows, seen = {}, {}
  for i = stack.length, 1, -1 do
    local name = stack.items[i].tagname
    if not seen[name] then
      seen[name] = true
      -- Entries with no tag (man-page cross-refs like strlen(3) jumped to
      -- with Ctrl-] inside a man page share this stack) are left out.
      local where = tag_location(name, root)
      if where then
        local n = #rows + 1
        rows[n] = { key = hotkeys[n], tag = name, where = where }
      end
    end
  end
  if #rows == 0 then
    vim.notify('tag stack empty', vim.log.levels.INFO)
    return
  end
  local lines = {}
  for n, r in ipairs(rows) do
    lines[n] = (' %s  %-18s %s'):format(r.key or ' ', r.tag, r.where)
  end
  local buf, win, close = require('custom.term').scratch_split('tagstack://', lines, { cursorline = true })
  local function go(n)
    local r = rows[n]
    close()
    if not r then
      return
    end
    local ok, err = pcall(vim.cmd.tag, r.tag)
    if not ok then
      notify_err(err)
      return
    end
    land_on(r.tag)
  end
  local opts = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set('n', '<CR>', function()
    go(vim.api.nvim_win_get_cursor(win)[1])
  end, opts)
  for n, r in ipairs(rows) do
    if r.key then
      vim.keymap.set('n', r.key, function()
        go(n)
      end, opts)
    end
  end
end

-- Persist the tag stack across sessions, zsh-history style. Vim keeps the
-- stack per window in memory only, so it's written to one JSON file per
-- project under stdpath('state')/tagstack/ every time it changes, and the
-- first C buffer opened in that project restores it into its window. There is
-- no "tag jump" event, but every jump/pop moves the cursor, so a buffer-local
-- CursorMoved (registered per C/C++ buffer above) plus a cheap shape check
-- (length, position, top entry) catches Ctrl-], g Ctrl-], Ctrl-t, :tag and
-- :pop alike; the write itself is debounced. VimLeavePre is only a backstop.
-- Entries reference buffer numbers, which don't survive a restart, so paths
-- are stored instead and re-resolved with bufadd() on load.
local stack_dir = vim.fn.stdpath 'state' .. '/tagstack'
vim.fn.mkdir(stack_dir, 'p')
local function stack_file(root)
  return stack_dir .. '/' .. root:gsub('[/\\:]', '%%') .. '.json'
end

local last_shape -- per-window would be more precise; one window is the norm
local write_timer, pending
local function flush()
  write_timer = nil
  if not pending then
    return
  end
  local f = io.open(pending.path, 'w')
  if f then
    f:write(pending.payload)
    f:close()
  end
  pending = nil
end
function save_tagstack()
  local buf = vim.api.nvim_get_current_buf()
  local stack = vim.fn.gettagstack(0)
  local top = stack.items[#stack.items]
  local shape = ('%d:%d:%s'):format(stack.length, stack.curidx, top and top.tagname or '')
  if shape == last_shape then
    return
  end
  last_shape = shape
  local items = {}
  for _, it in ipairs(stack.items) do
    local from = it.from
    items[#items + 1] = {
      tagname = it.tagname,
      matchnr = it.matchnr,
      from = { vim.api.nvim_buf_get_name(from[1]), from[2], from[3], from[4] },
      bufname = it.bufnr and vim.api.nvim_buf_get_name(it.bufnr) or nil,
    }
  end
  pending = { path = stack_file(project_root(buf)), payload = vim.json.encode { items = items, curidx = stack.curidx } }
  -- Debounce: a burst of Ctrl-]/Ctrl-t costs one write.
  if write_timer then
    write_timer:stop()
  end
  write_timer = vim.defer_fn(flush, 200)
end

local restored = {} -- root -> true, so a project restores once per session
local function restore_tagstack(buf)
  if vim.fn.gettagstack(0).length > 0 then
    return
  end
  local root = project_root(buf)
  if restored[root] then
    return
  end
  restored[root] = true
  local f = io.open(stack_file(root), 'r')
  if not f then
    return
  end
  local ok, data = pcall(vim.json.decode, f:read '*a')
  f:close()
  if not ok or type(data) ~= 'table' or not data.items then
    return
  end
  local items = {}
  for _, it in ipairs(data.items) do
    if vim.fn.filereadable(it.from[1]) == 1 then
      items[#items + 1] = {
        tagname = it.tagname,
        matchnr = it.matchnr,
        from = { vim.fn.bufadd(it.from[1]), it.from[2], it.from[3], it.from[4] },
        bufnr = it.bufname and it.bufname ~= '' and vim.fn.bufadd(it.bufname) or nil,
      }
    end
  end
  if #items > 0 then
    vim.fn.settagstack(0, { items = items, curidx = math.min(data.curidx or #items + 1, #items + 1) }, 'r')
  end
end

vim.api.nvim_create_autocmd('VimLeavePre', {
  group = group,
  callback = function()
    local ft = vim.bo.filetype
    if ft == 'c' or ft == 'cpp' then
      save_tagstack()
    end
    if write_timer then
      write_timer:stop()
    end
    flush()
  end,
})
vim.api.nvim_create_autocmd('FileType', {
  group = group,
  pattern = { 'c', 'cpp' },
  callback = function(ev)
    restore_tagstack(ev.buf)
  end,
})
