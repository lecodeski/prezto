#
# Integrates fzf and fzf-git into Prezto.
#

# Source module files.
if [ $commands[fzf] ]; then
  source "${0:h}/external/fzf-git.sh"

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

  # fzf-cd-widget (default ALT+C): Print tree structure in the preview window
  bindkey '^x' fzf-cd-widget
  export FZF_ALT_C_OPTS="
    --preview 'tree -C {}'"

  # Avoid using delta for preview (as per git config for side-by-side view)
  export FZF_GIT_PAGER=cat

  # Preview file content using bat (https://github.com/sharkdp/bat)
  # Key Bindings
  export FZF_DEFAULT_OPTS="
    --preview 'bat --style header-filesize --color=always {}'
    --style=full

    --bind 'alt-a:select-all,alt-x:deselect-all' \
    --bind 'ctrl-p:change-preview-window(down|hidden|)'

    --bind 'alt-f:forward-subword'
    --bind 'alt-b:backward-subword'
    --bind 'ctrl-backspace:backward-kill-subword'
    --bind 'alt-d:kill-subword'
    --bind 'alt-right:end-of-line'
    --bind 'alt-left:beginning-of-line'

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

  # ripgrep->fzf->vim [QUERY]
  fts() {
    RELOAD='reload:rg --hidden --no-ignore-parent --column --color=always --colors=path:fg:blue --colors=line:fg:yellow --smart-case {q} || :'
    OPENER='if [[ $FZF_SELECT_COUNT -eq 0 ]]; then
              vim {1} +{2}     # No selection. Open the current line in Vim.
            else
              vim +cw -q {+f}  # Build quickfix list for the selected items.
            fi'
    fzf --disabled --ansi --multi \
        --bind "start:$RELOAD" --bind "change:$RELOAD" \
        --bind "enter:become:$OPENER" \
        --bind "ctrl-o:execute:$OPENER" \
        --bind 'ctrl-p:toggle-preview' \
        --delimiter : \
        --preview 'bat --style=numbers,header-filesize --color=always --highlight-line {2} {1}' \
        --preview-window '~1,+{2}/3,<80(up)' \
        --query "$*"
  }
fi
