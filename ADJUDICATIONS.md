# Adjudications

Design decisions with their rejected alternatives. Newest section first.

## History hook: certify & reject, first word only (`runcoms/zshrc`, 2026-08-18)

**Prime rule: linger only > junk > real data loss — wrong lines only.**
The ladder ranks outcomes for typos, parse errors, and abandoned drafts.
A correct line has exactly one acceptable outcome: permanent persistence
in the histfile. Anything less breaks zsh's history function itself, so
certification exists to keep correct lines off the ladder entirely.
Real loss means not saved and not lingering — no recall path at all.
Every rule below errs up the ladder.

### Architecture

- One hook, one judged position: the first word at accept time. The
  line start is a command position by grammar definition. A certified
  line saves natively. An uncertified line rejects with return 1.
- Every rejected line lingers as the newest ring entry until the next
  line is read (verified). ↑ reaches it for one cycle — the
  fix-and-retry window. Rejection is never instant loss.
- The reject code is 1, not 2. Return 2 pins the line on the internal
  list for the whole session and never writes the file (verified). A
  rejected typo would stay a substring-search hit all session, with no
  removal primitive.
- A certified first word keeps the line under every exit status. A
  later 127 comes from a child or from the command's own semantics.
- We reject judging further `(z)` token positions (pipe-stage heads,
  separator heads). `(z)` yields lexemes without grammar. Case
  alternation and heredoc bodies emit bare `|` tokens (verified).
  Embedded newlines become `;` tokens (verified). A code review
  confirmed seven false rejects of correct lines: heredocs, `[[ … ]]`,
  case patterns, funcdef shapes, define-then-use, post-`cd` relative
  paths, `cdable_vars`. Each construct needs its own guard. The
  construct set is open-ended. Every miss is a lost correct line — the
  forbidden tier. Judging token positions is parsing without a parser.
- We reject the judge machinery (mark & re-add). It withheld
  first-word-uncertified lines. It judged them at precmd by
  `pipestatus` (127/130/146) plus a preexec ran-flag. It is the most
  grammar-correct native option: execution is zsh's own parser, so
  none of the seven false rejects can exist under it. It also
  self-heals certification gaps by outcome — it persisted
  `cdable_vars` lines and pre-chmod `./script.sh` (126) without
  special rules. We reject it for its temporal tail, not its verdicts.
  A withheld line dies with the shell (`exec`, crash) before precmd.
  SIGINT during an earlier precmd hook misjudges one line. Re-adds
  carry precmd timestamps. No fix exists inside the hook for any of
  the three.
- We reject withhold-everything (stash/save). Every line gets the
  shell-death window and precmd timestamps. `SHARE_HISTORY` visibility
  lags one cycle. Prior art exists (scarff.id.au, 2019) with a
  `$? == 0` gate. A status-0 gate also drops failing correct lines,
  e.g. `grep` without a match.
- We reject in-place histfile scrubbing. It re-implemented zsh-private
  internals: metafication bytes 0x83-0xa2, the `EXTENDED_HISTORY`
  layout, multiline backslash encoding. It needed `zsystem flock` and
  still lost. `fc -W` resurrected the typo. `SHARE_HISTORY` peers
  imported it first.
- We reject the `zsh-syntax-highlighting` parser as a grammar source.
  It exposes no API. Its `region_highlight` styles need
  theme-dependent decoding. Its tracker shows `unknown-token` false
  positives.
- Escalation path, out of scope now: recall-side filtering
  (`zsh-histdb`, `atuin`). Both record each line's exit status in
  sqlite and hide failures at recall. Write-time false rejects cannot
  exist there. Adopt one if junk from non-first typos ever hurts.

### Certification rules

- The hook judges only a plain first word (alnum, `/ _ . + ~ = -`).
  `whence` sees `$var`, quotes, and operators literally and gives no
  verdict. Such shapes certify — an uncertified correct line would
  fall to the linger and die after one command.
