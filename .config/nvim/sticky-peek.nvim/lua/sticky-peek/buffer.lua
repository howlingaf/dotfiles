local M = {}

---Build the read-only scratch buffer that backs a pin.
---@param lines string[] full snapshot of source lines
---@param source_ft string
---@param source_name string absolute path of the source buffer (may be empty)
---@return integer buf
function M.create(lines, source_ft, source_name)
  local buf = vim.api.nvim_create_buf(false, true)

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = false

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  if source_ft and source_ft ~= "" then
    vim.bo[buf].filetype = source_ft
  end

  local short = vim.fn.fnamemodify(source_name, ":t")
  if short == "" then short = "[No Name]" end
  -- Wrapped: pinning the same file twice would otherwise raise E95.
  pcall(vim.api.nvim_buf_set_name, buf, ("[READ-ONLY] %s"):format(short))

  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true

  return buf
end

return M
