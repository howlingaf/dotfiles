require 'custom.settings'

local have_make = vim.fn.executable 'make' == 1

-- vim.pack has no `build` field; specs below carry their build step in
-- `data.build` instead, dispatched from this autocmd (registered before
-- vim.pack.add() so it catches first-time installs).
vim.api.nvim_create_autocmd('PackChanged', {
  group = vim.api.nvim_create_augroup('pack-build-hooks', { clear = true }),
  callback = function(ev)
    local build = ev.data.spec.data and ev.data.spec.data.build
    if build then
      build(ev)
    end
  end,
})

-- Runs `cmd` in the plugin dir after it changes on disk. Blocks on install
-- (the built artifact is required later this same startup) but not on update
-- (the running session keeps its loaded copy; the build only matters next
-- session).
local function build_with(cmd)
  return function(ev)
    if ev.data.kind == 'delete' then
      return
    end
    local job = vim.system(cmd, { cwd = ev.data.path })
    if ev.data.kind == 'install' then
      job:wait()
    end
  end
end

-- Read by matchup's plugin/ code (which sources after init.lua finishes).
vim.g.matchup_matchparen_offscreen = {}

-- Every installed plugin is pinned to an exact commit. To update one: change
-- its `version` to a branch/tag, restart, run vim.pack.update(), then
-- optionally re-pin (see :h vim.pack-examples).
local specs = {
  { src = 'https://github.com/nvim-lua/plenary.nvim', version = '74b06c6c75e4eeb3108ec01852001636d85a932b' },
  { src = 'https://github.com/nvim-telescope/telescope.nvim', version = '7d324792b7943e4aa16ad007212e6acc6f9fe335' },
  { src = 'https://github.com/neovim/nvim-lspconfig', version = '229b79051b380377664edc4cbd534930154921a1' },
  { src = 'https://github.com/williamboman/mason.nvim', version = '16ba83bfc8a25f52bb545134f5bee082b195c460' },
  { src = 'https://github.com/williamboman/mason-lspconfig.nvim', version = '0a695750d747db1e7e70bcf0267ef8951c95fc83' },
  { src = 'https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim', version = '443f1ef8b5e6bf47045cb2217b6f748a223cf7dc' },
  { src = 'https://github.com/j-hui/fidget.nvim', version = '82404b196e73a00b1727a91903beef5ddc319d22' },
  { src = 'https://github.com/andymass/vim-matchup', version = 'a2d618496223386844acb5a6763cfc3cc1357af1' },
  { src = 'https://github.com/folke/lazydev.nvim', version = 'ff2cbcba459b637ec3fd165a2be59b7bbaeedf0d' },
  { src = 'https://github.com/Bilal2453/luvit-meta', version = 'cc9b2d412d2fbd30b94a70cfc214c2a3be27a0a2' },
  { src = 'https://github.com/stevearc/conform.nvim', version = '619363c30309d29ffa631e67c8183f2a72caa373' },
  { src = 'https://github.com/stevearc/aerial.nvim', version = '28fe6e822ae344544c379d60fcb13c9519a1f08a' },
  { src = 'https://github.com/hrsh7th/nvim-cmp', version = 'a1d504892f2bc56c2e79b65c6faded2fd21f3eca' },
  {
    src = 'https://github.com/L3MON4D3/LuaSnip',
    version = '0abc8f390b278c3b4aabc4c004ac8a088b65cf24',
    data = (vim.fn.has 'win32' == 0 and have_make) and { build = build_with { 'make', 'install_jsregexp' } } or nil,
  },
  { src = 'https://github.com/rafamadriz/friendly-snippets', version = '6cd7280adead7f586db6fccbd15d2cac7e2188b9' },
  { src = 'https://github.com/saadparwaiz1/cmp_luasnip', version = '98d9cb5c2c38532bd9bdb481067b20fea8f32e90' },
  { src = 'https://github.com/hrsh7th/cmp-nvim-lsp', version = 'cbc7b02bb99fae35cb42f514762b89b5126651ef' },
  { src = 'https://github.com/hrsh7th/cmp-path', version = 'c642487086dbd9a93160e1679a1327be111cbc25' },
  { src = 'https://github.com/folke/todo-comments.nvim', version = '31e3c38ce9b29781e4422fc0322eb0a21f4e8668' },
  { src = 'https://github.com/echasnovski/mini.nvim', version = 'b2ac6522f7a54b475d9fad711b938eefc6d3d0a6' },
  {
    src = 'https://github.com/nvim-treesitter/nvim-treesitter',
    version = '4916d6592ede8c07973490d9322f187e07dfefac',
    data = {
      build = function(ev)
        -- Parsers live in stdpath('data')/site, independent of the plugin
        -- manager; the require('nvim-treesitter').install{} call below handles
        -- them on install. Only refresh when the plugin itself is updated.
        if ev.data.kind ~= 'update' then
          return
        end
        if not ev.data.active then
          vim.cmd.packadd 'nvim-treesitter'
        end
        vim.cmd 'TSUpdate'
      end,
    },
  },
  { src = 'https://github.com/lukas-reineke/indent-blankline.nvim', version = 'd28a3f70721c79e3c5f6693057ae929f3d9c0a03' },
  { src = 'https://github.com/mfussenegger/nvim-lint', version = '99cbc3ca8a76845fca50e496be7212bebf907dd3' },
  { src = 'https://github.com/windwp/nvim-autopairs', version = '7b9923abad60b903ece7c52940e1321d39eccc79' },
  { src = 'https://github.com/lewis6991/gitsigns.nvim', version = '25050e4ed39e628282831d4cbecb1850454ce915' },
  { src = 'https://github.com/windwp/nvim-ts-autotag', version = '88c1453db4ba7dd24131086fe51fdf74e587d275' },
  { src = 'https://github.com/ThePrimeagen/harpoon', version = '87b1a3506211538f460786c23f98ec63ad9af4e5' },
  { src = 'https://github.com/hat0uma/csvview.nvim', version = '5c22774c3ecc7f8883af5d143b366e45b1f0875d' },
}
if have_make then
  table.insert(specs, {
    src = 'https://github.com/nvim-telescope/telescope-fzf-native.nvim',
    version = 'b25b749b9db64d375d782094e2b9dce53ad53a40',
    data = { build = build_with { 'make' } },
  })
