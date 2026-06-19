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
_zsh_plugin_install zsh-autosuggestions    https://github.com/zsh-users/zsh-autosuggestions.git
_zsh_plugin_install zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git
_zsh_plugin_install zsh-vim-mode           https://github.com/softmoth/zsh-vim-mode.git

ZSH_THEME="robbyrussell"

eval "$(zoxide init zsh)"

plugins=(
  zsh-autosuggestions
  zsh-vim-mode
  zsh-syntax-highlighting
  zsh-edit
)

source $ZSH/oh-my-zsh.sh

GIT_BRANCH_MAXLEN=24
git_prompt_info() {
  [[ "$(__git_prompt_git config --get oh-my-zsh.hide-info 2>/dev/null)" == "1" ]] && return
  local ref
  ref=$(__git_prompt_git symbolic-ref --short HEAD 2>/dev/null) \
    || ref=$(__git_prompt_git rev-parse --short HEAD 2>/dev/null) \
    || return 0
  ref="${ref#erwinb/}"
  if (( ${#ref} > GIT_BRANCH_MAXLEN )); then
    ref="${ref[1,GIT_BRANCH_MAXLEN]}…"
  fi
  echo "${ZSH_THEME_GIT_PROMPT_PREFIX}${ref}$(parse_git_dirty)${ZSH_THEME_GIT_PROMPT_SUFFIX}"
}

bindkey -v
bindkey -M viins 'jk' vi-cmd-mode

alias vi="nvim"
alias nv="cd $HOME/.config/nvim/"
alias vd="visidata"
alias src=". $HOME/.zshrc && echo '.zshrc sourced'"
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
  # Inside a git repo, only offer files from that repo; otherwise the full list.
  root=$(git rev-parse --show-toplevel 2>/dev/null)
  file=$(tac ~/.edit_history | while IFS= read -r f; do
    [[ -f $f ]] || continue
    [[ -n $root && $f != $root/* ]] && continue
    print -r -- "$f"
  done | fzy)
  [[ -z "$file" ]] && return
  cd "${file%/*}" && nvim "$file"
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

# Centre the prompt the way scrolloff=999 centres the nvim cursor: the prompt
# starts at the top and can descend only to the vertical middle; past that,
# output scrolls up and the prompt stays put. Works in any terminal that answers
# a cursor-position query (DSR) -- essentially all of them, nvim's included.
_center_prompt() {
  emulate -L zsh
  [[ -t 1 ]] || return              # only when stdout is a real terminal
  local target=$(( LINES / 2 )) reply row
  # Ask the terminal for the cursor row (DSR); it replies on the tty.
  print -n "\e[6n" >/dev/tty
  IFS= read -rs -t 0.3 -d R reply </dev/tty || return
  reply=${reply#*$'\e['}            # strip the ESC[ prefix -> "row;col"
  row=${reply%%;*}
  [[ $row == <-> ]] || return       # bail unless it's a clean number
  # Only act once the prompt would sit below the middle: scroll the screen up
  # so the upcoming prompt lands exactly on the centre row.
  (( row > target )) && print -n "\e[$(( row - target ))S\e[${target};1H" >/dev/tty
}
add-zsh-hook precmd _center_prompt

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
