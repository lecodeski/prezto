#!zsh
setopt EXTENDED_GLOB
rm "${ZDOTDIR:-$HOME}/.zshrc"
for rcfile in "${ZDOTDIR:-$HOME}"/.zprezto/runcoms/^README.md(.N); do
  ln -s "$rcfile" "${ZDOTDIR:-$HOME}/.${rcfile:t}"
done
