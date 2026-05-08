export ZSH="$HOME/.oh-my-zsh"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
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

eval "$(zoxide init zsh)"

bindkey -v
bindkey -M viins 'jk' vi-cmd-mode

alias vi="nvim"
alias nv="cd $HOME/.config/nvim/ && nvim ."
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


chpwd(){
    local tmp=$(grep -v "^$OLDPWD$" ~/.cd_history)
    echo "$tmp" > ~/.cd_history;
    echo "$OLDPWD" >> ~/.cd_history;
}

fzf_edit_history(){
  local file=$(tac ~/.edit_history | fzy)
  if [[ -z "$file" ]]; then
    return
  fi
  local dir=${file%/*}
  cd "$dir"
  nvim "$file"
}

fzf_cd_history(){
  local dir=$(tac ~/.cd_history | fzy)
  [[ -n "$dir" ]] && cd "$dir"
}

launch_nvim(){
  nvim .
}


bind '^A' fzf_cd_history
bind '^S' fzf_edit_history
bind '^N' launch_nvim


foo (){
  echo "hi"
}


[[ -f ~/.zshrc.mac ]] && source ~/.zshrc.mac
[[ -f ~/.zshrc.wsl ]] && source ~/.zshrc.wsl
[[ -f ~/.zshrc.linux ]] && source ~/.zshrc.linux
