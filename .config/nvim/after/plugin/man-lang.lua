-- Smarter :Man front end.
--
--   :Man printf      -> all exact matches across sections AND std:: pages;
--                       opens directly when unique, otherwise a picker in
--                       a bottom split (CR/1-9 choose, q/Esc cancel).
--   :Man c printf    -> printf(3); C-only: section 2 syscalls, then 3.
--   :Man cpp vector  -> std::vector(3), the stdman/cppreference pages.
--   :Man 3 printf    -> plain section numbers still work, no picker.
--   :Man! / :Man     -> pager mode / word under cursor, unchanged.
--
-- Lives in after/plugin/ so it loads after the runtime's plugin/man.lua and
-- can redefine the command; nvim_create_user_command overwrites like :command!.

-- open_page doesn't throw on a missing page -- it returns an error string --
-- so success is "pcall ok AND no error returned".
local function try_open(count, smods, fargs)
  local ok, err = pcall(require('man').open_page, count, smods, fargs)
  return ok and err == nil
end

-- Exact page candidates for a bare name, via the whatis DB (man -f): unlike
-- man -aw it resolves alias entries (realloc lives in malloc.3.gz and would
-- vanish under a filename filter) and carries the one-line description. The
-- exact-name check matters because man also does case-insensitive lookups
-- (printf would otherwise pull in OCaml's Printf(3o)).
local function collect(n)
  local items, seen = {}, {}
  local cmd = ('man -f %s 2>/dev/null'):format(vim.fn.shellescape(n))
  for _, l in ipairs(vim.fn.systemlist { 'sh', '-c', cmd }) do
    local pname, sect, desc = l:match '^(%S+)%s+%(([^)]+)%)%s+%-%s+(.*)'
    if pname == n and not seen[sect] then
      seen[sect] = true
      items[#items + 1] = {
        sect = sect,
        ref = ('%s(%s)'):format(pname, sect),
        -- stdman pages index as "(unknown subject)"; drop that noise
        desc = desc ~= '(unknown subject)' and desc or nil,
      }
    end
  end
  -- Prefer native numeric sections: POSIX/foreign twins (3p, 1p, 3perl, 3o)
  -- shadow nearly every libc name and would force a picker on unambiguous
  -- lookups like strlen. They still open explicitly (:Man 3p strlen) and
  -- still surface here when nothing native matches.
  local native = vim.tbl_filter(function(it)
    return it.sect:match '^%d+$' ~= nil
  end, items)
  return #native > 0 and native or items
end

-- stdman's pages live under /usr/local/man, which pacman's mandb hook does
-- not index, so the whatis DB can't see std:: names. Resolve those by path
-- instead: stdman keeps one file per symbol, so the basename IS the name and
-- the alias problem whatis solves for libc doesn't exist here.
local function collect_std(n)
  local items, seen = {}, {}
  local cmd = ('man -aw %s 2>/dev/null'):format(vim.fn.shellescape(n))
  for _, p in ipairs(vim.fn.systemlist { 'sh', '-c', cmd }) do
    local base = vim.fs.basename(p):gsub('%.gz$', '')
    local pname, sect = base:match '^(.*)%.([^.]+)$'
    if pname == n and not seen[base] then
      seen[base] = true
      items[#items + 1] = { sect = sect, ref = ('%s(%s)'):format(pname, sect) }
    end
  end
  return items
end

-- stdman also ships std:: twins of the entire C library (std::strlen), which
-- would make every libc lookup ambiguous. Weigh them by buffer language:
-- C buffers see std:: pages only as a fallback, C++ buffers see them first,
-- anywhere else both sets are offered.
-- Memoized per (filetype, name): man's page set doesn't change mid-session
-- and each lookup is two synchronous shell-outs.
local cand_cache = {}
local function candidates(name)
  local ft = vim.bo.filetype
  local key = ft .. '\0' .. name
  if cand_cache[key] then
    return cand_cache[key]
  end
  local plain = collect(name)
  local out
  if name:find '^std::' then
    out = plain
  elseif ft == 'c' then
    -- std:: is only a fallback in C; skip the second shell-out when unneeded.
    out = #plain > 0 and plain or collect_std('std::' .. name)
  elseif ft == 'cpp' then
    out = vim.list_extend(collect_std('std::' .. name), plain)
  else
    out = vim.list_extend(plain, collect_std('std::' .. name))
  end
  cand_cache[key] = out
  return out
end

-- Picker in a bottom split (like the tag-stack picker): one candidate per
-- line, cursorline for focus, CR or a number picks, q/Esc cancels and
-- returns to the window you came from.
local function pick(items, on_choice)
  local lines = {}
  for i, it in ipairs(items) do
    lines[i] = string.format(' %d  %-16s %s', i, it.ref, it.desc or '')
  end
  local buf, win, close = require('custom.term').scratch_split('manpick://', lines, { cursorline = true })
  local function choose(i)
    i = i or vim.api.nvim_win_get_cursor(win)[1]
    close()
    on_choice(items[i])
  end
  local opts = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set('n', '<CR>', function()
    choose()
  end, opts)
  for i = 1, math.min(#items, 9) do
    vim.keymap.set('n', tostring(i), function()
      choose(i)
    end, opts)
  end
end

vim.api.nvim_create_user_command('Man', function(params)
  local man = require 'man'
  if params.bang then
    man.init_pager()
    return
  end

  local lang, name = params.fargs[1], params.fargs[2]
  if lang == 'c' and name then
    -- Section 2 (syscalls) before 3 (C library). Can't just attempt opens in
    -- order: man.lua's _find_path silently falls back to ANY section on a
    -- miss (sect 2 + printf would open printf(1)), and section lookups
    -- prefix-match subsections (sect 3 + open finds open(3perl)). So resolve
    -- the path first and only open when its section matches exactly.
    -- man._find_path is private API; if a Neovim upgrade removes it, fall
    -- back to plain attempts (loses the exact-section check, keeps K working).
    local resolve = type(man._find_path) == 'function' and man._find_path or nil
    for _, sect in ipairs { '2', '3' } do
      if resolve then
        local ok, path = pcall(resolve, name, sect)
        local psect = ok and path and (path:match '%.([^%.]+)%.gz$' or path:match '%.([^%.]+)$')
        if psect == sect and try_open(params.count, params.smods, { sect, name }) then
          return
        end
      elseif try_open(params.count, params.smods, { sect, name }) then
        return
      end
    end
    vim.notify('no C man page for "' .. name .. '"', vim.log.levels.WARN)
    return
  elseif lang == 'cpp' and name then
    if not name:find '^std::' then
      name = 'std::' .. name
    end
    if not try_open(params.count, params.smods, { name }) then
      vim.notify('no C++ man page for "' .. name .. '"', vim.log.levels.WARN)
    end
    return
  end

  -- Bare single-name lookup (no count prefix, no explicit "name(sect)"):
  -- collect every exact match and let the user pick when ambiguous.
  local q = params.fargs[1]
  if #params.fargs == 1 and params.count < 0 and not q:find '%(' then
    local items = candidates(q)
    if #items == 1 then
      if not try_open(-1, params.smods, { items[1].ref }) then
        vim.notify('no man page for "' .. q .. '"', vim.log.levels.WARN)
      end
      return
    elseif #items > 1 then
      pick(items, function(it)
        if it and not try_open(-1, params.smods, { it.ref }) then
          vim.notify('failed to open ' .. it.ref, vim.log.levels.WARN)
        end
      end)
      return
    end
    -- zero candidates: fall through so man.lua produces its usual error
    -- (covers spelling fixups like space->underscore it does internally).
  end

  local _, err = pcall(man.open_page, params.count, params.smods, params.fargs)
  if err then
    vim.notify('man.lua: ' .. err, vim.log.levels.ERROR)
  end
end, {
  bang = true,
  bar = true,
  range = true,
  addr = 'other',
  nargs = '*',
  complete = function(arg_lead, cmd_line, cursor_pos)
    local man = require 'man'
    -- Rewrite the cmd_line the completer sees so candidates match the lang:
    -- after `cpp`, complete among std:: pages; after `c`, section 3.
    if cmd_line:find '^Man%s+cpp%s+' then
      local lead = arg_lead:find '^std::' and arg_lead or ('std::' .. arg_lead)
      return man.man_complete(lead, 'Man ' .. lead)
    elseif cmd_line:find '^Man%s+c%s+' then
      return man.man_complete(arg_lead, 'Man 3 ' .. arg_lead)
    end
    return man.man_complete(arg_lead, cmd_line, cursor_pos)
  end,
})

-- <leader><leader>: drop into the command line with `:Man ` typed, ready for a
-- name (tab completion works from here). Deliberately not <cmd>/silent -- the
-- cmdline has to stay open for typing.
vim.keymap.set('n', '<leader><leader>', ':Man ', { desc = 'Look up a man page' })
