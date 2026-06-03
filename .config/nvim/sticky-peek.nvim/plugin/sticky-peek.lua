if vim.g.loaded_sticky_peek then return end
vim.g.loaded_sticky_peek = 1

-- Default-config setup so :StickyPeek* commands and the leader keymaps work
-- without the user calling setup() explicitly. A later setup({...}) from user
-- config will re-merge and re-bind keymaps idempotently.
require("sticky-peek").setup()
