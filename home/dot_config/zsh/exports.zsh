# zsh exports (PATH, environment variables)

# User-installed binaries (chezmoi via get.chezmoi.io/lb, pipx, cargo, etc.)
export PATH="$HOME/.local/bin:$PATH"
# Ability to open editor in OpenCode
export EDITOR="code --wait"
# Enable exa (WebSearch) for OpenCode
export OPENCODE_ENABLE_EXA=1
# Use fd as fzf's file source.
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# chezmoi decrypts ~/.secrets.local from age-encrypted source state; never commit it.
# shellcheck source=/dev/null
[[ -f ~/.secrets.local ]] && source ~/.secrets.local
