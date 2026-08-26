-- One definition of "project root", shared by the tags workflow and :grep, so
-- they agree on the same directory: the nearest ancestor holding a tags file,
-- .git, or Makefile; the cwd otherwise.
local M = {}

M.markers = { 'tags', '.git', 'Makefile' }

function M.root(buf)
  return vim.fs.root(buf or 0, M.markers) or vim.fn.getcwd()
end

return M
