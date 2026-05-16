#!zsh
setopt EXTENDED_GLOB
rm "${ZDOTDIR:-$HOME}/.zshrc"
for rcfile in "${ZDOTDIR:-$HOME}"/.zprezto/runcoms/^README.md(.N); do
  ln -s "$rcfile" "${ZDOTDIR:-$HOME}/.${rcfile:t}"
done

if [[ $commands[brew] ]]; then
  echo "$(brew --prefix)/bin/zsh" | sudo tee -a /etc/shells
  chsh -s $(brew --prefix)/bin/zsh

  if [[ $(uname) == "Linux" ]]; then
      rm -f ${ZDOTDIR:-$HOME}/.zcompdump
      autoload -Uz compinit
      compinit

      sudo sh -c 'echo "AcceptEnv TERMINAL_INTELLIJ" >> /etc/ssh/sshd_config'
      sudo systemctl restart sshd
  fi
fi

exec zsh