end
if vim.g.have_nerd_font then
  -- Unpinned: gated off, so it has never been installed and there is no
  -- commit to pin. Pin when first enabled.
  table.insert(specs, { src = 'https://github.com/nvim-tree/nvim-web-devicons' })
end
-- confirm=false: install missing plugins without prompting.
vim.pack.add(specs, { confirm = false })

-- Local plugin: on the runtimepath only, not managed by vim.pack. Its
-- plugin/sticky-peek.lua runs setup() with defaults when plugin files source
-- after init.lua.
vim.opt.rtp:append(vim.fn.stdpath 'config' .. '/sticky-peek.nvim')

-- Telescope
-- List files with rg, then keep only those grep classifies as text (-I drops
-- files with binary content). Catches extensionless executables, .o files,
-- images, etc. by content rather than extension, so text like .sh survives.
-- Side effect: zero-byte files are dropped too (grep sees no matching line).
local function text_files_cmd(rg_flags)
  return { 'sh', '-c', 'rg --files ' .. rg_flags .. [[ | xargs -r -d '\n' grep -Il '' 2>/dev/null]] }
end
require('telescope').setup {
  defaults = {
    preview = { treesitter = false },
    file_ignore_patterns = {
      'node_modules',
      '%.git/',
      'dist/',
      'build/',
      '%.lock',
      '__pycache__/',
      '%.cache/',
    },
  },
  pickers = {
    find_files = {
      find_command = text_files_cmd '',
    },
  },
}
pcall(require('telescope').load_extension, 'fzf')

