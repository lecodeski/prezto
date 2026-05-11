#
# Integrates fzf and fzf-git into Prezto.
#

# Source module files.
if [ $commands[fzf] ]; then
  __path=${0:h}
  wrapperfunction() {
      source "$__path/external/fzf-git.sh" || return 1
  }
  wrapperfunction

  #
  # Options
  #

  # Use fd (Rust) as directory waker instead internal default (Go)
  export FZF_DEFAULT_COMMAND='fd --hidden --no-ignore-vcs --no-ignore-parent'
  export FZF_CTRL_T_COMMAND='fd --hidden --no-ignore-parent'
  export FZF_ALT_C_COMMAND='fd --type=d --hidden --no-ignore-parent'

  # CTRL-/ to toggle small preview window to see the full command
  # CTRL-Y to copy the command into clipboard using pbcopy
  export FZF_CTRL_R_OPTS="
    --preview 'echo {}' --preview-window up:3:hidden:wrap
    --bind 'ctrl-/:toggle-preview'
    --bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort'
    --color header:italic
    --header 'Press CTRL-Y to copy command into clipboard'"

  # Print tree structure in the preview window
  export FZF_ALT_C_OPTS="
    --preview 'tree -C {}'"

  # Avoid using delta for preview (as per git config for side-by-side view)
  export FZF_GIT_PAGER=cat

  # Preview file content using bat (https://github.com/sharkdp/bat)
  # Key Bindings
  export FZF_DEFAULT_OPTS="
    --preview 'bat --style header-filesize --color=always {}'
    --bind 'ctrl-d:change-preview-window(down|hidden|)'
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
