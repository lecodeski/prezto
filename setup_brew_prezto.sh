#!/bin/bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

if [[ $(uname) == "Linux" ]]; then
  eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)
  echo 'eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)' >> ~/.profile
fi

brew install zsh

brew install git
# remove automatically installed but inferior completion script
rm -f $(brew --prefix)/share/zsh/site-functions/_git

brew install exa
brew install bat
brew install icdiff
brew install git-delta
brew install ncdu
brew install links
brew install googler
brew install git-open
brew install translate-shell

brew install fzf
$(brew --prefix)/opt/fzf/install

$(brew --prefix)/bin/zsh "${ZDOTDIR:-$HOME}"/.zprezto/setup_prezto.sh
