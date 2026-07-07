require('csvview').setup {
  parser = {
    async_chunksize = 50,
    delimiter = {
      default = ',',
      ft = {
        tsv = '\t',
      },
    },
    quote_char = '"',
    comments = {},
  },
  keymaps = {
    textobject_field_inner = { 'if', mode = { 'o', 'x' } },
    textobject_field_outer = { 'af', mode = { 'o', 'x' } },
    jump_next_field_end = { '<Tab>', mode = { 'n', 'v' } },
    jump_prev_field_end = { '<S-Tab>', mode = { 'n', 'v' } },
    jump_next_row = { '<Enter>', mode = { 'n', 'v' } },
    jump_prev_row = { '<S-Enter>', mode = { 'n', 'v' } },
  },
}