vim.keymap.set('n', '<leader>sk', '<cmd>Telescope keymaps<cr>', { desc = '[S]earch [K]eymaps' })
vim.keymap.set('n', '<leader>sf', '<cmd>Telescope find_files<cr>', { desc = '[S]earch [F]iles' })
-- Like <leader>sf but includes hidden dotfiles AND git-ignored files
-- (build dirs, etc.) -- a full "find everything" search on demand.
vim.keymap.set('n', '<leader>sF', function()
  -- hidden/no_ignore opts only work with a bare rg/fd find_command, so bake
  -- the flags into the text-filtering command instead.
  require('telescope.builtin').find_files {
    find_command = text_files_cmd '--hidden --no-ignore',
    prompt_title = 'Find Files (all, incl. hidden + ignored)',
  }
end, { desc = '[S]earch [F]iles (all, incl. hidden + ignored)' })
vim.keymap.set('n', '<leader>ss', '<cmd>Telescope builtin<cr>', { desc = '[S]earch [S]elect Telescope' })
vim.keymap.set('n', '<leader>sw', '<cmd>Telescope grep_string<cr>', { desc = '[S]earch current [W]ord' })
vim.keymap.set('n', '<leader>sg', '<cmd>Telescope live_grep<cr>', { desc = '[S]earch by [G]rep' })
vim.keymap.set('n', '<leader>sd', '<cmd>Telescope diagnostics<cr>', { desc = '[S]earch [D]iagnostics' })
vim.keymap.set('n', '<leader>sr', '<cmd>Telescope resume<cr>', { desc = '[S]earch [R]esume' })
vim.keymap.set('n', '<leader>s.', '<cmd>Telescope oldfiles<cr>', { desc = '[S]earch Recent Files ("." for repeat)' })
vim.keymap.set('n', '<leader>/', function()
  require('telescope.builtin').current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
    winblend = 10,
    previewer = false,
  })
end, { desc = '[/] Fuzzily search in current buffer' })
vim.keymap.set('n', '<leader>s/', function()
  require('telescope.builtin').live_grep {
    grep_open_files = true,
    prompt_title = 'Live Grep in Open Files',
  }
end, { desc = '[S]earch [/] in Open Files' })
vim.keymap.set('n', '<leader>sn', function()
  require('telescope.builtin').find_files { cwd = vim.fn.stdpath 'config' }
end, { desc = '[S]earch [N]eovim files' })
vim.keymap.set('n', '<leader>e', '<cmd>Telescope find_files<cr>', { desc = 'Browse files in working directory' })

-- LSP
-- Keymaps & UI on attach (unchanged)
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
  callback = function(event)
    local map = function(keys, func, desc, mode)
      mode = mode or 'n'
      vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
    end

    -- `K` is the standard LSP hover -- a compact tooltip with the matched
    -- overload's signature (concrete types substituted) and doc comment,
    -- like Visual Studio's Quick Info. `<leader>K` peeks the full source
    -- definition inline (handy for browsing your own struct/class bodies).
    map('K', vim.lsp.buf.hover, 'Hover (Quick Info)')
    map('<leader>K', require('custom.peek').peek_definition, 'Peek Definition (source)')

    map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
    map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
    map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
    map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')
    map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
    map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')
    map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
    map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction', { 'n', 'x' })
    map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
      local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
      vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.document_highlight,
      })
      vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.clear_references,
      })
      vim.api.nvim_create_autocmd('LspDetach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
        callback = function(event2)
          vim.lsp.buf.clear_references()
          vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
        end,
      })
    end

    if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
      map('<leader>th', function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
      end, '[T]oggle Inlay [H]ints')
    end
  end,
})

local capabilities = vim.lsp.protocol.make_client_capabilities()
local ok_cmp, cmp_nvim_lsp = pcall(require, 'cmp_nvim_lsp')
if ok_cmp then
  capabilities = vim.tbl_deep_extend('force', capabilities, cmp_nvim_lsp.default_capabilities())
end

-- Capabilities for every server (merged into each per-server config below).
vim.lsp.config('*', { capabilities = capabilities })

