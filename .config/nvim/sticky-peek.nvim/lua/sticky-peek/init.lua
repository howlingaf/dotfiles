local config = require("sticky-peek.config")
local state = require("sticky-peek.state")
local highlights = require("sticky-peek.highlights")
local buffer = require("sticky-peek.buffer")
local window = require("sticky-peek.window")
local commands = require("sticky-peek.commands")

local M = {}

local AUGROUP_GLOBAL = "StickyPeekGlobal"
local AUGROUP_WIN = "StickyPeekWin"

---Snapshot the current buffer into a read-only top split. Focus stays in the
---source window so editing/navigation is uninterrupted.
function M.pin()
  local current_win = vim.api.nvim_get_current_win()
  if state.is_active() and current_win == state.win then
    vim.notify("[sticky-peek] cannot pin from inside the pin window", vim.log.levels.WARN)
    return
  end

  local source_buf = vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(source_buf) then
    vim.notify("[sticky-peek] source buffer is not valid", vim.log.levels.WARN)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)
  if #lines == 0 or (#lines == 1 and lines[1] == "") then
    vim.notify("[sticky-peek] buffer is empty", vim.log.levels.WARN)
    return
  end

  local source_ft = vim.bo[source_buf].filetype
  local source_name = vim.api.nvim_buf_get_name(source_buf)

  M.close()

  local buf = buffer.create(lines, source_ft, source_name)
  local win = window.open(buf)

  state.buf = buf
  state.win = win

  local km = config.options.keymaps
  if km and km.close_in_pin and km.close_in_pin ~= "" then
    vim.keymap.set("n", km.close_in_pin, function() M.close() end, {
      buffer = buf,
      nowait = true,
      silent = true,
      desc = "sticky-peek: close pin",
    })
  end

  local group = vim.api.nvim_create_augroup(AUGROUP_WIN, { clear = true })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = tostring(win),
    once = true,
    callback = function() state.reset() end,
  })
end

function M.close()
  pcall(vim.api.nvim_create_augroup, AUGROUP_WIN, { clear = true })

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    pcall(vim.api.nvim_win_close, state.win, true)
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
  end
  state.reset()
end

function M.toggle()
  if state.is_active() then
    M.close()
  else
    M.pin()
  end
end

---@return boolean
function M.is_active()
  return state.is_active()
end

---@param user_opts table|nil
function M.setup(user_opts)
  config.merge(user_opts)
  highlights.setup(config.options.highlights)
  commands.setup(M)

  local group = vim.api.nvim_create_augroup(AUGROUP_GLOBAL, { clear = true })

  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      if state.is_active() then
        window.resize(state.win)
      end
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function() M.close() end,
  })
end

return M
