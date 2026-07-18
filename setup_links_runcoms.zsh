#!/usr/bin/env zsh
(( EUID )) || { echo "ERROR: don't run this script as root - bad things can happen" >&2; exit 1; }
setopt EXTENDED_GLOB
err=0
for rcfile in "${ZDOTDIR:-$HOME}"/.zprezto/runcoms/^README.md(.N); do
  target="${ZDOTDIR:-$HOME}/.${rcfile:t}"
  [[ -L $target && $target -ef $rcfile ]] && continue
  [[ -e $target || -L $target ]] && mv "$target" "$target.bak-$(date +%Y%m%d%H%M%S)"
  ln -s "$rcfile" "$target" || err=1
done
exit $err
