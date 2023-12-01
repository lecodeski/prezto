#
# Initializes Prezto.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

#
# Version Check
#

# Check for the minimum supported version.
min_zsh_version='4.3.11'
if ! autoload -Uz is-at-least || ! is-at-least "$min_zsh_version"; then
  printf "prezto: old shell detected, minimum required: %s\n" "$min_zsh_version" >&2
  return 1
fi
unset min_zsh_version

# zprezto convenience updater
# The function is surrounded by ( ) instead of { } so it starts in a subshell
# and won't affect the environment of the calling shell
function zprezto-update {
  (
    function cannot-fast-forward {
      local STATUS="$1"
      [[ -n "${STATUS}" ]] && printf "%s\n" "${STATUS}"
      printf "Unable to fast-forward the changes. You can fix this by "
      printf "running\ncd '%s' and then\n'git pull' " "${ZPREZTODIR}"
      printf "to manually pull and possibly merge in changes\n"
    }
    cd -q -- "${ZPREZTODIR}" || return 7

    git fetch --all || return "$?"
    local LOCAL=$(git rev-parse main)
    local REMOTE=$(git rev-parse origin/main)
    local BASE=$(git merge-base main origin/main)

    if [[ $LOCAL == $REMOTE ]]; then
      printf "There are no updates.\n"
      return 0

    elif [[ $LOCAL == $BASE ]]; then
      printf "There is an update available. Trying to pull.\n\n"

      local orig_branch="$(git branch --show-current)"
      [[ "$orig_branch" != "main" ]] && local off_main=$orig_branch
      [[ $(git diff --stat) != '' ]] && local dirty=1

      [ $dirty ] && git stash
      [ $off_main ] && git switch main

      if git pull --ff-only; then
        printf "Syncing submodules\n"
        git submodule sync --recursive
        git submodule update --init --recursive
        [ $off_main ] && git switch $orig_branch && git rebase main && git push --force-with-lease --force-if-includes
        [ $dirty ] && git stash pop
        return $?

      else
        cannot-fast-forward
        return 1
      fi

    elif [[ $REMOTE == $BASE ]]; then
      cannot-fast-forward "Commits in main that aren't in upstream."
      return 1

    else
      cannot-fast-forward "Upstream and local have diverged."
      return 1
    fi

    return 1
  )
}
#
# Module Loader
#

# Loads Prezto modules.
function pmodload {
  local -a pmodules
  local -a pmodule_dirs
  local -a locations
  local pmodule
  local pmodule_location
  local pfunction_glob='^([_.]*|prompt_*_setup|README*|*~)(-.N:t)'

  # Load in any additional directories and warn if they don't exist
  zstyle -a ':prezto:load' pmodule-dirs 'user_pmodule_dirs'
  for user_dir in "$user_pmodule_dirs[@]"; do
    if [[ ! -d "$user_dir" ]]; then
      echo "$0: Missing user module dir: $user_dir"
    fi
  done

  pmodule_dirs=("$ZPREZTODIR/modules" "$ZPREZTODIR/contrib" "$user_pmodule_dirs[@]")

  # $argv is overridden in the anonymous function.
  pmodules=("$argv[@]")

  # Load Prezto modules.
  for pmodule in "$pmodules[@]"; do
    if zstyle -t ":prezto:module:$pmodule" loaded 'yes' 'no'; then
      continue
    else
      locations=(${pmodule_dirs:+${^pmodule_dirs}/$pmodule(-/FN)})
      if (( ${#locations} > 1 )); then
        if ! zstyle -t ':prezto:load' pmodule-allow-overrides 'yes'; then
          print "$0: conflicting module locations: $locations"
          continue
        fi
      elif (( ${#locations} < 1 )); then
        print "$0: no such module: $pmodule"
        continue
      fi

      # Grab the full path to this module
      pmodule_location=${locations[-1]}

      # Add functions to $fpath.
      fpath=(${pmodule_location}/functions(-/FN) $fpath)

      function {
        local pfunction

        # Extended globbing is needed for listing autoloadable function directories.
        setopt LOCAL_OPTIONS EXTENDED_GLOB

        # Load Prezto functions.
        for pfunction in ${pmodule_location}/functions/$~pfunction_glob; do
          autoload -Uz "$pfunction"
        done
      }

      if [[ -s "${pmodule_location}/init.zsh" ]]; then
        source "${pmodule_location}/init.zsh"
      elif [[ -s "${pmodule_location}/${pmodule}.plugin.zsh" ]]; then
        source "${pmodule_location}/${pmodule}.plugin.zsh"
      fi

      if (( $? == 0 )); then
        zstyle ":prezto:module:$pmodule" loaded 'yes'
      else
        # Remove the $fpath entry.
        fpath[(r)${pmodule_location}/functions]=()

        function {
          local pfunction

          # Extended globbing is needed for listing autoloadable function
          # directories.
          setopt LOCAL_OPTIONS EXTENDED_GLOB

          # Unload Prezto functions.
          for pfunction in ${pmodule_location}/functions/$~pfunction_glob; do
            unfunction "$pfunction"
          done
        }

        zstyle ":prezto:module:$pmodule" loaded 'no'
      fi
    fi
  done
}

#
# Prezto Initialization
#

# This finds the directory prezto is installed to so plugin managers don't need
# to rely on dirty hacks to force prezto into a directory. Additionally, it
# needs to be done here because inside the pmodload function ${0:h} evaluates to
# the current directory of the shell rather than the prezto dir.
ZPREZTODIR=${0:h}

# Source the Prezto configuration file.
if [[ -s "${ZDOTDIR:-$HOME}/.zpreztorc" ]]; then
  source "${ZDOTDIR:-$HOME}/.zpreztorc"
fi

# Disable color and theme in dumb terminals.
if [[ "$TERM" == 'dumb' ]]; then
  zstyle ':prezto:*:*' color 'no'
  zstyle ':prezto:module:prompt' theme 'off'
fi

# Load Zsh modules.
zstyle -a ':prezto:load' zmodule 'zmodules'
for zmodule ("$zmodules[@]") zmodload "zsh/${(z)zmodule}"
unset zmodule{s,}

# Load more specific 'run-help' function from $fpath.
(( $+aliases[run-help] )) && unalias run-help && autoload -Uz run-help

# Autoload Zsh functions.
zstyle -a ':prezto:load' zfunction 'zfunctions'
for zfunction ("$zfunctions[@]") autoload -Uz "$zfunction"
unset zfunction{s,}

# Load Prezto modules.
zstyle -a ':prezto:load' pmodule 'pmodules'
pmodload "$pmodules[@]"
unset pmodules