- `${(Q)}` unquotes the judged word. Quote removal evaluates nothing,
  so `$(…)` cannot execute. `\cmp` certifies as `cmp`. `\typo` and
  `"typo"` reject.
- A function definition certifies by any bare `()` token (`(Ie)` exact
  index). The name resolves only after the definition runs. A
  `words[2]`-only check missed multi-name definitions
  (`foo bar() { … }`) and judged the first name — a false reject
  (review finding). A bare unquoted `()` has no other zsh meaning, and
  a quoted `"()"` argument does not match.
- The hook always certifies pure assignments. The strip pattern
  anchors a full identifier and includes `+=`. The loose
  `[A-Za-z_]*=*` stripped `LC-ALL=C` and hid the typo behind it.
- A stripped `PATH=`/`path=` prefix stops certification. The line
  resolves against a PATH the hook cannot see. The line certifies.
- `=` is in the certifiable set. A `=`-word that survives the
  assignment strip is malformed — zsh execs it as a command, so
  `whence` gives a true verdict: `LC-ALL=C true` rejects. A
  leading-`=` word (`=grep`, alias bypass) certifies via `-x ${~word}`.
  Equals-expansion evaluates nothing.
- The hook sets `nonomatch` locally. A typo named dir (`~porj/src`)
  makes `${~word}` abort the hook. The abort also rejects, but with a
  hook error on stderr. `nonomatch` keeps the reject silent.
- A tilde or pathed word certifies via `-x ${~word}`. Tilde expansion
  is deterministic and evaluates nothing. `-d` alone missed
  `~/bin/tool`. We reject `-e`: it rescues `./script.sh` before its
  `chmod +x`, but it also persists every existing non-executable file
  typed as a command. The rescue costs one retype after the chmod.
  The junk class is broader than the rescue.
- `-x` vouches only for equals-words and pathed words (`=*`, `*/*`).
  A bare x-bit name (`test.sh` without `./`) never execs from the
  cwd. It is a typo by construction. `-d` still covers bare auto_cd
  dirs.
- A bare identifier certifies when its parameter value is a directory
  (`-d ${(P)w}`). The live config sets `CDABLE_VARS`, so bare `proj`
  cds to `$proj`. The arm also certifies relative-valued parameters
  that `cd` refuses. That miss is junk-direction and acceptable.
- `$var` first words stay blanket-certified. `${(e)}` executes
  embedded `$(…)`: unsafe, we reject it. Resolving via `${(P)NAME}`
  covers only the bare `$NAME` shape, and the value can be multi-word.
  We reject it as YAGNI. The miss direction is junk, which is
  acceptable.

### Verified non-problems

- Relative pathed first words stay consistent. Certification runs at
  accept time in the execution cwd. A later recall certifies and runs
  under the same new cwd. Only non-first positions broke this
  (`cd proj && ./build.sh`), and the hook no longer judges them.
- Multiline constructs certify by their reserved first word — `whence`
  gives a verdict on `for`, `while`, `if` (verified). Bodies are
  never judged, so native multiline handling stays intact.
- `NO_CLOBBER` exempts `/dev/null` (a device). Plain `>` suffices in
  the hook (verified against this repo's `unsetopt CLOBBER`).

### Accepted costs

- A rejected wrong line survives one ↑ cycle, then it is gone — next
  command or shell exit. Native zsh would persist parse errors and
  drafts. Uncertified means near-certain junk, so the short window
  costs nothing real.
- A compound line behind a typo head (`typo || fallback`, `typo; work`)
  rejects whole. The executed tail work is not persisted.
- A typo after the first word persists: `echo hi | grpe x`,
  `cd /tmp && gti status`, `sudo typo`. Junk, accepted. The
  escalation path above convicts such lines at recall instead.
- A pathed file without x-bit (`./script.sh` before `chmod +x`)
  rejects into the linger. After the chmod, the line needs a retype.
