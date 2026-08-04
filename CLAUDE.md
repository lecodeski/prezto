# CLAUDE.md

## What this is

Personal fork of [sorin-ionescu/prezto](https://github.com/sorin-ionescu/prezto) (zsh config framework). Remote `origin` = lecodeski/prezto, `upstream` = sorin-ionescu/prezto. Default branch: `main`.

**This repo is the live shell config of this machine.** Files in `runcoms/` are symlinked into `$HOME` as dotfiles (via `setup_links_runcoms.zsh`, which links every `runcoms/` file except README.md — a new file there needs a re-run to go live). Edits take effect in every new shell immediately. **Broken syntax breaks shell startup** — always syntax-check.

## Commands

No build or test suite. Instead:

- syntax-check a zsh file: `zsh -n <file>`
- verify a change: fresh shell — `zsh -ic 'exit'` catches startup errors
- update fork + submodules: `zprezto-update` — fork-custom, defined in
  `init.zsh`; semantics in [README](README.md#updating)
- submodules after checkout: `git submodule update --init --recursive`

## Commit convention

`<type>: <message with `backticked` names>` — types: `add`, `mod`, `del`, `fix`, `refac`, `bump`. Exactly one trailing emoji, varied across commits. The `cm` script (`modules/utility/bin/cm`) generates these via Haiku API.

## Architecture

Load order: `runcoms/zshenv` → `zprofile` → `zshrc` (sources `init.zsh`) → `zlogin`.

- `init.zsh` — loader. Reads `zstyle ':prezto:load' pmodule` from `runcoms/zpreztorc` and sources each `modules/<name>/init.zsh` **in listed order** (order matters: `syntax-highlighting` before `history-substring-search`, `completion` before `autosuggestions`, `prompt` late). Also defines the fork's `zprezto-update` + `zprezto-restart`.
- `modules/<name>/` — `init.zsh` plus optional `functions/` (autoloaded) and `external/` (git submodules of third-party plugins). Fork additions: `fzf` module (fzf-tab, fzf-git), `vendored-completions` module, `utility/bin/` (`cm`, `cpy`, `pst` — on PATH).
- `runcoms/` — zsh startup files plus non-zsh dotfiles symlinked too (`gitconfig`, `vimrc`, `batrc`, `ripgreprc`, `p10k.zsh`, `p10k-intellij.zsh`). Bulk of personal aliases/keybindings: `runcoms/zshrc` (~500 added lines vs upstream).
- `setup_homebrew_prezto.sh` / `setup_prezto.zsh` — one-time machine bootstrap; rarely touched.

## Fork policies & gotchas

- never patch files under `modules/*/external/` (vendored submodules) — upstream is the only source of truth; bump the submodule instead
- keep divergence from `upstream` minimal and rebase-friendly; `zprezto-update` assumes ff-only pulls on `main`
- upstream sync is automated: `.github/pull.yml` lets pull[bot] merge `sorin-ionescu:master` into GitHub `main`; never merge/rebase upstream manually — just ff-pull what the bot produced
- `cmp` is aliased to `cm && git push` in `zshrc` — use `\cmp` or `command cmp` for the real binary
- in `runcoms/gitconfig`, the `env -u GIT_DIR` wrapper and absolute difftool paths are load-bearing (IntelliJ Settings Sync can otherwise wipe repos on cold start) — don't "simplify" them away
