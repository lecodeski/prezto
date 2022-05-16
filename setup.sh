"${ZDOTDIR:-$HOME}"/.zprezto/setup_brew.sh
[[ $(uname) == "Linux" ]] && eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)
$(brew --prefix)/bin/zsh "${ZDOTDIR:-$HOME}"/.zprezto/setup_prezto.sh
