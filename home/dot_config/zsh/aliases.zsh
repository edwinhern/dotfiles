# zsh aliases and small helper functions

alias cd="z"
alias find="fd"
alias o="open ."
alias l="ls"
alias ll="ls -al"
# shellcheck disable=SC2139 # ZDOTDIR is set at shell start; expand at alias define is fine
alias ozh='code ${ZDOTDIR:-$HOME}/.zshrc'
# shellcheck disable=SC2139
alias szh='source ${ZDOTDIR:-$HOME}/.zshrc'
alias kp="killport"
alias ".."="cd .."
alias update="brew update && brew upgrade && brew cleanup && mise upgrade"
