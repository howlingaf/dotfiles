# sticky-peek.nvim

Snapshot the current buffer into a read-only horizontal split pinned at the top of the editor. Edit anywhere else with the snapshot visible as a frozen reference; scroll the pin independently to keep whatever section you want in view.

## Install

### lazy.nvim

```lua
{
  "you/sticky-peek.nvim",
  event = "VeryLazy",
  config = function()
    require("sticky-peek").setup({})
  end,
}
```

The plugin auto-initializes with defaults via `plugin/sticky-peek.lua`, so the user commands and default keymaps work even without an explicit `setup()` call.

## Default config

```lua
require("sticky-peek").setup({
  height_pct = 0.25,    -- fraction of editor height the pin occupies
  keymaps = {
    pin = "<leader>sp",     -- normal mode
    close = "<leader>sx",   -- normal mode
    close_in_pin = "q",     -- inside the pin window
  },
  highlights = {
    -- override any of:
    --   StickyPeekNormal | StickyPeekQuoteBar | StickyPeekLineNr
  },
})
```

Pass `keymaps = false` to skip the default mappings entirely and bind your own to the user commands.

## Usage

1. Open any file, position your cursor anywhere.
2. `<leader>sp` — snapshots the buffer into a top split. Focus stays in the source.
3. Navigate / edit freely in the source.
4. `<C-w>k` to enter the pin, scroll to the section you want as your reference.
5. `<C-w>j` back into the source. The pin stays scrolled where you left it.
6. `<leader>sx` (or `q` from inside the pin) to close.

Re-pinning replaces the previous snapshot.

## User commands

- `:StickyPeekPin` — snapshot the current buffer.
- `:StickyPeekClose` — close the active pin.
- `:StickyPeekToggle` — pin if not active, close if active.

## Visual design

The pin is visually distinct from your main editing area via three layered cues:

- **Tinted background** (`StickyPeekNormal`, default `#1f1d2e`) — pops against a transparent or terminal-default Normal.
- **Left-edge quote bar** rendered through `statuscolumn` — a `▎` glyph in muted purple down column 1, the universal blockquote affordance.
- **Dimmed line numbers** (`StickyPeekLineNr`) — reads as auxiliary content, not primary edit surface.

Override colors to match your theme:

```lua
require("sticky-peek").setup({
  highlights = {
    StickyPeekNormal   = { bg = "#1e1e2e" },
    StickyPeekQuoteBar = { fg = "#cba6f7", bg = "#1e1e2e" },
    StickyPeekLineNr   = { fg = "#7f849c", bg = "#1e1e2e" },
  },
})
```

The plugin re-applies its highlights on `ColorScheme` so theme switches don't blow them away.

## Known limitations

- **Snapshot semantics.** A pin is a frozen copy of the source buffer at pin time. Subsequent edits to the source are *not* reflected. Re-pin to refresh.
- **Single pin.** Only one active pin at a time; pinning again replaces the previous.
- **Single tab page.** The pin lives in the tabpage where it was created; switching tabs does not carry it.
- **No persistence.** Pins are not saved across Neovim sessions.
- **`winfixbuf` requires Neovim 0.10+.** On 0.9 the plugin still works, but the pin window's buffer can theoretically be swapped by `:edit`/`:bnext`. Recommended target: 0.10+.
