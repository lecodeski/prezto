#
# Integrates fzf and fzf-git into Prezto.
#

# Source module files.
if [ $commands[fzf] ]; then
  #
  # fzf-git for fancy git widgets powered by fzf
  #
  source "${0:h}/external/fzf-git/fzf-git.sh" 

  #
  # fzf-tab for fancy completions powered by fzf
  #
  # disable sort when completing 
  zstyle ':completion:*' sort false
  # set descriptions format to enable group support
  # NOTE: don't use escape sequences (like '%F{red}%d%f') here, fzf-tab will ignore them
  zstyle ':completion:*' format '[%d]'
  zstyle ':completion:*:descriptions' format '[%d]'
  zstyle ':completion:*:messages' format '[%d]'
  zstyle ':completion:*:warnings' format '[%d]'
  zstyle ':completion:*:corrections' format '[%d]'
  # set list-colors to enable filename colorizing
  zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
  # force zsh not to show completion menu, which allows fzf-tab to capture the unambiguous prefix
  zstyle ':completion:*' menu no

  source "${0:h}/external/fzf-tab/fzf-tab.plugin.zsh"

  # preview directory's content with eza when completing cd
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --long --all --header --git --icons --color=always $realpath'
  # preview generic arguments-rest with bat (for files) and eza (for directories)
  zstyle ':fzf-tab:complete:*:*argument-rest' fzf-preview '
    if [[ -d $realpath ]]; then
      eza --long --all --header --git --icons --color=always $realpath
    elif [[ -f $realpath ]]; then
      echo "$(ls -lh $realpath | awk "{print \$5}") — $(file -b $realpath)"
      echo
      bat --color=always --style=plain --line-range :100 $realpath 2>/dev/null
    fi'
  # Git commits / refs preview
  zstyle ':fzf-tab:complete:git-(diff|log|show|checkout|switch|reset|rebase|cherry-pick|revert):(*argument-rest|*)' \
    fzf-preview 'git show --stat --patch --color=always ${word%% *} 2>/dev/null | DELTA_FEATURES=+ delta --paging=never'
  # Workaround: exclude above preview for certain command as there is no exact 'files only' context qualifier
  # hopefully this list won't get too long
  zstyle ':fzf-tab:complete:alias:argument-rest' fzf-preview ''

  # switch group using `>` and `<`
  zstyle ':fzf-tab:*' switch-group '>' '<'
  # To make fzf-tab follow FZF_DEFAULT_OPTS.
  # NOTE: This may lead to unexpected behavior since some flags break this plugin. See Aloxaf/fzf-tab#455.
  zstyle ':fzf-tab:*' use-fzf-default-opts yes
  # custom fzf flags
  ### lets the completion panel auto calculate it's height: needed vs up to the defined percentage of terminal's height
  ### the redundant binding below is a workaround - the one from defaults is not working for some reason
  zstyle ':fzf-tab:*' fzf-flags --height=~75% --bind 'ctrl-backspace:backward-kill-subword'

  #
  # Options
  #
  export FZF_DEFAULT_PREVIEW_OPTS="
    --preview 'bat --style header-filesize --color=always {}'
    --preview-window '~1'"

  # Use fd (Rust) as directory waker instead internal default (Go)
  export FZF_DEFAULT_COMMAND='fd --hidden --no-ignore-vcs --no-ignore-parent'
  export FZF_CTRL_T_COMMAND='fd --hidden --no-ignore-parent'
  export FZF_ALT_C_COMMAND='fd --type=d --hidden --no-ignore-parent'

  # CTRL-/ to toggle small preview window to see the full command
  # CTRL-Y to copy the command into clipboard using pbcopy
  export FZF_CTRL_R_OPTS="
    --preview 'echo {}' --preview-window up:3:hidden:wrap-word
    --bind 'ctrl-/:toggle-preview'
    --bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort'
    --color header:italic
    --header 'Press CTRL-Y to copy command into clipboard'"

  # fzf-file-widget options
  export FZF_CTRL_T_OPTS=$FZF_DEFAULT_PREVIEW_OPTS

  # fzf-cd-widget (default ALT+C): Print tree structure in the preview window
  export FZF_ALT_C_OPTS="--preview 'tree -C {}'"

  # Avoid using delta for preview (as per git config for side-by-side view)
  export FZF_GIT_PAGER=cat

  # Preview file content using bat (https://github.com/sharkdp/bat)
  # Key Bindings
  export FZF_DEFAULT_OPTS="
    --style=full
    --multi

    --bind 'alt-a:select-all,alt-q:deselect-all'
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
    --bind 'ctrl-j:down-selected'
    --bind 'ctrl-k:up-selected'

    --bind 'up:preview-up'
    --bind 'down:preview-down'
    --bind 'ctrl-w:toggle-preview-wrap-word'
    --bind 'page-up:preview-page-up'
    --bind 'page-down:preview-page-down'
    --bind 'home:preview-top'
    --bind 'end:preview-bottom'"

  # ripgrep->fzf->vim [QUERY]
  fts() {
    rg_args=("${@:2}")

    RELOAD="reload:rg \
      --ignore \
      --column \
      --color=always \
      {q} \
      ${rg_args} \
      || :"

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
        --query "$1"
  }
  compdef fts=rg

  alias fzp="fzf $FZF_DEFAULT_PREVIEW_OPTS"
  alias ap='export AWS_PROFILE=$(sed -n "s/\[profile \(.*\)\]/\1/gp" ~/.aws/config | fzf)'
fi
