export ZSH="$HOME/.oh-my-zsh"
export EDITOR="nvim"
export VISUAL="nvim"
source $ZSH/oh-my-zsh.sh
ZSH_THEME="agnoster"
plugins=(
  git
  zsh-autosuggestions
  zsh-vim-mode
  zsh-syntax-highlighting
)
bindkey -v
bindkey -M viins 'jk' vi-cmd-mode
alias vi="nvim"
alias sr="source $HOME/.zshrc"
alias ya="yazi"
alias zs="nvim $HOME/.zshrc"
alias dotgit='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
alias instance1="gcloud compute ssh instance-1 --zone us-central1-a"

eval "$(zoxide init zsh)"
setopt PROMPT_SUBST
PROMPT='%F{cyan}$(shorten_path)%f %F{yellow}$(git rev-parse --abbrev-ref HEAD 2>/dev/null)%f %# '

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
