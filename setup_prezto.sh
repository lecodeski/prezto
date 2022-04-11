#!zsh
setopt EXTENDED_GLOB
for rcfile in "${ZDOTDIR:-$HOME}"/.zprezto/runcoms/^README.md(.N); do
  ln -s "$rcfile" "${ZDOTDIR:-$HOME}/.${rcfile:t}"
done

echo "$(brew --prefix)/bin/zsh" | sudo tee -a /etc/shells
chsh -s $(brew --prefix)/bin/zsh

if [[ $OS == "Linux" ]]; then
    echo "FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH" >> ~/.profile
    rm -f ${ZDOTDIR:-$HOME}/.zcompdump
    autoload -Uz compinit
    compinit
fi

exec zsh
