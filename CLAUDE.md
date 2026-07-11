# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Personal fork of [sorin-ionescu/prezto](https://github.com/sorin-ionescu/prezto) (zsh config framework). Remote `origin` = lecodeski/prezto, `upstream` = sorin-ionescu/prezto. Default branch: `main`.

**This repo is the live shell config of this machine.** Files in `runcoms/` are symlinked into `$HOME` as dotfiles (via `setup_links_runcoms.zsh`, which links every `runcoms/` file except README.md — a new file there needs a re-run to go live). Edits take effect in every new shell immediately. Be careful with broken syntax — it breaks shell startup.

## Commands

No build or test suite. Instead:

- Syntax-check a zsh file: `zsh -n <file>`
- Verify a change: open a fresh shell (`zsh -ic 'exit'` catches startup errors)
- Update fork + submodules: `zprezto-update` (custom version in `init.zsh`: fetches, stashes dirty state incl. untracked, ff-pulls `main`, syncs submodules, rebases feature branch back and force-pushes it with `--force-with-lease`)
- Submodules after checkout: `git submodule update --init --recursive`

## Commit convention

`<type>: <message with `backticked` names> <emoji>` — types seen: `add`, `mod`, `fix`, `refac`, `bump`. Exactly one trailing emoji, varied across commits. The `cm` script (`modules/utility/bin/cm`) generates these via Haiku API.

## Architecture

Load order: `runcoms/zshenv` → `zprofile` → `zshrc` (sources `init.zsh`) → `zlogin`.

- `init.zsh` — loader. Reads `zstyle ':prezto:load' pmodule` from `runcoms/zpreztorc:32` and sources each `modules/<name>/init.zsh` **in listed order** (order matters, e.g. `syntax-highlighting` before `history-substring-search`, `completion` before `autosuggestions`, `prompt` late). Also defines the fork's custom `zprezto-update`.
- `modules/<name>/` — `init.zsh` plus optional `functions/` (autoloaded) and `external/` (git submodules for third-party plugins). Fork additions: `fzf` module (fzf-tab, fzf-git), `utility/bin/` (`cm`, `cpy`, `pst` — on PATH).
- `runcoms/` — zsh startup files plus non-zsh dotfiles that get symlinked too (`gitconfig`, `vimrc`, `batrc`, `ripgreprc`, `p10k.zsh`, `p10k-intellij.zsh`). Bulk of personal aliases/keybindings lives in `runcoms/zshrc` (~500 added lines vs upstream).
- `setup_homebrew_prezto.sh` / `setup_prezto.zsh` — one-time machine bootstrap; rarely touched.

## Fork policies & gotchas

- Never patch files under `modules/*/external/` (vendored submodules) — upstream is the only source of truth; bump the submodule instead.
- Keep divergence from `upstream` minimal and rebase-friendly; `zprezto-update` assumes ff-only pulls on `main`.
- Upstream sync is automated: `.github/pull.yml` makes pull[bot] merge `sorin-ionescu:master` into GitHub `main`; never merge/rebase upstream into `main` manually — just ff-pull what the bot produced.
- `cmp` is aliased to `cm && git push` in `zshrc` — use `\cmp` or `command cmp` for the real binary.
- In `runcoms/gitconfig`, the `env -u GIT_DIR` wrapper and absolute paths on difftool entries are load-bearing (IntelliJ Settings Sync can otherwise wipe repos on cold start) — don't "simplify" them away.
