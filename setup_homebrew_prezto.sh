#!/bin/bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

if [[ $(uname) == "Linux" ]]; then
  eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)
  echo 'eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)' >> ~/.profile
fi

brew install zsh

brew install git

brew install vim
brew install eza
brew install ripgrep
brew install bat
brew install bat-extras
brew install icdiff
brew install git-delta
brew install dua-cli
brew install ncdu
brew install git-open
brew install tree
brew install zsh-completions
brew install fd

brew install fzf
$(brew --prefix)/opt/fzf/install

# Install vim plugin manager vim-plug
curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

$(brew --prefix)/bin/zsh "${ZDOTDIR:-$HOME}"/.zprezto/setup_prezto.zsh