-- Per-server config (add more servers here)
local servers = {
  rust_analyzer = {},
  lua_ls = {
    settings = {
      Lua = { completion = { callSnippet = 'Replace' } },
    },
  },
  ts_ls = {
    settings = {
      -- ESLint (@typescript-eslint/no-unused-vars) owns "unused" reporting;
      -- drop ts_ls's duplicate greyed-out hints (6133 unused local, 6196
      -- unused declaration, 6192 all imports unused, 6138 unused property).
      diagnostics = { ignoredCodes = { 6133, 6196, 6192, 6138 } },
      typescript = {
        inlayHints = {
          includeInlayParameterNameHints = 'all',
          includeInlayFunctionParameterTypeHints = true,
          includeInlayVariableTypeHints = true,
          includeInlayPropertyDeclarationTypeHints = true,
        },
      },
      javascript = {
        inlayHints = {
          includeInlayParameterNameHints = 'all',
          includeInlayFunctionParameterTypeHints = true,
        },
      },
    },
  },
  pyright = {
    settings = {
      python = {
        analysis = {
          typeCheckingMode = 'standard', -- 'basic' -> 'standard' for richer type diagnostics
          autoSearchPaths = true,
          useLibraryCodeForTypes = true,
          -- Ruff owns "unused" reporting; silence pyright's duplicate
          -- greyed-out "X is not accessed" hints.
          diagnosticSeverityOverrides = {
            reportUnusedImport = 'none',
            reportUnusedVariable = 'none',
            reportUnusedClass = 'none',
            reportUnusedFunction = 'none',
          },
        },
      },
      -- Defer linting (unused imports, style, etc.) to the ruff LSP, which
      -- does it live and faster. pyright stays the type checker.
      pyright = {
        disableOrganizeImports = true,
      },
    },
  },
  -- ruff as a live LSP: inline lint squiggles + quick-fixes as you type,
  -- the Python analog to clangd's --clang-tidy. Replaces the on-save pylint
  -- pass (removed from nvim-lint). Hover is left to pyright to avoid dupes.
  ruff = {
    on_attach = function(client)
      client.server_capabilities.hoverProvider = false
    end,
  },
  -- ESLint as a live LSP: inline lint squiggles + quick-fixes as you type,
  -- the JS/TS analog to the ruff LSP. Only activates in projects that have
  -- an ESLint config (.eslintrc / eslint.config.js); silent otherwise.
  -- Replaces the on-save eslint_d pass (removed from nvim-lint).
  eslint = {},
}

-- Optional servers (automatically configured if manually installed via :MasonInstall)
local optional_servers = {
  gopls = {
    settings = {
      gopls = {
        analyses = {
          unusedparams = true,
        },
        staticcheck = true,
        gofumpt = true,
      },
    },
  },
  clangd = {
    cmd = {
      'clangd',
      '--background-index',
      '--header-insertion=iwyu',
      '--completion-style=detailed',
      '--function-arg-placeholders=1',
    },
  },
  jdtls = {
    settings = {
      java = {
        signatureHelp = { enabled = true },
        contentProvider = { preferred = 'fernflower' },
        completion = {
          favoriteStaticMembers = {
            'org.junit.Assert.*',
            'org.junit.jupiter.api.Assertions.*',
            'org.mockito.Mockito.*',
          },
        },
      },
    },
  },
}

-- Register per-server config via the v2 API (mason-lspconfig dropped `handlers`).
-- `vim.lsp.config(name, opts)` stores the config; `automatic_enable` (default true)
-- in mason-lspconfig then calls `vim.lsp.enable(name)` for each installed server.
for name, opts in pairs(vim.tbl_extend('force', {}, servers, optional_servers)) do
  vim.lsp.config(name, opts)
end

require('mason').setup()

local ensure_installed = vim.tbl_keys(servers)
vim.list_extend(ensure_installed, {
  'stylua',
  'prettier',
  'prettierd',
  'ruff',
  'isort',
})
require('mason-tool-installer').setup { ensure_installed = ensure_installed }

-- mason-tool-installer installs everything above; mason-lspconfig just
-- needs to run so `automatic_enable` calls vim.lsp.enable() per server.
require('mason-lspconfig').setup {}

require('fidget').setup {}

require('lazydev').setup {
  library = {
    { path = 'luvit-meta/library', words = { 'vim%.uv' } },
  },
}

-- Completion (nvim-cmp + LuaSnip)
local cmp = require 'cmp'
local luasnip = require 'luasnip'
luasnip.config.setup {}
require('luasnip.loaders.from_vscode').lazy_load()

-- Load custom snippets
require 'snippets'

