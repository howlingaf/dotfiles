require 'custom.settings'

local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then
    error('Error cloning lazy.nvim:\n' .. out)
  end
end ---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)

-- prettierd with prettier fallback, shared by all JS/TS filetypes in conform.
local prettier = { 'prettierd', 'prettier', stop_after_first = true }

require('lazy').setup {
  { 'tpope/vim-sleuth', event = 'BufReadPre' },

  {
    'nvim-telescope/telescope.nvim',
    cmd = 'Telescope',
    dependencies = {
      'nvim-lua/plenary.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    keys = {
      { '<leader>sk', '<cmd>Telescope keymaps<cr>', desc = '[S]earch [K]eymaps' },
      { '<leader>sf', '<cmd>Telescope find_files<cr>', desc = '[S]earch [F]iles' },
      -- Like <leader>sf but includes hidden dotfiles AND git-ignored files
      -- (build dirs, etc.) -- a full "find everything" search on demand.
      { '<leader>sF', '<cmd>Telescope find_files hidden=true no_ignore=true<cr>', desc = '[S]earch [F]iles (all, incl. hidden + ignored)' },
      { '<leader>ss', '<cmd>Telescope builtin<cr>', desc = '[S]earch [S]elect Telescope' },
      { '<leader>sw', '<cmd>Telescope grep_string<cr>', desc = '[S]earch current [W]ord' },
      { '<leader>sg', '<cmd>Telescope live_grep<cr>', desc = '[S]earch by [G]rep' },
      { '<leader>sd', '<cmd>Telescope diagnostics<cr>', desc = '[S]earch [D]iagnostics' },
      { '<leader>sr', '<cmd>Telescope resume<cr>', desc = '[S]earch [R]esume' },
      { '<leader>s.', '<cmd>Telescope oldfiles<cr>', desc = '[S]earch Recent Files ("." for repeat)' },
      {
        '<leader>/',
        function()
          require('telescope.builtin').current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
            winblend = 10,
            previewer = false,
          })
        end,
        desc = '[/] Fuzzily search in current buffer',
      },
      {
        '<leader>s/',
        function()
          require('telescope.builtin').live_grep {
            grep_open_files = true,
            prompt_title = 'Live Grep in Open Files',
          }
        end,
        desc = '[S]earch [/] in Open Files',
      },
      {
        '<leader>sn',
        function()
          require('telescope.builtin').find_files { cwd = vim.fn.stdpath 'config' }
        end,
        desc = '[S]earch [N]eovim files',
      },
      { '<leader>e', '<cmd>Telescope find_files<cr>', desc = 'Browse files in working directory' },
    },
    config = function()
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
      }
      pcall(require('telescope').load_extension, 'fzf')
    end,
  },
  {
    'neovim/nvim-lspconfig',
    -- Defer the whole LSP stack (mason, lspconfig, cmp-nvim-lsp) until a real
    -- file is opened, instead of loading on every launch. LSP still attaches
    -- normally -- BufReadPre fires before the buffer is read, so clangd/pyright
    -- etc. start as soon as you open code, just not when nvim opens to a dashboard.
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = {
      { 'williamboman/mason.nvim', config = true }, -- must load before dependents
      'williamboman/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      { 'j-hui/fidget.nvim', opts = {} },
    },
    config = function()
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
            '--clang-tidy',
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
    end,
  },
  {
    'andymass/vim-matchup',
    event = 'BufReadPost',
    config = function()
      vim.g.matchup_matchparen_offscreen = {}
    end,
  },
  {
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        { path = 'luvit-meta/library', words = { 'vim%.uv' } },
      },
    },
  },
  { 'Bilal2453/luvit-meta', lazy = true },
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function()
          require('conform').format { async = true, lsp_format = 'fallback' }
        end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    opts = {
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
    },
  },

  {
    'stevearc/aerial.nvim',
    cmd = 'AerialToggle',
    keys = {
      { '<leader>o', '<cmd>AerialToggle!<CR>', desc = 'Toggle class outline' },
    },
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
    opts = {
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
    },
  },
  {
    'hrsh7th/nvim-cmp',
    event = 'InsertEnter',
    dependencies = {
      {
        'L3MON4D3/LuaSnip',
        build = (function()
          if vim.fn.has 'win32' == 1 or vim.fn.executable 'make' == 0 then
            return
          end
          return 'make install_jsregexp'
        end)(),
        dependencies = {
          {
            'rafamadriz/friendly-snippets',
            config = function()
              require('luasnip.loaders.from_vscode').lazy_load()
            end,
          },
        },
      },
      'saadparwaiz1/cmp_luasnip',
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-path',
    },
    config = function()
      local cmp = require 'cmp'
      local luasnip = require 'luasnip'
      luasnip.config.setup {}

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
    end,
  },

  { 'folke/todo-comments.nvim', event = 'BufReadPost', dependencies = { 'nvim-lua/plenary.nvim' }, opts = { signs = false } },

  {
    'echasnovski/mini.nvim',
    config = function()
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
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    build = ':TSUpdate',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
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
    end,
  },

  require 'kickstart.plugins.indent_line',
  require 'kickstart.plugins.lint',
  require 'kickstart.plugins.autopairs',
  require 'kickstart.plugins.gitsigns',

  { import = 'custom.plugins' },
}
