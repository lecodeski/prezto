#!/usr/bin/env zsh
(( EUID )) || { print -u2 "ERROR: don't run this script as root - bad things can happen"; exit 1; }

"${ZDOTDIR:-$HOME}"/.zprezto/setup_links_runcoms.zsh ||
  { print -u2 "ERROR: linking runcoms failed, aborting"; exit 1; }

# installs vim plugin manager "vim-plug"
curl -fLo "$HOME"/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

bp=${HOMEBREW_PREFIX:-$(brew --prefix 2>/dev/null)}
zpath=${bp:+$bp/bin/zsh}
[[ -x $zpath ]] || zpath=${commands[zsh]}

print "\nINFO & sudo: Changing login shell to $zpath and extending sshd config with IntelliJ env var transfer"
if sudo -v; then
  grep -qxF "$zpath" /etc/shells ||
    print "\n$zpath" | sudo tee -a /etc/shells >/dev/null

  me=$(id -un)

  sudo chsh -s "$zpath" "$me" ||
    chsh -s "$zpath" ||
    sudo usermod -s "$zpath" "$me" ||
    print -u2 "WARN: could not set login shell to $zpath"

  # server half of IntelliJ terminal detection over SSH; the client half is
  # IntelliJ's terminal env var TERMINAL_INTELLIJ=TRUE (in IntelliJ settings);
  # plain `ssh` additionally needs `SendEnv TERMINAL_INTELLIJ` in ssh config
  if [[ $OSTYPE != darwin* ]]; then
    sshd_config_d=/etc/ssh/sshd_config.d
    if [[ -d $sshd_config_d ]]; then
      print 'AcceptEnv TERMINAL_INTELLIJ' | sudo tee "$sshd_config_d"/50-terminal-intellij.conf >/dev/null

      sudo systemctl try-reload-or-restart ssh || sudo systemctl try-reload-or-restart sshd

      sudo sshd -T | grep -qi terminal_intellij ||
        print -u2 "WARN: AcceptEnv not effective, check sshd running and Include in sshd_config"
    else
      print -u2 "WARN: no $sshd_config_d, skipping sshd config"
    fi
  fi
else
  print -u2 "WARN: no sudo, skipping login shell (and sshd config on non-macOS)"
fi

exec "$zpath" -l
