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

# restore the dirstack carried across zprezto-restart's exec (producer below)
if (( $+_ZPREZTO_DIRSTACK )); then
  dirstack=(${(ps:\n:)_ZPREZTO_DIRSTACK})
  unset _ZPREZTO_DIRSTACK
fi

# lock helper for concurrency control; the acquired fd lands in $_zprezto_update_lock_fd
# (no concurrent writers by construction: the lock itself serializes)
_zprezto_update_lock="${XDG_CACHE_HOME:-$HOME/.cache}/prezto/update.lock"
function zprezto-update-trylock {
  # a set marker reenters for genuinely nested calls only (caller has a caller)
  # at top level it means a suspended update or its leftover → refuse
  if (( $+_zprezto_update_lock_fd )); then
    (( $#funcstack > 2 )) && return 0
  else
    zmodload zsh/system && mkdir -p "${_zprezto_update_lock:h}" && : >>| "$_zprezto_update_lock" || {
      print "💥 cannot create lock anchor $_zprezto_update_lock" >&2
      return 1
    }
    zsystem flock -t 0 -f _zprezto_update_lock_fd "$_zprezto_update_lock" 2> /dev/null && return 0
  fi
  print "💥 another update is already running (suspended or other shell? check jobs / tabs; a leftover clears via exec zsh)" >&2
  return 1
}

# release + required unset in one place
function zprezto-update-unlock {
  zsystem flock -u $_zprezto_update_lock_fd
  unset _zprezto_update_lock_fd
}

# zprezto convenience updater
# The git work runs in a ( ) subshell; the tail runs in the calling shell
# re-sources zpreztorc, refreshes completions, may exec-restart
function zprezto-update {
  # untyped: must stay empty when unassigned — ${RESTART:+…} depends on it (-i would pin 0, non-empty)
  local RESTART

  case $1 in
    '') RESTART=1 ;;
    --skip-restart) ;;
    *) print "usage: zprezto-update [--skip-restart]" >&2; return 1 ;;
  esac

  (
    # an inherited GIT_DIR outranks both cd and git -C, pointing every git call below at a foreign repo
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

    function cannot-fast-forward {
      [[ -n $1 ]] && print $1
      print "💥 Unable to fast-forward the changes. You can fix this by running"
      print "cd '$ZPREZTODIR', check the condition of your working copy and probably then"
      print "'git switch main && git pull'"
      print "to manually pull and possibly merge in changes and then re-run your last update command"
    } >&2

    function pull-update {
      local orig_branch=$1
      local -i dirty=$2
      local -i off_main=0

      [[ $orig_branch != main ]] && off_main=1
      (( off_main )) && { git switch main || return }

      # the already-fetched ref the gate compared, not whatever branch.main.merge points at
      git merge --ff-only origin/main || {
        cannot-fast-forward
        return 1
      }
      print "🍺 Syncing submodules" &&
        git submodule sync --recursive &&
        git submodule foreach --recursive 'git fetch --tags' &&
        git submodule update --init --recursive || return

      if (( off_main )) && ! {
        git switch $orig_branch &&
        git rebase main &&
        # check for branch's remote is origin before FORCE-pushing
        { [[ $(git rev-parse --abbrev-ref @{push} 2> /dev/null) != origin/* ]] ||
          git push --force-with-lease --force-if-includes } }
      then
        print "💥 Update pulled, but restoring '$orig_branch' (switch/rebase/push) failed — resolve manually; not restarting." >&2
        return 1
      fi
      if (( dirty )); then git stash pop || return; fi
    }

    # lock lives only in subshell and is auto-released
    zprezto-update-trylock || return

    builtin cd -q -- "$ZPREZTODIR" || return 7

    git fetch --all -q || return 1
    local ORIG_BRANCH="$(git branch --show-current)"
    local LOCAL=$(git rev-parse --verify --quiet main)
    local REMOTE=$(git rev-parse --verify --quiet origin/main)
    local BASE=$(git merge-base main origin/main)

    git diff --quiet --diff-filter=U
    if (( $? == 1 )); then # rc 1 is "unmerged paths found" — anything else is a git error, not a conflict
      cannot-fast-forward "💥 unresolved merge — resolve it (git status) first"
    elif [[ -z $ORIG_BRANCH ]]; then
      cannot-fast-forward "💥 detached HEAD — check out a branch first"
    elif [[ -z $LOCAL ]]; then
      cannot-fast-forward "💥 no local 'main' branch"
    elif [[ -z $REMOTE ]]; then
      cannot-fast-forward "💥 no 'origin/main' — check the remote"
    elif [[ $LOCAL == $REMOTE ]]; then
      print "🛌 There are no updates${RESTART:+, skipping restart}."
      return 0

    elif [[ $LOCAL == $BASE ]]; then
      print "🍺 There is an update available. Trying to pull.\n"

      local -i DIRTY=0
      [[ -n $(git status --porcelain --ignore-submodules) ]] && DIRTY=1
      (( DIRTY )) && { git stash push --include-untracked || return 1 }

      pull-update "$ORIG_BRANCH" $DIRTY && return 42 # arbitrary "pulled" marker for the parent

      (( DIRTY )) && print "💡 Note: your local changes are still stashed."
      local CUR_BRANCH="${$(git branch --show-current):-detached}"
      [[ $CUR_BRANCH != $ORIG_BRANCH ]] &&
        print "💡 Note: HEAD is now on '$CUR_BRANCH' (started on '$ORIG_BRANCH')."

    elif [[ $REMOTE == $BASE ]]; then
      cannot-fast-forward "💥 Commits in main that aren't in upstream."
    else
      cannot-fast-forward "💥 Upstream and local have diverged."
    fi

    return 1
  )
  local ret=$?   # 42=pulled, 0=up-to-date, else git failure; capture before anything consumes it
  (( ret != 42 && ret != 0 )) && return $ret

  # re-source for new vendored-completion URLs before the restart (pure zstyle, idempotent)
  [[ -s "${ZDOTDIR:-$HOME}/.zpreztorc" ]] && source "${ZDOTDIR:-$HOME}/.zpreztorc"
  zprezto-dumb-term-overrides
  if zstyle -t ':prezto:module:vendored-completions' loaded && ! update-vendored-completions && (( !RESTART )); then
    print "ERROR: vendored-completions refresh failed (see above)." >&2
    return 1
  fi

  if (( RESTART && ret == 42 )); then
    zprezto-restart
  fi
}

# Reload the shell in place
function zprezto-restart {
  # exec would replace a subshell, or hand the new shell non-tty stdio (a non-tty
  # stdin makes it start non-interactive, read EOF and exit — killing the session)
  [[ -o interactive && -t 0 && -t 1 ]] && (( ZSH_SUBSHELL == 0 )) || return 0

  if ! zmodload zsh/parameter; then
    print "ERROR: cannot load zsh/parameter to check for jobs." >&2
    return 2
  fi
  if (( $#jobstates )); then
    print "💥 Not restarting - background/suspended jobs would be killed." >&2
    return 1
  fi
  print "♻️ Restarting shell"
  export _ZPREZTO_DIRSTACK=${(pj:\n:)dirstack}
  [[ -o login ]] && exec zsh -l
  exec zsh
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

# Disable color and theme in dumb terminals (re-applied wherever zpreztorc is re-sourced).
function zprezto-dumb-term-overrides {
  [[ $TERM == dumb ]] || return 0
  zstyle ':prezto:*:*' color 'no'
  zstyle ':prezto:module:prompt' theme 'off'
}
zprezto-dumb-term-overrides

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
