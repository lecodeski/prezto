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
- The precmd check scans `pipestatus` for 127 or 130, not `$?`. `typo | wc -l`
  ends with status 0. zsh restores `pipestatus` per precmd hook (verified).
- 130 on a withheld line means Ctrl-C during the not-found advice. The
  command itself cannot be running: certification already proved the word
  does not resolve, and the Homebrew handler only prints advice. Without
  the 130 rule, Ctrl-C on the slow advice re-added the typo (reproduced
  with a real pty via zpty). Keyboard SIGINT hits the process group, so
  130 lands in `pipestatus`.
- A typo Ctrl-C and an availability probe (run the bare name, cancel) are
  the same bytes and the same statuses. Intent is not detectable. The 130
  rule makes Ctrl-C match the wait-it-out outcome: both drop. Probe with
  `command -v x` instead — that line certifies and stays.
- Wrapping `command_not_found_handler` with `trap 'return 127' INT` is
  rejected. The trap converts the status only when trap and child share a
  function frame (verified). The Homebrew handler nests two frames deep,
  and the interrupt unwinds the outer frames to 130 anyway.
- Signaling only the shell pid (not the group) leaves 130 out of
  `pipestatus`, and the typo survives. No keyboard produces this. Accepted.

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
