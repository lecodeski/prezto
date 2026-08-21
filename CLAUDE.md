# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Personal fork of [sorin-ionescu/prezto](https://github.com/sorin-ionescu/prezto) (zsh config framework). Remote `origin` = lecodeski/prezto, `upstream` = sorin-ionescu/prezto. Default branch: `main`.

**This repo is the live shell config of this machine.** Files in `runcoms/` are symlinked into `$HOME` as dotfiles (via `setup_links_runcoms.zsh`, which links every `runcoms/` file except README.md — a new file there needs a re-run to go live). Edits take effect in every new shell immediately. **Broken syntax breaks shell startup** — always syntax-check.

## Commands

No build or test suite. Instead:

- syntax-check a zsh file: `zsh -n <file>`
- verify a change: fresh shell — `zsh -ic 'exit'` catches startup errors
- no-tty runs of `zsh -ic 'exit'` (sandboxes, CI, pipes) print benign noise on
  stderr: `can't change option: monitor`/`zle`, a gitstatus init failure, `gstty`
  device errors, plus sandbox write denials (`touch: … zcompdump`, `warn: error
  in creating config file.`) — only other output indicates a real startup error.
  A `zsh -i` fed on stdin adds `locking failed for …/.zsh_history` at exit,
  which `-c` skips
- that shell also writes iTerm2 OSC sequences (`]1337;RemoteHost=…`) — they land
  on stdout or stderr depending on redirect order, and glue themselves to the
  first line of output. A command that greps or anchors that line loses it:
  `zsh -ic 'setopt'` hides its first option from `grep '^name$'` — prepend a
  `print` to break the glue
- Claude's shell **expands the live aliases** but carries only part of the
  option state — `extendedglob` is off there and on in a real shell (verified),
  so judge option-dependent code with `zsh -ic`, never from the tool shell.
  `noclobber` does carry over, so `>` to an existing file fails — use `>|`
- apply a change to the running shell: `zprezto-restart` (`exec`s zsh; refuses while
  jobs exist)
