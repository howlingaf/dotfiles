export ZSH="$HOME/.oh-my-zsh"
export EDITOR="nvim"
export VISUAL="nvim"
ZSH_THEME=""  # No theme - we'll use custom prompt
plugins=(
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

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

source $ZSH/oh-my-zsh.sh

# Fast custom prompt: just directory and git branch
function git_branch_fast() {
  # Fast: only get branch name, no status checks
  local branch
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [[ -n "$branch" ]]; then
    echo "$branch"
  fi
}

# Simple prompt: directory (cyan) + git branch (blue) if in repo
setopt PROMPT_SUBST
PROMPT='%F{cyan}%1~%f %F{blue}$(git_branch_fast)%f %# '