cmp.setup {
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  completion = { completeopt = 'menu,menuone,noinsert' },

  mapping = cmp.mapping.preset.insert {
    ['<C-n>'] = cmp.mapping.select_next_item(),
    ['<C-p>'] = cmp.mapping.select_prev_item(),
    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-y>'] = cmp.mapping.confirm { select = true },

    ['<Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_locally_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { 'i', 's' }),
    ['<S-Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.locally_jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { 'i', 's' }),
  },
  sources = {
    {
      name = 'lazydev',
      group_index = 0,
    },
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
    { name = 'path' },
  },
}

-- autopairs, after cmp so its confirm_done event exists to hook.
require('nvim-autopairs').setup {}
cmp.event:on('confirm_done', require('nvim-autopairs.completion.cmp').on_confirm_done())

-- Formatting (conform)
-- prettierd with prettier fallback, shared by all JS/TS filetypes.
local prettier = { 'prettierd', 'prettier', stop_after_first = true }
require('conform').setup {
  notify_on_error = false,
  format_on_save = {
    timeout_ms = 500,
    lsp_format = 'fallback',
  },
  formatters_by_ft = {
    lua = { 'stylua' },
    -- 'ruff' alone is a deprecated alias for ruff_fix (lint autofixes only);
    -- ruff_format is the actual formatter.
    python = { 'isort', 'ruff_format' },
    javascript = prettier,
    typescript = prettier,
    javascriptreact = prettier,
    typescriptreact = prettier,
    go = { 'gofumpt', 'goimports' },
    cpp = { 'clang-format' },
    c = { 'clang-format' },
    java = { 'google-java-format' },
  },
}
vim.keymap.set('', '<leader>f', function()
  require('conform').format { async = true, lsp_format = 'fallback' }
end, { desc = '[F]ormat buffer' })

-- Aerial (symbol outline)
require('aerial').setup {
  backends = { 'lsp', 'treesitter' },
  layout = {
    default_direction = 'right',
    -- Fixed panel width. Bump this one number to taste (columns, not px).
    width = 28,
    min_width = 28,
    max_width = 28,
  },
  show_guides = true,
  filter_kind = false,
}
vim.keymap.set('n', '<leader>o', '<cmd>AerialToggle!<CR>', { desc = 'Toggle class outline' })

require('todo-comments').setup { signs = false }

-- mini.nvim
require('mini.ai').setup { n_lines = 100 }
require('mini.surround').setup()

local statusline = require 'mini.statusline'

-- Custom sections, called from content.active below instead of
-- monkeypatching mini's own section_* functions.
-- MAX_LEN follows zshrc's GIT_BRANCH_MAXLEN so both truncate alike.
local MAX_LEN = tonumber(vim.env.GIT_BRANCH_MAXLEN) or 24
local function trunc_right(s)
  if vim.fn.strchars(s) <= MAX_LEN then
    return s
  end
  return vim.fn.strcharpart(s, 0, MAX_LEN) .. '…'
end
local function section_git(args)
  if statusline.is_truncated(args.trunc_width) then
    return ''
  end
  local head = vim.b.minigit_summary_string or vim.b.gitsigns_head
  if head == nil or head == '' then
    return ''
  end
  return 'Git ' .. trunc_right(head)
end
local function section_filename()
  if vim.bo.buftype == 'terminal' then
    return '%t'
  end
  return '%t%m%r'
end

statusline.setup {
  use_icons = vim.g.have_nerd_font,
  content = {
    active = function()
      local mode, mode_hl = statusline.section_mode { trunc_width = 120 }
      local git = section_git { trunc_width = 75 }
      local diff = statusline.section_diff { trunc_width = 75 }
      local diag = statusline.section_diagnostics { trunc_width = 75 }
      local lsp = statusline.section_lsp { trunc_width = 75 }
      local filename = section_filename()
      local fileinfo = statusline.section_fileinfo { trunc_width = 120 }
      local location = statusline.section_location { trunc_width = 75 }
      local search = statusline.section_searchcount { trunc_width = 75 }
      return statusline.combine_groups {
        { hl = mode_hl, strings = { mode } },
        { hl = 'MiniStatuslineFilename', strings = { filename } },
        '%<',
        { hl = 'MiniStatuslineDevinfo', strings = { git, diff, diag, lsp } },
        '%=',
        { hl = 'MiniStatuslineFileinfo', strings = { fileinfo } },
        { hl = mode_hl, strings = { search, location } },
      }
    end,
  },
}

-- Treesitter (main branch API)
require('nvim-treesitter').install {
  'bash',
  'c',
  'cpp',
  'diff',
  'html',
  'lua',
  'luadoc',
  'query',
  'vim',
  'vimdoc',
  'python',
  'javascript',
  'typescript',
  'tsx',
  'java',
  'go',
}
vim.api.nvim_create_autocmd('FileType', {
  callback = function(ev)
    -- Only start for filetypes with an installed parser, so real
    -- highlighter errors aren't swallowed by a blanket pcall.
    local lang = vim.treesitter.language.get_lang(ev.match)
    if lang and vim.treesitter.language.add(lang) then
      vim.treesitter.start(ev.buf, lang)
    end
  end,
})

require('ibl').setup {}
require 'kickstart.plugins.lint'
require 'kickstart.plugins.gitsigns'

require('nvim-ts-autotag').setup {}
require 'custom.plugins.harpoon'
require 'custom.plugins.csv'
