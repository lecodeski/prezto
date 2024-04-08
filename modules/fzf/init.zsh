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

  export FZF_DEFAULT_OPTS="
  --bind 'ctrl-f:up'
  --bind 'ctrl-v:down'
  --bind 'ctrl-g:page-up'
  --bind 'ctrl-b:page-down'
  --bind 'ctrl-a:top'
  --bind 'ctrl-e:last'
  --bind 'up:preview-up'
  --bind 'down:preview-down'
  --bind 'ctrl-w:toggle-preview-wrap'
  --bind 'page-up:preview-page-up'
  --bind 'page-down:preview-page-down'
  --bind 'home:preview-top'
  --bind 'end:preview-bottom'"
fi
