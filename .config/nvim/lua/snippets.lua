local ls = require 'luasnip'
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

ls.add_snippets('javascript', {
  s('clg', {
    t 'console.log(',
    i(1, ''),
    t ')',
  }),
})

ls.add_snippets('typescript', {
  s('clg', {
    t 'console.log(',
    i(1, ''),
    t ')',
  }),
})

ls.add_snippets('javascriptreact', {
  s('clg', {
    t 'console.log(',
    i(1, ''),
    t ')',
  }),
})

ls.add_snippets('typescriptreact', {
  s('clg', {
    t 'console.log(',
    i(1, ''),
    t ')',
  }),
})
