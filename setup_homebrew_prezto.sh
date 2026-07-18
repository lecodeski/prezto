#!/bin/bash
(( EUID )) || { echo "ERROR: don't run this script as root - bad things can happen" >&2; exit 1; }
[[ $OSTYPE == darwin* && $(sysctl -n sysctl.proc_translated 2>/dev/null) == 1 ]] && { echo "ERROR: Rosetta shell, run from a native arm64 terminal" >&2; exit 1; }
script=$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh) && [[ $script ]] && /bin/bash -c "$script" || { echo "ERROR: Homebrew install failed" >&2; exit 1; }

case $OSTYPE-$HOSTTYPE in
  darwin*-arm64 | darwin*-aarch64) HOMEBREW_PREFIX=/opt/homebrew ;;
  darwin*)                         HOMEBREW_PREFIX=/usr/local ;;
  *)                               HOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew ;;
esac
[[ -x $HOMEBREW_PREFIX/bin/brew ]] || { echo "ERROR: no brew at $HOMEBREW_PREFIX, install failed?" >&2; exit 1; }
eval "$("$HOMEBREW_PREFIX"/bin/brew shellenv)"

brew bundle --file="${ZDOTDIR:-$HOME}"/.zprezto/setup_Brewfile
[[ -x $HOMEBREW_PREFIX/bin/zsh ]] || { echo "ERROR: no zsh at $HOMEBREW_PREFIX/bin/zsh, aborting" >&2; exit 1; }
"$HOMEBREW_PREFIX"/opt/fzf/install --key-bindings --completion --no-update-rc

"${ZDOTDIR:-$HOME}"/.zprezto/setup_prezto.zsh
