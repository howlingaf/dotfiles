return {

  'obsidian-nvim/obsidian.nvim',
  version = '*',
  lazy = true,

  -- Load Obsidian.nvim for all markdown files BEFORE ftplugins run
  ft = 'markdown',

  dependencies = {
    'nvim-lua/plenary.nvim',
  },
  config = function()
    local obsidian = require 'obsidian'
    local curl = require 'plenary.curl'
    local Path = require 'plenary.path'

    -------------------------------------------------------------------------
    -- Static output directory for LeetCode notes
    -------------------------------------------------------------------------
    local PROBLEMS_PATH = vim.fn.expand '~/Vaults/personal/_leetcode'

    -------------------------------------------------------------------------
    -- LeetCode Problem Creator
    -------------------------------------------------------------------------
    local function create_leetcode_problem()
      vim.ui.input({ prompt = 'Enter LeetCode problem number: ' }, function(problem_id)
        if not problem_id or problem_id == '' then
          return
        end

        print 'Fetching problem data...'

        curl.get('https://leetcode-api-pied.vercel.app/problems', {
          callback = function(response)
            vim.schedule(function()
              if response.status ~= 200 then
                print('Error fetching problem data: ' .. response.status)
                return
              end

              local ok, data = pcall(vim.json.decode, response.body)
              if not ok or type(data) ~= 'table' then
                print 'Invalid API response'
                return
              end

              -- Find matching problem
              local problem = nil
              for _, p in ipairs(data) do
                if tostring(p.frontend_id) == tostring(problem_id) then
                  problem = p
                  break
                end
              end

              if not problem then
                print('Problem ' .. problem_id .. ' not found')
                return
              end

              -------------------------------------------------------------------
              -- Ensure directory exists
              -------------------------------------------------------------------
              vim.fn.mkdir(PROBLEMS_PATH, 'p')

              -------------------------------------------------------------------
              -- Build filename
              -------------------------------------------------------------------
              local filename = string.format('%s/%s-%s.md', PROBLEMS_PATH, problem.frontend_id, problem.title_slug)

              -------------------------------------------------------------------
              -- Create file safely
              -------------------------------------------------------------------
              Path:new(filename):write('', 'w')

              -------------------------------------------------------------------
              -- Open & populate
              -------------------------------------------------------------------
              vim.cmd('edit ' .. filename)

              local content = {
                '# ' .. problem.frontend_id .. '. ' .. problem.title,
                '',
                '**Difficulty**: ' .. problem.difficulty,
                '**Date**: ' .. os.date '%Y-%m-%d',
                '',
                '## Problem Statement',
                problem.url,
                '',
                '## Notes',
                '',
              }

              vim.api.nvim_buf_set_lines(0, 0, -1, false, content)

              print('Created problem note: ' .. filename)
            end)
          end,
        })
      end)
    end

    -------------------------------------------------------------------------
    -- Keymaps
    -------------------------------------------------------------------------
    vim.keymap.set('n', '<leader>nl', create_leetcode_problem, {
      desc = 'New LeetCode problem note',
    })

    vim.keymap.set('n', '<leader>nn', ':ObsidianNewFromTemplate<CR>', {
      desc = 'New note from template',
    })

    vim.keymap.set('n', '<leader>na', ':ObsidianTagsActive<CR>', {
      desc = 'Find active notes',
    })

    -------------------------------------------------------------------------
    -- Obsidian.nvim Setup
    -------------------------------------------------------------------------
    obsidian.setup {
      workspaces = {
        {
          name = 'personal',
          path = vim.fn.expand '~/Vaults/personal/',
        },
      },

      templates = {
        folder = vim.fn.expand '~/Vaults/personal/_templates',
        date_format = '%Y-%m-%d',
        time_format = '%H:%M',
        substitutions = {
          yesterday = function()
            return os.date('%Y-%m-%d', os.time() - 86400)
          end,
          tomorrow = function()
            return os.date('%Y-%m-%d', os.time() + 86400)
          end,
        },
      },

      ui = { enable = true },

      note_frontmatter_func = function(note)
        local now = os.date '%Y-%m-%d %H:%M'
        local title = note.title

        if note.aliases and #note.aliases > 0 then
          title = note.aliases[1]
        elseif note.title then
          note:add_alias(note.title)
        end

        local out = {
          title = title,
          id = note.id,
          aliases = note.aliases,
          tags = note.tags,
          created = now,
          modified = now,
        }

        if note.metadata and note.metadata.created then
          out.created = note.metadata.created
        end

        return out
      end,

      callbacks = {
        pre_write_note = function(_, note)
          if note.metadata then
            note.metadata.modified = os.date '%Y-%m-%d %H:%M'
          end
        end,
      },
    }
  end,
}
