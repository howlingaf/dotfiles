export ZSH="$HOME/.oh-my-zsh"
export EDITOR="nvim"
export VISUAL="nvim"

plugins=(
  fzf-tab
  zsh-autosuggestions
  zsh-vim-mode
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

#bindings
bindkey -v
bindkey -M viins 'jk' vi-cmd-mode

#alias
alias vi="nvim"
alias src=". $HOME/.zshrc && echo '.zshrc sourced'"
alias rc="nvim $HOME/.zshrc"
alias dg='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
alias server="gcloud compute ssh arketa-migrations --zone=us-central1-f"

eval "$(zoxide init zsh)"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

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
