# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Personal fork of [sorin-ionescu/prezto](https://github.com/sorin-ionescu/prezto) (zsh config framework). Remote `origin` = lecodeski/prezto, `upstream` = sorin-ionescu/prezto. Default branch: `main`.

**This repo is the live shell config of this machine.** Files in `runcoms/` are symlinked into `$HOME` as dotfiles (via `setup_links_runcoms.zsh`, which links every `runcoms/` file except README.md — a new file there needs a re-run to go live). Edits take effect in every new shell immediately. **Broken syntax breaks shell startup** — always syntax-check.

## Commands

No build or test suite. Instead:

- syntax-check a zsh file: `zsh -n <file>`
- verify a change: fresh shell — `zsh -ic 'exit'` catches startup errors
- no-tty runs of `zsh -ic 'exit'` (sandboxes, CI, pipes) print benign noise:
  `can't change option: monitor`/`zle`, a gitstatus init failure, `gstty` device
  errors — only other output indicates a real startup error
- test interactive behavior by piping lines: `print -rl '<lines>' | ZDOTDIR=<scratch> zsh -i`
  — always `-rl`: plain `print -l` interprets escapes, and a `\c` in a test line
  silently truncates the whole feed
- give every test shell an isolated `ZDOTDIR` with its own `HISTFILE` — this repo
  is the live config, a stray test writes into the real history
- Claude's shell inherits the live config's options — authoritative dump:
  `zsh -ic 'setopt'`. Example: `unsetopt CLOBBER` makes `>` to an existing file
  fail with `file exists` — use `>|` in test commands
- a fed line that reads stdin (`cat`, `read`) can swallow the rest of the feed —
  redirect its stdin or put it last
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
- before flagging option-dependent zsh behavior (`no_clobber`, `share_history`,
  `extended_glob`, …): the effective options live in each loaded module's
  `init.zsh` plus `runcoms/zshrc` `### ZSH Options` — authoritative dump:
  `zsh -ic 'setopt'`
- never patch files under `modules/*/external/` (vendored submodules) — upstream is the only source of truth; bump the submodule instead
- keep divergence from `upstream` minimal and rebase-friendly; `zprezto-update` assumes ff-only pulls on `main`
- upstream sync is automated: `.github/pull.yml` lets pull[bot] merge `sorin-ionescu:master` into GitHub `main`; never merge/rebase upstream manually — just ff-pull what the bot produced
- vendored completions install to `$XDG_DATA_HOME/prezto-vendored-completions`, outside the repo, so a refresh never dirties the tree that `zprezto-update` stashes — keep them out
- `cm` authenticates with `ANTHROPIC_API_KEY` or the Claude Code OAuth token, and falls back to `claude -p`
- `cmp` is aliased to `cm && git push` in `zshrc` — use `\cmp` or `command cmp` for the real binary
- in `runcoms/gitconfig`, the `env -u GIT_DIR` wrapper and absolute difftool paths are load-bearing (IntelliJ Settings Sync can otherwise wipe repos on cold start) — don't "simplify" them away
- style per `.editorconfig`: 2-space indent, LF, final newline, no trailing whitespace
