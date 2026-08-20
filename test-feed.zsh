#!/bin/zsh -f
# Feed lines to an isolated interactive zsh running the live zshaddhistory
# hook, then print the resulting histfile. Never touches the real history.
# Usage: ./test-feed.zsh '<line>' ...
emulate -L zsh -o err_exit
zd=$(mktemp -d ${TMPDIR:-/tmp}/zsh-feed.XXXXXX)
{
  awk '/^# Keep mistyped commands out of history/,/^\}$/' ${0:A:h}/runcoms/zshrc > $zd/.zshrc
  cat >> $zd/.zshrc <<'EOF'
HISTFILE=$ZDOTDIR/hist
HISTSIZE=100
SAVEHIST=100
setopt hist_ignore_dups hist_ignore_space share_history auto_cd cdable_vars
EOF
  # a fed line that reads stdin (cat, read) can swallow the rest of the feed —
  # redirect its stdin or put it last
  print -rl -- "$@" 'exit 0' | ZDOTDIR=$zd zsh -i 2> /dev/null > /dev/null
  cat $zd/hist
} always {
  rm -rf $zd
}