- update fork + submodules: `zprezto-update` (`-s` skips the restart) — fork-custom,
  defined in `init.zsh`; semantics in [README](README.md#updating)
- submodules after checkout: `git submodule update --init --recursive`
- re-fetch vendored completion files: `update-vendored-completions`

## Commit convention

`<type>: <message with `backticked` names>` — types: `add`, `mod`, `del`, `fix`, `refac`, `bump`. Exactly one trailing emoji, varied across commits. The `cm` script (`modules/utility/bin/cm`) generates these via Haiku API.

## Architecture

Load order: `runcoms/zshenv` → `zprofile` → `zshrc` (sources `init.zsh`) → `zlogin`.

- `init.zsh` — loader. Reads `zstyle ':prezto:load' pmodule` from `runcoms/zpreztorc` and sources each `modules/<name>/init.zsh` **in listed order** (order matters: `syntax-highlighting` before `history-substring-search`, `completion` before `autosuggestions`, `prompt` late). Also defines the fork's `zprezto-update` + `zprezto-restart`.
- `runcoms/zpreztorc` — the switchboard: module list plus every `zstyle ':prezto:*'` setting (including the vendored-completion URLs). A module reads its own settings; it does not read the list.
- `modules/<name>/` — `init.zsh` plus optional `functions/` (autoloaded, `_*`/`README*` skipped), `bin/` (module puts it on PATH itself — only `utility` does), and `external/` (git submodules of third-party plugins). Fork additions: `fzf` module (fzf-tab, fzf-git), `vendored-completions` module, `utility/bin/` (`cm`, `cpy`, `pst`).
- `runcoms/` — zsh startup files plus non-zsh dotfiles symlinked too (`gitconfig`, `vimrc`, `batrc`, `ripgreprc`, `p10k.zsh`, `p10k-intellij.zsh`). Bulk of personal aliases/keybindings: `runcoms/zshrc` (~500 added lines vs upstream), grouped by `###` section headers.
- `setup_homebrew_prezto.sh` / `setup_prezto.zsh` — one-time machine bootstrap; rarely touched.

## Fork policies & gotchas

- design rationale — decisions, rejected alternatives, accepted costs, verified
  non-problems — lives in [ADJUDICATIONS.md](ADJUDICATIONS.md), never inline.
  Its contents are settled — reviews re-flag them only with new verified facts
- repo prose is Simplified Technical English with dash-chained telegraphese.
  Dash-joined clauses count as separate sentence units, so the 25-word cap and
  the one-idea rule apply per clause, not per period. The style matches the
  author's own writing — reviews must not flag dash-chained bullets as STE
  violations
- `runcoms/zshrc` installs a `zshaddhistory` hook, `_zah-certify`. A line whose
  first word resolves to no command and to no cd target never reaches
  `.zsh_history` — it stays on ↑ for one fix-and-retry cycle, then it is gone.
  Registration runs through `add-zsh-hook`, so a second hook composes with it
  and does not replace it. Full rule set and rationale:
  [ADJUDICATIONS.md](ADJUDICATIONS.md)
- before flagging option-dependent zsh behavior (`no_clobber`, `share_history`,
  `extended_glob`, …): almost every option comes from a loaded module's
  `init.zsh` — `runcoms/zshrc` `### ZSH Options` adds only `globdots`.
  Authoritative dump: `zsh -ic 'print; setopt kshoptionprint; setopt'` — it
  prints one `name on|off` line per option. Two traps there. Some options print
  their negated name, so `no_clobber` shows up as `noclobber on`, never
  `clobber off`. And `monitor` reads `off` because that shell cannot set it —
  a real tty shell has it on. Bare `setopt` lists only the options
  that differ from the zsh default, so it never answers "is `nullglob` off?".
  The leading `print` keeps OSC bytes off the first line
- never patch files under `modules/*/external/` (vendored submodules) — upstream is the only source of truth; bump the submodule instead
- keep divergence from `upstream` minimal and rebase-friendly; `zprezto-update` assumes ff-only pulls on `main`
- upstream sync is automated: `.github/pull.yml` lets pull[bot] merge `sorin-ionescu:master` into GitHub `main`; never merge/rebase upstream manually — just ff-pull what the bot produced
- vendored completions install to `$XDG_DATA_HOME/prezto-vendored-completions`, outside the repo, so a refresh never dirties the tree that `zprezto-update` stashes — keep them out
- `cm` authenticates with `ANTHROPIC_API_KEY` or the Claude Code OAuth token, and falls back to `claude -p`
- two wrapper layers cover the command names. First ~570 aliases. Then prezto's
  `gnu-utility` functions, which exec the homebrew `g*` GNU binaries — 103 names
  are live, among them `ls rm cp mv sed awk find date stat head tail wc sort
  xargs touch env`. A name gets a function only when its `g*` binary is
  installed, so `grep` stays BSD grep and `tar` stays bsdtar. `make` is prezto's
  own colorizer over `/usr/bin/make`, not a GNU wrapper.
  `\cmd` strips the alias only, so the GNU function still wins — `command cmd`
  is the sole route to the system binary. `find` carries a second alias layer,
  `noglob find`, which `\find` drops with the first. Plain `ls` is GNU
  coreutils, `sed` is GNU sed, `find` is GNU findutils, and `command ls` is BSD
  `/bin/ls`, where `--group-directories-first` fails. `whence -p rm` reports
  `/bin/rm` and lies — the function execs `grm`. Prezto aliases `gls` and `grm`
  to git commands (`git log`, `git remote --verbose`), so spell those binaries
  `command gls` and `command grm`
- in a no-tty run (sandbox, CI, pipe) plain `rm` deletes nothing yet **reports
  success**: the alias adds `-i --verbose`, `command grm` hits EOF on the
  prompt, and exits 0 with the file intact. On a tty the alias prompts and
  deletes as usual. For a delete that must not prompt, use `\rm` — it drops the
  alias and with it the `-i` guard
- `cmp` is aliased to `cm && git push` in `zshrc` — use `\cmp` or `command cmp` for the real binary
- in `runcoms/gitconfig`, the `env -u GIT_DIR` wrapper and absolute difftool paths are load-bearing (IntelliJ Settings Sync can otherwise wipe repos on cold start) — don't "simplify" them away
- style per `.editorconfig`: 2-space indent, LF, final newline, no trailing whitespace
