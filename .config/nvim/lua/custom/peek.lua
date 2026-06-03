-- Inline definition peek for `K`.
--
-- The built-in `K` (hover) collapses struct/class/enum bodies to `{}`, so it's
-- useless for "what's actually in this type". This instead asks the server for
-- the definition location(s), and:
--
--   * if a location is a real DEFINITION WITH A BODY (struct/class/union/enum
--     with members, or a function with a body), it shows that source inline --
--     expanded with treesitter so you get the whole declaration, not one line.
--   * otherwise (a library function that only has a declaration, a `using`
--     re-export like `using ::memcpy`, a plain variable, an expression) it
--     falls back to normal hover, which gives clangd's clean signature/type.
--
-- This is why `K memcpy` now shows the signature instead of `using ::memcpy`:
-- clangd returns two definition locations for it (the <cstring> using-decl and
-- the <string.h> declaration); neither has a body, so we use hover.

local M = {}

-- Strip common leading indentation so a nested definition isn't pushed right.
local function dedent(lines)
  local min_indent = math.huge
  for _, l in ipairs(lines) do
    if l:match '%S' then
      min_indent = math.min(min_indent, #(l:match '^%s*'))
    end
  end
  if min_indent == math.huge or min_indent == 0 then
    return lines
  end
  local out = {}
  for i, l in ipairs(lines) do
    out[i] = l:sub(min_indent + 1)
  end
  return out
end

-- Walk up from (row,col) to the nearest treesitter node that is a definition
-- WITH A BODY. Returns the node, or nil if there's nothing worth showing inline
-- (declaration-only, using-decl, variable, etc.). Returning nil is what makes
-- the caller fall back to hover.
local function find_body_node(buf, row, col)
  local ok, parser = pcall(vim.treesitter.get_parser, buf)
  if not ok or not parser then
    return nil
  end
  parser:parse()
  local node = vim.treesitter.get_node { bufnr = buf, pos = { row, col } }
  -- Track whether we climb out through a function body. If the definition sits
  -- INSIDE a function body (a local variable, a statement), the nearest
  -- function_definition is the surrounding function -- not the symbol itself --
  -- so we must not show that whole function. In that case bail to hover.
  local passed_function_body = false
  while node do
    local t = node:type()
    if t == 'compound_statement' then
      passed_function_body = true
    end
    local hit = false
    if t == 'function_definition' then
      hit = not passed_function_body
    elseif t == 'type_definition' then
      hit = true
    elseif t == 'struct_specifier' or t == 'class_specifier' or t == 'union_specifier' then
      for child in node:iter_children() do
        if child:type() == 'field_declaration_list' then
          hit = true
          break
        end
      end
    elseif t == 'enum_specifier' then
      for child in node:iter_children() do
        if child:type() == 'enumerator_list' then
          hit = true
          break
        end
      end
    end
    if hit then
      -- Prefer the enclosing template<...> so type/function templates show
      -- their parameter list too.
      local parent = node:parent()
      if parent and parent:type() == 'template_declaration' then
        return parent
      end
      return node
    end
    node = node:parent()
  end
  return nil
end

-- Load a target buffer without ever prompting on an existing swapfile (E325).
local function load_buf_silent(target_buf)
  if vim.api.nvim_buf_is_loaded(target_buf) then
    return
  end
  local save_shm = vim.o.shortmess
  vim.o.shortmess = save_shm .. 'A'
  pcall(vim.fn.bufload, target_buf)
  vim.o.shortmess = save_shm
end

-- Try to render one definition location's body inline. Returns true on success.
local function show_location_body(loc)
  local uri = loc.uri or loc.targetUri
  local range = loc.targetSelectionRange or loc.targetRange or loc.range
  if not uri or not range then
    return false
  end

  local target_buf = vim.uri_to_bufnr(uri)
  load_buf_silent(target_buf)

  local node = find_body_node(target_buf, range.start.line, range.start.character)
  if not node then
    return false
  end

  local sline, _, eline, ecol = node:range()
  if ecol == 0 and eline > sline then
    eline = eline - 1 -- container ended at col 0 of the next line
  end
  local lines = vim.api.nvim_buf_get_lines(target_buf, sline, eline + 1, false)
  if #lines == 0 then
    return false
  end
  lines = dedent(lines)

  vim.lsp.util.open_floating_preview(lines, vim.bo[target_buf].filetype, {
    border = 'single',
    max_width = 100,
    max_height = 30,
    focusable = true,
    focus = true,
    close_events = { 'CursorMoved', 'CursorMovedI', 'InsertEnter', 'BufLeave' },
  })
  return true
end

function M.peek_definition()
  local bufnr = 0
  local clients = vim.lsp.get_clients { bufnr = bufnr, method = 'textDocument/definition' }
  if #clients == 0 then
    vim.lsp.buf.hover()
    return
  end

  local client = clients[1]
  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)

  client:request('textDocument/definition', params, function(err, result)
    if err or not result or (type(result) == 'table' and vim.tbl_isempty(result)) then
      vim.lsp.buf.hover()
      return
    end

    -- result is Location | Location[] | LocationLink[]. Try each in order; the
    -- first one that is a real body (not a using-decl / forward declaration)
    -- wins. If none qualifies, hover gives the clean signature.
    local locations = vim.islist(result) and result or { result }
    for _, loc in ipairs(locations) do
      if show_location_body(loc) then
        return
      end
    end

    vim.lsp.buf.hover()
  end, bufnr)
end

return M
