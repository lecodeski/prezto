#
# Integrates zsh-autosuggestions into Prezto.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# Source module files.
if [ $commands[fzf] ]; then
  __path=${0:h}
  wrapperfunction() {
      source "$__path/external/fzf-git.sh" || return 1
  }
  wrapperfunction

  #
  # Key Bindings
  #

  export FZF_DEFAULT_OPTS="--bind 'ctrl-f:up,ctrl-v:down,ctrl-g:page-up,ctrl-b:page-down,up:preview-up,down:preview-down,page-up:preview-page-up,page-down:preview-page-down'"
fi
