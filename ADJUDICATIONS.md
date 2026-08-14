# Adjudications

Design decisions with their rejected alternatives. Newest section first.

## History hooks: mark & re-add (`runcoms/zshrc`, 2026-08-14)

**Prime rule: junk > data loss.** A kept typo costs one junk entry. A lost
valid line is unrecoverable. Every rule below errs toward junk.

### Architecture

- Withhold-everything (stash/save, `f5a7be0e`) is rejected. It gave every
  line the shell-death loss window, precmd timestamps, and delayed
  `SHARE_HISTORY` visibility.
- Current shape: certify at accept time. Stash only uncertifiable lines.
  Decide those by exit status at precmd.
- The withhold return code is 1, not 2. Return 2 keeps the line internal,
  and `HIST_IGNORE_DUPS` then swallows the precmd `print -s` copy as a dup.
- The precmd check scans `pipestatus` for 127, not `$?`. `typo | wc -l`
  ends with status 0. zsh restores `pipestatus` per precmd hook (verified).

### Certification rules

- Only plain first words (alnum, `/ _ . + ~ -`) are certified. `whence`
  sees `$var`, quotes, and operators literally and gives no verdict. Such
  lines are kept.
- `${(Q)}` unquotes the words first. Quote removal evaluates nothing, so
  `$(…)` cannot execute. `\cmp` certifies as `cmp`. `\typo` and `"typo"`
  drop.
- Pure assignments are always kept. `BAR=$(exit 127)` is a valid line with
  status 127. Withholding lost it.
- Array assignments are always kept. `(z)` splits `FOO=(a b) cmd` into
  fragments, so the hook would certify the wrong word.
- Tilde words certify via `-x ${~word}`. Tilde expansion is deterministic
  and evaluates nothing. `-d` alone missed `~/bin/tool`, and a real 127
  then dropped the valid line. Blanket keep let `~/nodir` junk in. The
  x-bit covers executables and cd-able dirs.
- `-x` vouches only for pathed words (`*/*`). A bare x-bit name (`test.sh`
  without `./`) never execs from the cwd, so it is a typo by construction.
  `-d` still covers bare auto_cd dirs.
- `$var` first words stay blanket-kept. `${(e)}` executes embedded `$(…)`:
  unsafe, rejected. `${(P)NAME}` is safe but covers only the bare `$NAME`
  shape, and the value can be multi-word. Rejected as YAGNI. The miss
  direction is junk, which is safe.

### Verified non-problems

- Non-executable pathed files need no rule. `/path/data.txt` runs into
  126, not 127. Even a withheld line self-heals at precmd.
- Relative pathed words stay consistent. Certification runs at accept time
  in the execution cwd. A recall in another cwd certifies and runs under
  that same new cwd.
- Earlier precmd hooks do not corrupt the check. zsh restores `$?` and
  `pipestatus` for each hook.
- `print -sr` does not re-enter the zshaddhistory hooks. No recursion.

### Accepted costs

- `typo &` and `typo; true` re-add. The parent status hides the 127.
- A withheld typo that ends the shell (exec, terminal death) is lost.
  Only typos take this path.
- Re-added lines carry precmd timestamps and zero duration under
  `EXTENDED_HISTORY`.

### Open

- Ctrl-C (status 130) during the slow Homebrew command-not-found handler
  re-adds the typo. Plausible, unverified.
