# Adjudications

Design decisions with their rejected alternatives. Newest section first.

## History hook: certify & reject (`runcoms/zshrc`, 2026-08-16)

**Prime rule: linger only > junk > real data loss — wrong lines only.**
The ladder ranks outcomes for typos, parse errors, and abandoned drafts.
A correct line has exactly one acceptable outcome: permanent persistence
in the histfile. Anything less breaks zsh's history function itself, so
certification exists to keep correct lines off the ladder entirely.
Real loss means not saved and not lingering — no recall path at all.
Every rule below errs up the ladder.

### Architecture

- One hook, one moment: `zshaddhistory` certifies every command head at
  accept time — the first word plus the word after each `|`, `|&`, `;`,
  `&&`, `||`, `&`, `&!`, `&|`. A certified line saves natively. An
  uncertified head rejects the line with return 1. `echo hi | grpe x`
  and `cd /tmp && gti status` reject. The env-prefix strip runs per
  head (`… | LC_ALL=C sort`).
- No precommand table is needed for separator heads: `whence` certifies
  every reserved word that can follow a separator (`do`, `done`,
  `then`, `else`, `elif`, `fi`, `esac`, `repeat`, `until`, `select`,
  `foreach`, `end` — verified). `in` never follows a separator, and
  `((` fails the charset check and skips.
- `(z)` yields `;` tokens for embedded newlines (verified), so the
  bodies of multiline constructs get judged too.
- Every rejected line lingers as the newest ring entry until the next
  line is read (verified). ↑ reaches it for one cycle — the
  fix-and-retry window. Rejection is never instant loss.
- The reject code is 1, not 2. Return 2 pins the line on the internal
  list for the whole session and never writes the file (verified). A
  rejected typo would stay a ring entry — and a substring-search hit —
  all session, with no removal primitive.
- Certified heads keep the line under every exit status. A later 127
  comes from a child or from the command's own semantics. The line
  itself is correct user input.
- We reject the judge machinery (mark & re-add, `d1f4e292`..the state
  before this section): withhold uncertified lines, judge them at
  precmd by `pipestatus` (127/130/146) plus a preexec ran-flag, re-add
  survivors with `print -s`. It predates the linger discovery —
  rejection looked like instant loss, so every uncertain shape needed a
  rescue path. Its whole net effect over certify & reject: it persisted
  withheld lines that ran clean (`typo; true`, `typo || fallback`) —
  junk tier where linger was available. It paid with three hooks of
  state, a shell-death loss window, precmd timestamps on re-adds, a
  SIGINT-precmd misjudge window, and the 127/130/146 forensics (^C
  during not-found advice, trap frames).
- We reject withhold-everything (stash/save, `f5a7be0e`). It gave every
  line the shell-death loss window and precmd timestamps. It delayed
  `SHARE_HISTORY` visibility.
- We reject in-place histfile scrubbing (`d1f4e292`..`1538dd18`). It
  re-implemented zsh-private internals: metafication bytes 0x83-0xa2,
  the `EXTENDED_HISTORY` line layout, multiline backslash encoding. It
  needed `zsystem flock` and still lost: `fc -W` resurrected the typo,
  `SHARE_HISTORY` peers imported it first, and `HIST_IGNORE_DUPS`
  false-alarmed the tail check on every repeated typo.

### Certification rules

- The hook judges only plain heads (alnum, `/ _ . + ~ = -`). `whence`
  sees `$var`, quotes, and operators literally and gives no verdict.
  Such heads pass — an uncertified correct line would fall to the
  linger and die after one command.
- `${(Q)}` unquotes each judged head. Quote removal evaluates nothing,
  so `$(…)` cannot execute. `\cmp` certifies as `cmp`. `\typo` and
  `"typo"` reject. Stage detection runs on raw `(z)` tokens — unquoting
  first would turn the argument `"|"` (`grep "|" file`) into a stage
  boundary and judge `file` as a head, a false reject.
- A function definition certifies by its second `(z)` token `()`. The
  name resolves only after the definition runs, so `whence` has no
  verdict at accept time.
- The hook always certifies pure assignments. The strip pattern anchors
  a full identifier and includes `+=`. The loose `[A-Za-z_]*=*`
  stripped `LC-ALL=C` and hid the typo behind it.
- A stripped `PATH=`/`path=` prefix stops certification. The line
  resolves against a PATH the hook cannot see. The line certifies.
- `=` is in the certifiable set. A `=`-word that survives the
  assignment strip is malformed — zsh execs it as a command, so
  `whence` gives a true verdict: `LC-ALL=C true` rejects. A leading-`=`
  word (`=grep`, alias bypass) certifies via `-x ${~word}`.
  Equals-expansion evaluates nothing.
- The hook sets `nonomatch` locally. A typo named dir (`~porj/src`)
  makes `${~word}` abort the hook. The abort also rejects, but with a
  hook error on stderr. `nonomatch` keeps the reject silent.
- A tilde or pathed word certifies via `-x ${~word}`. Tilde expansion
  is deterministic and evaluates nothing. `-d` alone missed
  `~/bin/tool`. We reject `-e`: it rescues `./script.sh` before its
  `chmod +x`, but it also persists every existing non-executable file
  typed as a command (`/path/data.txt`, 126). The rescue costs one
  retype after the chmod. The junk class is broader than the rescue.
- `-x` vouches only for equals-words and pathed words (`=*`, `*/*`). A
  bare x-bit name (`test.sh` without `./`) never execs from the cwd.
  It is a typo by construction. `-d` still covers bare auto_cd dirs.
- The mark & re-add era kept uncertified `~name`/`=cmd` words to guard
  them against stale-status conviction. No conviction exists anymore —
  such words reject into the linger, the right tier for junk.
- `$var` first words stay blanket-certified. `${(e)}` executes embedded
  `$(…)`: unsafe, we reject it. `${(P)NAME}` is safe but covers only
  the bare `$NAME` shape. The value can be multi-word. We reject it as
  YAGNI. The miss direction is junk, which is acceptable.

### Verified non-problems

- Relative pathed words stay consistent. Certification runs at accept
  time in the execution cwd. A later recall certifies and runs under
  the same new cwd.
- Multiline constructs certify by their reserved first word — `whence`
  gives a verdict on `for`, `while`, `if` (verified) — and keep zsh's
  native multiline history handling.
- `NO_CLOBBER` exempts `/dev/null` (a device). Plain `>` suffices in
  the hook (verified against this repo's `unsetopt CLOBBER`).

### Accepted costs

- A rejected wrong line survives one ↑ cycle, then it is gone — next
  command or shell exit. Native zsh would persist parse errors and
  drafts. Uncertified means near-certain junk, so the short window
  costs nothing real.
- A compound line behind a typo head (`typo || fallback`, `typo; work`)
  rejects whole. The executed tail work is not persisted.
- A typo chained behind a certified head (`sudo typo`, `time typo`,
  `then qwerty`) persists. Only the first word of each command position
  gets judged. Junk, accepted.
