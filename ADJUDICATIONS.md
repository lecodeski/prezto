# Adjudications

Settled review verdicts — trade-offs, rejected findings, verified non-problems.
A review re-flags an entry only with a new verified fact. Each entry: verdict —
reason — evidence.

## fzf-tab command preview (`modules/fzf/init.zsh`, `modules/fzf/command-preview.zsh`)

### Mechanism

- **Snapshot through `zstyle -e`, not a static preview string** — required.
  fzf-tab runs the preview as `SHELL=$ZSH_NAME` → a bare `zsh -c`
  (`lib/-ftb-fzf:81`) that reads no `zshrc` — no aliases, no functions, no
  unexported parameters. `-e` re-evaluates per completion, so aliases from
  `zshrc`, defined after the module loads, are in the snapshot too
- **Functions and parameters go through files, not inline** — required. All
  function bodies are about 1.1 MB, `ARG_MAX` is 1 MB (`getconf`, 2026-10-22)
- **Preview logic in a sourced file, `command-preview.zsh`** — chosen by the
  user. The inline string needed two levels of `\` escaping. `typeset -p`
  writes the snapshots and does the quoting — one `\$realpath` stays, because
  `_fzf_path_preview` exists only in the main shell
- **`case $group`, not probing the name in a fixed order** — chosen (review 1).
  Probing let a parameter hide a command (`manpath`), and builtins got no
  preview. Groups come from `format '[%d]'`: `[alias]`, `[regular alias]` (in
  `alias`/`unalias`), `[shell function]`, `[parameter]`, `[external command]`,
  `[builtin command]` — every other group returns 1 and falls to the path
  preview
- **Each branch loads only its own snapshot** — chosen. A command preview
  costs about 7 ms instead of about 40 ms. Sourcing the function snapshot
  costs about 18 ms, in the function branch only
- **Command style defined before the generic path preview** — required. Both
  patterns have equal `zstyle` weight, and the first defined wins (verified
  2026-11-02). A one-line comment at the style guards the order

### Snapshot files

- **Files in fzf-tab's `$tmp_dir`** — accepted, decided by the user.
  `$tmp_dir` is an undocumented local of `-ftb-fzf`, but fzf-tab deletes
  `$tmp_dir/*.$$` after each run (`lib/-ftb-fzf:104`). Outside it, about
  1.3 MB per shell stayed for good — secrets included. The submodule is
  pinned, a bump is deliberate, and the whole module depends on fzf-tab
- **Full snapshot on every command-position Tab (about 1 MB)** — accepted,
  decided by the user. Writing takes about 7 ms. Filtering to the candidates
  through `_ftb_compcap` saves a few ms for a deeper internal dependency
- **`ftb-tmux-popup` declares `tmp_dir` in another scope** — non-problem. Not
  in use here
- **Files stay when `-ftb-fzf` returns before its `rm` (`debug-command`)** —
  accepted, not verified (review 2). Debug path only

### Content per group

- **Alias as `name='value'` via `${(q-)…}`** — chosen. The format `alias`
  itself prints
- **Autoload stub: first `fpath` hit, `--language=zsh`** — required (review 2).
  `(N[1])` after `${^p}` applies per element and showed every shadowed copy.
  Stub files have no extension and no shebang, so `bat` needs the language
- **Stub path from `$functions_source`** — rejected. Empty for Prezto stubs
  such as `pfs` (verified 2026-10-27)
- **Parameter line found by a zsh pattern with `${(b)word}`, not `grep -E`** —
  required (review 1). The ERE broke on `[`, `g++`, and `.`. The pattern also
  matches tied pairs — `PATH` and `path` both find `typeset -T PATH path=(…)`
- **`-parameter-` context through the same style** — required (review 2). The
  old `${(P@)word}` style ran in the bare preview shell and saw exported
  variables only. `echo`/`print` arguments fall to the path preview
- **Fake parameters show `unset — offered by _x`** — asked for by the user.
  `compinit` turns every `#compdef -value-,NAME,-default-` into
  `fake-parameters` for `-command-` and `export`, so names like `ANT_ARGS`
  appear unset. Lookup by pattern `-value-,NAME,*` because upstream keys
  `MPD_HOST` as `-default` without the trailing dash. No `_comps` key holds a
  pattern (verified 2026-10-27). No match → plain `unset`
- **Locals of zle, completion, or fzf-tab shadow globals in the dump** —
  accepted limit, marked. `typeset -p` runs inside the completion call stack.
  Detection is generic — `-local` in `$parameters`, no hard-coded names,
  chosen by the user. The list is taken before the style declares its own
  locals. The session value behind a local is unreachable in zsh
- **ZLE and completion specials get the local marker** — expected, not
  verified. `zshzle(1)`: they "have local scope, like parameters created in a
  function using `local`". The `zpty` probe failed — no pty in the sandbox, no
  completion outside it. Check `BUF<Tab>` in the real menu
- **`*` and `@` show `unset`** — accepted. `typeset -p` prints no line for
  them
- **`hideval` parameters (`mapfile`, `functions`, `commands`) show the type
  only** — non-problem, wanted. A value of `mapfile` reads every file in the
  directory
- **Secret values on screen in the preview** — accepted, decided by the user
- **Commands and builtins: `tldr`, then `batman`** — chosen. A missing `tldr`
  or page falls through — `2>/dev/null` also swallows `command not found`
  (verified). Missing macOS pages in the `tlrc` cache need `tldr --update`
- **`OPT_COLOR=true batman`** — chosen by the user over
  `man | col -bx | bat -l man`. `batman` forwards only `--paging`/`--wrap` to
  its MANPAGER child, which then sees no tty and drops color —
  `--color=always` has no effect (verified). Fix pending upstream:
  eth-p/bat-extras#127, open since 2024-09. Drop the variable once it lands
- **No preview for `[reserved word]`, `[global alias]`, `[suffix alias]`** —
  YAGNI. No source for reserved words, and no global or suffix alias is
  defined here (verified 2026-10-27)

## `TMPPREFIX` (`runcoms/zshenv`)

- **`TMPPREFIX=${${TMPDIR:-${XDG_RUNTIME_DIR:-/tmp}}%/}/zsh`** — chosen. The
  zsh default `/tmp/zsh` put fzf-tab's directory at mode `0755` and its files
  at `0644` under umask `022` — readable by every local user, name predictable
- **zsh's own temp files** — non-problem. `=(…)` gets `0600`, a heredoc
  `0400` (verified 2026-10-27). Only fzf-tab's files were exposed
- **In `zshenv`, not `zprofile`** — chosen. `zprofile` misses shells with
  `SHLVL` > 1 whose parent lacks the value, and the fork's own exports live in
  `zshenv`
- **No `export`, no guard** — chosen (review 1). Every zsh reads `zshenv`. The
  final `/tmp` equals zsh's default
- **`$XDG_RUNTIME_DIR` fallback** — chosen by the user. Private on Linux,
  where `$TMPDIR` is mostly unset
- **Heredocs fail once systemd removes `/run/user/<uid>` under a running
  shell** — non-problem per the docs, not verified on Linux.
  `pam_systemd(8)`: removed "on the user's final logout".
  `KillUserProcesses=yes` (upstream default) kills the shell with the session.
  With `no` (Debian, Ubuntu), the abandoned scope keeps the session "closing"
  while processes remain, so the directory stays
- **Shared `/tmp` when neither variable is set (SSH without `pam_systemd`,
  containers)** — accepted. fzf-tab deletes the files after each run, and most
  distros set `fs.protected_symlinks=1`
- **Private fallback `/tmp/zsh-$UID` with `mkdir -m 700`** — rejected. A
  directory check in every shell, and the name is just as predictable
- **Umask stays `022`** — decided. `027` does not help — every normal user is
  in `staff`. `077` breaks Homebrew files, service UIDs, and Docker bind
  mounts. Secrets belong in `0700` directories instead

## Bootstrap packages (`setup_Brewfile`)

- **`tlrc` on every OS** — chosen. First choice of the command preview
- **`man-db` on Linux only (`if OS.linux?`)** — chosen. On macOS it installs
  as `gman`, and nothing uses it — `gnu-utility` wraps no `man`. Minimal
  images may lack `man` and the pages — the preview then stays empty
- **`bat`, not `batcat`** — non-problem. Homebrew installs `bat` on Linux too

## Completion users (`modules/completion/init.zsh`)

- **`c s<Tab>` offered `sparec_application` in `[user]`** — explained.
  `CDABLE_VARS` (`modules/directory`) lets `_cd` add `_tilde` for a non-empty
  prefix (`_cd:84`). Prezto ignores `'_*'` users, but this service account
  (home `/var/empty`) has no underscore
- **`${(k)userdirs[(R)/var/empty]}` appended to Prezto's ignored-patterns
  line** — chosen. No hard-coded name, and a one-line change in an upstream
  file beats a re-read-and-reset override in `zshrc`. Rejected: one fixed name
  (misses the next account), `CDABLE_VARS` off (drops `cd VARNAME`, diverges
  from upstream)
