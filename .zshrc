export ZSH="$HOME/.oh-my-zsh"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.local/share/nvim/mason/bin:$PATH"
export EDITOR="nvim"
export VISUAL="nvim"

setopt IGNORE_EOF
setopt PROMPT_SUBST

function _zsh_plugin_install() {
  local name=$1 repo=$2
  local dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/$name"
  [[ -d "$dir" ]] || git clone --depth 1 "$repo" "$dir"
}

_zsh_plugin_install zsh-edit               https://github.com/marlonrichert/zsh-edit.git
_zsh_plugin_install zsh-vim-mode           https://github.com/softmoth/zsh-vim-mode.git

ZSH_THEME=""  # no theme; PROMPT is set by hand below


plugins=(
  zsh-vim-mode
  zsh-edit
)

source $ZSH/oh-my-zsh.sh

# Bash-style prompt, like Arch's default PS1 '[\u@\h \W]\$ ': [user@host dir]$
# with ~ for home. No oh-my-zsh theme (ZSH_THEME is empty above).
PROMPT='[%n@%m %1~]$ '

# No colors. Types are told apart the pre-color Unix way, with ls -F markers:
# dir/  executable*  symlink@  fifo|  socket=  (plain files get nothing).
# Overrides oh-my-zsh's `ls --color=tty`; l/ll/la expand through this alias.
# Completion menus drop their colors too (they already append / to dirs).
alias ls='ls -F --color=never'
zstyle ':completion:*' list-colors ''


bindkey -v
bindkey -M viins 'jk' vi-cmd-mode

alias vi="nvim"
alias nv="cd ~/.config/nvim"
alias vd="visidata"
alias sr=". $HOME/.zshrc && echo '.zshrc sourced'"
alias rc="nvim $HOME/.zshrc ; . $HOME/.zshrc"
alias dg='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
unalias cl cr c 2>/dev/null


cl() {
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || root=$PWD
  cd "$root"
  claude -c "$@"
}

cr() {
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || root=$PWD
  cd "$root"
  claude -r "$@"
}

c() {
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || root=$PWD
  cd "$root"
  claude -c "$@"
}

nvim() {
  # Inside an nvim :terminal (Neovim exports $NVIM, its RPC socket) don't nest
  # an editor: hand the files to the parent, which hides the terminal and
  # opens them in the window it was toggled from. No files -> nothing to do.
  if [[ -n $NVIM ]]; then
    local f opened=0
    for f in "$@"; do
      [[ $f == -* ]] && continue
      # custom/term.lua open_file hides the terminal and
      # opens the file in the window it was toggled from. '' escapes ' in vimscript.
      command nvim --server "$NVIM" --remote-expr "v:lua.require('custom.term').open_file('${${f:A}//\'/\'\'}')" >/dev/null
      opened=1
    done
    (( opened )) || { print -u2 "nvim: already inside nvim (\$NVIM set); nothing opened"; return 1 }
    return
  fi
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || { command nvim "$@"; return }
  local -a args
  local a
  for a in "$@"; do
    case "$a" in
      -*) args+=("$a") ;;
      *)  args+=("${a:A}") ;;
    esac
  done
  cd "$root"
  command nvim "${args[@]}"
}


chpwd(){
    local tmp=$(grep -v "^$OLDPWD$" ~/.cd_history)
    echo "$tmp" > ~/.cd_history;
    echo "$OLDPWD" >> ~/.cd_history;
}

