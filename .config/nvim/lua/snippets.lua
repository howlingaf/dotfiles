local ls = require 'luasnip'
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

-- Snippet objects can't be shared between filetypes, so build a fresh one per ft.
for _, ft in ipairs { 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' } do
  ls.add_snippets(ft, {
    s('clg', {
      t 'console.log(',
      i(1, ''),
      t ')',
    }),
  })
end
