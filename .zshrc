# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export EDITOR="nvim"
export VISUAL="nvim"

# Ctrl-D at empty prompt does nothing (prevents accidental shell exit +
# tmux pane close + eventual server death).
setopt IGNORE_EOF

ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  zsh-autosuggestions
  zsh-vim-mode
  zsh-syntax-highlighting
  zsh-edit
)

source $ZSH/oh-my-zsh.sh

eval "$(zoxide init zsh)"

bindkey -v
bindkey -M viins 'jk' vi-cmd-mode

alias vi="nvim"
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
  claude -c "$@"
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

bind '^A' fzf_cd_history
bind '^S' fzf_edit_history


foo (){
  echo "hi"
}

bind '^F' foo


[[ -f ~/.zshrc.mac ]] && source ~/.zshrc.mac
[[ -f ~/.zshrc.wsl ]] && source ~/.zshrc.wsl

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


