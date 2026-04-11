export ZSH="$HOME/.oh-my-zsh"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export EDITOR="nvim"
export VISUAL="nvim"

plugins=(
  fzf-tab
  zsh-autosuggestions
  zsh-vim-mode
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

bindkey -v
bindkey -M viins 'jk' vi-cmd-mode

alias vi="nvim"
alias vd="visidata"
alias src=". $HOME/.zshrc && echo '.zshrc sourced'"
alias rc="nvim $HOME/.zshrc"
alias dg='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'

eval "$(zoxide init zsh)"

chpwd(){
    local tmp=$(grep -v "^$OLDPWD$" ~/.cd_history)
    echo "$tmp" > ~/.cd_history;
    echo "$OLDPWD" >> ~/.cd_history;
}

fzf_edit_history(){
  local file=$(tac ~/.edit_history | fzy)
  if [[ -z "$file" ]]; then
    zle reset-prompt
    return
  fi
  local dir=${file%/*}
  cd "$dir"
  nvim "$file"
  zle reset-prompt
}

fzf_cd_history(){
  local dir=$(tac ~/.cd_history | fzy)
  [[ -n "$dir" ]] && cd "$dir"
  zle reset-prompt
}

zle -N fzf_cd_history
bindkey '^A' fzf_cd_history
zle -N fzf_edit_history
bindkey '^S' fzf_edit_history

[[ -f ~/.zshrc.mac ]] && source ~/.zshrc.mac
[[ -f ~/.zshrc.wsl ]] && source ~/.zshrc.wsl