fzf_edit_history(){
  local file root
  # Inside a git repo, only offer files from that repo, shown relative to its
  # root (the absolute prefix is re-added after the pick); otherwise the full
  # list with absolute paths.
  root=$(git rev-parse --show-toplevel 2>/dev/null)
  file=$(tac ~/.edit_history | while IFS= read -r f; do
    [[ -f $f ]] || continue
    if [[ -n $root ]]; then
      [[ $f == $root/* ]] || continue
      print -r -- "${f#$root/}"
    else
      print -r -- "$f"
    fi
  done | fzy)
  [[ -z "$file" ]] && return
  [[ -n $root ]] && file=$root/$file
  # Land in the file's repo root when it's tracked in one; otherwise fall
  # back to the file's own directory. Resolve from the file's dir (git -C),
  # not $PWD -- the file may live in a different repo than where we are now.
  local dir=${file%/*} froot
  froot=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || froot=$dir
  cd "$froot" && nvim "$file"
}

fzf_cd_history(){
  local dir
  dir=$(tac ~/.cd_history | while IFS= read -r d; do [[ -d $d ]] && print -r -- "$d"; done | fzy)
  [[ -n "$dir" ]] && cd "$dir"
}

launch_nvim(){
  nvim
}

fzf_cmd_history(){
  local cmd
  cmd=$(fc -ln 1 | sed 's/^[[:space:]]\+//' | tac | awk '
    !seen[$0]++ && NF>1 {
      for (i=2; i<=NF; i++) if ($i !~ /^-/) { print; next }
    }
  ' | fzy) || return
  [[ -z "$cmd" ]] && return
  BUFFER="$cmd"
  CURSOR=${#BUFFER}
}

dirmenu_select(){
  local dest
  dest=$(dirmenu) && [[ -n "$dest" ]] && cd "$dest"
}


# Bind a key to run a function silently — no command name leaks onto the
# prompt (which is what zsh-edit's `bind` does, since it simulates typing).
# `zle -I` lets the inner command take over the terminal cleanly; the
# `</dev/tty` ensures fzy reads keys even if ZLE has redirected stdin.
silent_bind(){
  local key="$1" cmd="$2" widget="__silent_$2"
  functions[$widget]="zle -I; $cmd </dev/tty; zle reset-prompt"
  zle -N "$widget"
  bindkey "$key" "$widget"
}
silent_bind '^A' fzf_cd_history
silent_bind '^S' fzf_edit_history
silent_bind '^N' launch_nvim
silent_bind '^F' dirmenu_select
silent_bind '^D' fzf_cmd_history

# Pane title = cwd; bubbles up via tmux set-titles to outer terminal title bar.
set-pane-title() {
  print -Pn "\e]2;%d\a"
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd set-pane-title

# Keep the prompt on the vertical middle of the viewport, like scrolloff=999
# keeps the nvim cursor centred: below the middle, scroll the screen up so the
# prompt lands on the centre row; above it (fresh shell, after `clear`), move
# the cursor down to the centre row. Works in any terminal that answers a
# cursor-position query (DSR). Skipped inside nvim terminals (partial-height
# splits; nvim manages the view there).
_center_prompt() {
  emulate -L zsh
  [[ -t 1 && -z $NVIM ]] || return
  local target=$(( LINES / 2 )) reply row
  print -n "\e[6n" >/dev/tty                       # DSR: ask for the cursor row
  IFS= read -rs -t 0.3 -d R reply </dev/tty || return
  reply=${reply#*$'\e['}                             # "row;col"
  row=${reply%%;*}
  [[ $row == <-> ]] || return
  if (( row > target )); then
    print -n "\e[$(( row - target ))S\e[${target};1H" >/dev/tty   # scroll up, then place
  elif (( row < target )); then
    print -n "\e[${target};1H" >/dev/tty                            # just move down
  fi
}
add-zsh-hook precmd _center_prompt

# Ctrl-L is a zle widget (clear-screen), not a command, so precmd never runs
# and the prompt would land at the top. Clear, park the cursor on the centre
# row, and let zle redraw the prompt there.
_clear_screen_centered() {
  if [[ -n $NVIM ]]; then
    zle clear-screen
    return
  fi
  print -n "\e[2J\e[$(( LINES / 2 ));1H" >/dev/tty
  zle reset-prompt
}
zle -N _clear_screen_centered
bindkey '^L' _clear_screen_centered
bindkey -M viins '^L' _clear_screen_centered
bindkey -M vicmd '^L' _clear_screen_centered

[[ -f ~/.zshrc.mac ]] && source ~/.zshrc.mac
[[ -f ~/.zshrc.wsl ]] && source ~/.zshrc.wsl
[[ -f ~/.zshrc.linux ]] && source ~/.zshrc.linux

if [[ "$(uname -s)" == "Darwin" ]]; then
  PROMPT='%F{213}[mac]%f '$PROMPT
elif [[ -n "$SSH_TTY" ]]; then
  PROMPT='%F{blue}[arch]%f '$PROMPT
fi

# tidydoc <check-name>: open a clang-tidy check's doc page in the terminal.
# The URL is derived from the name by swapping the first '-' for '/', e.g.
# modernize-loop-convert -> modernize/loop-convert.html
tidydoc() {
  if [[ -z "$1" ]]; then
    echo "usage: tidydoc <check-name>   e.g. tidydoc modernize-loop-convert" >&2
    return 1
  fi
  w3m "https://clang.llvm.org/extra/clang-tidy/checks/${1/-//}.html"
}




# rt: cd back to the root of the current git repo (worktree-aware).
rt() {
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "not in a git repo" >&2
    return 1
  }
  cd "$root"
}


# BEGIN opam configuration
# This is useful if you're using opam as it adds:
#   - the correct directories to the PATH
#   - auto-completion for the opam binary
# This section can be safely removed at any time if needed.
[[ ! -r '/home/howlingaf/.opam/opam-init/init.zsh' ]] || source '/home/howlingaf/.opam/opam-init/init.zsh' > /dev/null 2> /dev/null
# END opam configuration
