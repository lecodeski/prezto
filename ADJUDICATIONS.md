# Adjudications

Design decisions with their rejected alternatives. Newest section first.

## History hooks: mark & re-add (`runcoms/zshrc`, 2026-08-14)

**Prime rule: junk > data loss.** A kept typo costs one junk entry. A lost
valid line is unrecoverable. Every rule below errs toward junk.

### Architecture

- We reject withhold-everything (stash/save, `f5a7be0e`). It gave every
  line the shell-death loss window. It stamped every line with precmd
  time. It delayed `SHARE_HISTORY` visibility.
- We reject in-place histfile scrubbing (`_history-scrub`,
  `d1f4e292`..`1538dd18`). It preserved native timestamps and multiline
  entries. But it re-implemented zsh-private internals: metafication
  bytes 0x83-0xa2, the `EXTENDED_HISTORY` line layout, multiline
  backslash encoding. It needed `zsystem flock` and still lost. The typo
  stayed on the internal list. `fc -W` resurrected it, and
  `SHARE_HISTORY` peers imported it before the scrub. `HIST_IGNORE_DUPS`
  also false-alarmed the tail check on every repeated typo.
- Current shape: certify at accept time. Stash only uncertifiable lines.
  Judge those at precmd. Deferring only the marked lines keeps native
  handling for ~100% of entries.
- A certified first word keeps the line under every exit status. A later
  127 comes from a child or from the command's own semantics. The line
  itself is valid user input.
- The withhold return code is 1, not 2. Return 2 keeps the line internal.
  `HIST_IGNORE_DUPS` then swallows the precmd `print -s` copy as a dup.
- The precmd check scans `pipestatus` for 127, 130, or 146 — not `$?`.
  `typo | wc -l` ends with status 0. zsh restores `pipestatus` per precmd
  hook (verified).
- A `preexec` flag marks real execution. A withheld line without the flag
  never ran: parse error, abandoned PS2 draft. The hook re-adds it, so it
  stays recallable like in native zsh. A stale status from an earlier
  command must not judge it (verified in both directions).
- 130/146 on an executed withheld line means ^C/^Z during the not-found
  advice. Certification proves the word does not resolve, so only the
  advice can be running. The Homebrew handler only prints advice and
  always returns 127. The rule makes ^C match the wait-it-out outcome:
  both drop. A typo ^C and an availability probe are the same bytes.
  Intent is not detectable. Probe with `command -v x` instead — that line
  certifies and stays.
- We reject wrapping `command_not_found_handler` with
  `trap 'return 127' INT`. The trap converts the status only when trap
  and child share a frame (verified). The Homebrew handler nests two
  frames deep. The interrupt unwinds the outer frames to 130 anyway.

### Certification rules

- The hook certifies only plain first words (alnum, `/ _ . + ~ = -`).
  `whence` sees `$var`, quotes, and operators literally and gives no
  verdict. The hook keeps such lines.
- `${(Q)}` unquotes the words first. Quote removal evaluates nothing, so
  `$(…)` cannot execute. `\cmp` certifies as `cmp`. `\typo` and `"typo"`
  drop.
- A function definition certifies by its second `(z)` token `()`. A
  funcdef runs without an update to `pipestatus`, so a stale 127 judged
  it (verified loss). A define-and-call compound (`f() { … }; f`)
  genuinely runs, and its own 127/130 judged it. Both are valid user
  input and now stay.
- The hook always keeps pure assignments. `BAR=$(exit 127)` is a valid
  line with status 127. Withholding lost it. The strip pattern anchors a
  full identifier and includes `+=`. The loose `[A-Za-z_]*=*` stripped
  `LC-ALL=C` and unmarked the typo behind it.
- A stripped `PATH=`/`path=` prefix stops certification. The line
  resolves against a PATH the hook cannot see. The hook keeps the line.
- `=` is in the certifiable set. A `=`-word that survives the assignment
  strip is malformed. zsh execs it as a command, so `whence` gives a true
  verdict: `LC-ALL=C true` drops on its 127. A leading-`=` word
  (`=grep`, alias bypass like `\cmd`) certifies via `-x ${~word}`.
  Equals-expansion evaluates nothing.
- The hook sets `nonomatch` locally. A typo named dir (`~porj/src`) made
  `${~word}` abort the whole hook. The line vanished with no recall — the
  loss class the prime rule forbids.
- The hook keeps an uncertified `~name` or `=cmd` word. Such a word can
  die at expansion, before execution, and updates no status (verified:
  `$?` and `pipestatus` both stay stale). A stale bad status from an
  earlier command would then judge it.
- A tilde word certifies via `-x ${~word}`. Tilde expansion is
  deterministic and evaluates nothing. `-d` alone missed `~/bin/tool`,
  and a real 127 then dropped the valid line. The x-bit covers
  executables and cd-able dirs.
- `-x` vouches only for equals-words and pathed words (`=*`, `*/*`). A
  bare x-bit name (`test.sh` without `./`) never execs from the cwd. It
  is a typo by construction. `-d` still covers bare auto_cd dirs.
- `$var` first words stay blanket-kept. `${(e)}` executes embedded
  `$(…)`: unsafe, we reject it. `${(P)NAME}` is safe but covers only the
  bare `$NAME` shape. The value can be multi-word. We reject it as YAGNI.
  The miss direction is junk, which is safe.

### Verified non-problems

- Non-executable pathed files need no rule. `/path/data.txt` runs into
  126, not 127. The withheld path re-adds it.
- Relative pathed words stay consistent. Certification runs at accept
  time in the execution cwd. A later recall certifies and runs under the
  same new cwd.
- Earlier precmd hooks do not corrupt the check. zsh restores `$?` and
  `pipestatus` for each hook.
- `print -sr` does not re-enter the zshaddhistory hooks. No recursion.
- `NO_CLOBBER` exempts `/dev/null` (a device). Plain `>` suffices in the
  hook (verified against this repo's `unsetopt CLOBBER`).

### Accepted costs

- `typo &` and `typo; true` re-add. The parent status hides the 127.
- The shell loses a withheld typo that execs or dies with the terminal.
  Only true typos take this path.
- Re-added lines carry precmd timestamps and zero duration under
  `EXTENDED_HISTORY`.
- SIGINT during an earlier precmd hook skips `_history-save` for one
  cycle, and one line gets misjudged. The trigger needs a blocked tty
  plus an unstick ^C. No fix exists inside our hook.
- SIGINT to the bare shell pid (no process group) leaves 130 out of
  `pipestatus`, and the typo re-adds. No keyboard produces this.
