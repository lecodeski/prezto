# Adjudications

Design decisions with their rejected alternatives. Newest section first.

## Prose: dash-chained telegraphese (repo docs, 2026-08-20)

Dash-joined clauses count as separate STE sentence units. The 25-word
cap and the one-idea rule apply per clause, not per period. The style
matches the rule author's own writing. Reviews must not flag
dash-chained bullets as STE violations.

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
- Every rejected line lingers as the newest ring entry until zsh
  reads the next line (verified). ↑ reaches it for one cycle — the
  fix-and-retry window. Rejection is never instant loss.
- The reject code is 1, not 2. Return 2 pins the line on the internal
  list for the whole session and never writes the file (verified). A
  rejected typo would stay a substring-search hit all session, with no
  removal primitive.
- A certified first word keeps the line under every exit status. A
  later 127 comes from a child or from the command's own semantics.
- We reject judging further `(z)` token positions (pipe-stage heads,
  separator heads). `(z)` yields lexemes without grammar. Judging
  token positions is parsing without a parser.
  - Case alternation and heredoc bodies emit bare `|` tokens
    (verified). Embedded newlines become `;` tokens (verified).
  - A code review confirmed seven false rejects of correct lines:
    heredocs, `[[ … ]]`, case patterns, funcdef shapes,
    define-then-use, post-`cd` relative paths, `cdable_vars`.
  - Each construct needs its own guard. The construct set is
    open-ended. Every miss is a lost correct line — the forbidden
    tier.
- We reject the judge machinery (mark & re-add). It withheld
  first-word-uncertified lines. It judged them at precmd by
  `pipestatus` (127/130/146) plus a preexec ran-flag.
  - It is the most grammar-correct native option. Execution is zsh's
    own parser, so none of the seven false rejects can exist under
    it. It also self-heals certification gaps by outcome — it
    persisted `cdable_vars` lines and pre-chmod `./script.sh` (126)
    without special rules.
  - We reject it for its temporal tail, not its verdicts. A withheld
    line dies with the shell (`exec`, crash) before precmd. SIGINT
    during an earlier precmd hook misjudges one line. Re-adds carry
    precmd timestamps. No fix exists inside the hook for any of the
    three.
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
- Identifier patterns use `[[:alpha:]_][[:IDENT:]]#`. The ASCII-only
  `[A-Za-z_][A-Za-z0-9_]#` rejected the correct line `wörk=5` — `ö`
  is alnum, so the charset arm gave no rescue (review finding,
  verified).
- The strip scan iterates by value with a break flag. `shift` and
  array subscripting both cost O(n) per word in zsh. The old
  shift loop froze accept for 4.2 s on a 100KB assignment run
  (measured, review finding). The value scan takes 17 ms there
  (measured).
- The hook tokenizes with `${(Z+n+)}`: newlines count as whitespace,
  not `;` tokens (verified). Plain `(z)` emitted a stray `;` for the
  line's trailing newline, which kept the pure-assignment check dead —
  pure assignments certified via the charset arm judging `;` instead
  (review finding, verified). The flag also judges the real head of a
  pasted multiline entry (`FOO=bar\ntypo` rejects — `(z)` certified
  its `;`).
- An assignment token that ends in `=(` stops certification. `(z)`
  fragments an array assignment into `name=(` plus elements, so later
  tokens carry no judgeable head. The looser `*\(*` also matched
  scalar `$( )` values — `LOG=$(date) grpe x` certified and hid the
  typo (review finding, verified).
- Hook locals carry a `_zah_` prefix. Dynamic resolution sees every
  name in scope, and plain `words`/`w` locals shadowed same-named
  user parameters in the former `${(P)}` arm — a verified false
  reject (review finding). The prefix keeps every arm
  collision-free.
- A stripped `PATH=`/`path=` prefix stops certification. The line
  resolves against a PATH the hook cannot see. The line certifies.
- `=` is in the certifiable set. A `=`-word that survives the
  assignment strip is malformed — zsh execs it as a command, so
  `whence` gives a true verdict: `LC-ALL=C true` rejects. A
  leading-`=` word (`=grep`, alias bypass) certifies through the
  expanded `whence`. Equals-expansion evaluates nothing.
- The hook sets `nonomatch` locally. A typo named dir (`~porj/src`)
  makes `${~word}` abort the hook. The abort also rejects, but with a
  hook error on stderr. `nonomatch` keeps the reject silent. `=typo`
  likewise rejects silently (verified).
- One judge: `whence -- ${~word}`. `${~}` expands a leading `~` or `=`
  deterministically and evaluates nothing. `whence` checks the x-bit
  on pathed words and searches only PATH for bare words — a bare x-bit
  `test.sh` never certifies, a typo by construction. This merged
  away a parallel `(=*|*/*) && -x ${~word}` arm (review
  simplification, behavior-identical, verified). The cd probe covers
  dirs, which `whence` refuses.
- We reject `-e`-style existence judging: it rescues `./script.sh`
  before its `chmod +x`, but it persists every existing
  non-executable file typed as a command. The rescue costs one retype
  after the chmod. The junk class is broader than the rescue.
- Dir resolution is one subshell probe: `( builtin cd -q -- ${~word} )`.
  cd itself is the auto_cd oracle — cwd dirs, `cdable_vars` params,
  `hash -d` named dirs, user homes, `cdpath`, and the
  plain-relative-words-only cdpath rule, all exact by construction.
  No future cd feature can desynchronize the hook. `-q` suppresses
  chpwd hooks, and the subshell isolates the chdir. The fork costs
  ~1 ms, only on dir lines and the reject path.
- The probe replaced four hand-rolled arms (`-d`, prefix gate,
  `~word` retry, cdpath loop — review simplification). Their history:
  a `${(P)}` params-only arm missed `hash -d` dirs that cd correctly
  (review finding, verified). A cwd-only `-d` check missed `cdpath`
  dirs (review finding, verified). `-d` also wrongly certified no-x
  dirs that auto_cd refuses — the probe rejects them, more exact.
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
  gives a verdict on `for`, `while`, `if` (verified). The hook never
  judges bodies, so native multiline handling stays intact.
- `NO_CLOBBER` exempts `/dev/null` (a device). Plain `>` suffices in
  the hook (verified against this repo's `unsetopt CLOBBER`).
- `setopt CORRECT` needs no rule. The hook receives the corrected
  line, not the typo (review-refuted candidate, verified).
- A plain `zshaddhistory` function coexists with future
  `add-zsh-hook zshaddhistory` consumers. zsh runs the function and
  the hook array both (review-refuted candidate).
- `(z)` keeps `(( … ))`, `$(( … ))`, `$( … )`, quoted words, and
  parenthesized globs as single tokens (verified). Those constructs
  never reach the judged position. Two plausible split claims proved
  false under test — verify tokenization before building on it.
- The hook fires for parse-error lines too (verified by trace). A
  certified first word saves them, like native zsh does.
- Space-prefixed lines need no rule. `HIST_IGNORE_SPACE` applies
  natively. The hook has no `print -s` left to bypass it.
- The hook survives `setopt nounset` (verified: correct verdicts, no
  error output). The former `${(P)}` arm aborted under it on unset
  names (review finding). The cd probe resolves no parameter
  dynamically.
- Suffix aliases need no rule. `whence` resolves them natively
  (verified), so a `doc.pdf` line under `alias -s pdf=open`
  certifies.
- The arms need no option gates (`autocd`, `cdable_vars`, `cdpath`).
  An arm only ever certifies, so a stale option costs one junk entry —
  the line fails with command-not-found and persists. A gate can only
  suppress a certify, so a gate that misreads option state rejects a
  correct line — the forbidden tier. Gateless is the strictly safer
  shape, and the options are invariants of this config anyway
  (review-refuted candidate).
- The value scan needs no emptiness guard. A `for` over an empty
  array does not run. The pure-assignment default then certifies — an
  empty token list never reaches the judge.
- Short-form `for` binds the full `[[ … ]] && return 0` sublist as
  its body (verified). The `return 0` fires per matching `cdpath`
  entry, not after the loop.
- The hook writes nothing to stderr on any input class (verified:
  `-foo`, `+foo`, empty words, bad `~`-names, array-valued
  parameters). `whence --` kills usage errors. `nonomatch` kills
  expansion errors. The dropped `2>&1` hid nothing.
- An empty first word (`""`) rejects via the explicit `-n` gate. Such
  a line errors before it runs anything. Without the gate the cd
  probe certifies it — `cd ''` goes to `$HOME` (verified). The
  earlier `~`-retry and cdpath arms certified it too.
- A `CDPATH=`/`cdpath=` prefix needs no `PATH=`-style bail. A
  one-shot `CDPATH=/x dir` line does not auto_cd at all (verified),
  so judging the next word against the live `cdpath` is correct.
- `setopt localoptions extendedglob` fully covers the hook's `#`
  patterns. Pattern evaluation happens at execution, not at function
  parse (verified).
- Performance is settled: ~23µs on the certify path, ~60µs on
  reject, 17 ms for a 100KB assignment run, builtins only (measured).
  We refute caching and speed-gating proposals in advance.
- `HIST_IGNORE_ALL_DUPS` does not delete an older correct entry when
  a rejected duplicate lingers (verified).
- The surviving inline comments are deletion defenses. Each states a
  fact whose absence invites a breaking simplification. Three review
  rounds pruned the set — it is settled.

### Accepted costs

- A rejected wrong line survives one ↑ cycle. Then it is gone — next
  command or shell exit. Native zsh would persist parse errors and
  drafts. Uncertified means near-certain junk, so the short window
  costs nothing real.
- A compound line behind a typo head (`typo || fallback`, `typo; work`)
  rejects whole. The hook drops the executed tail work.
- A typo after the first word persists: `echo hi | grpe x`,
  `cd /tmp && gti status`, `sudo typo`. Junk, accepted. The
  escalation path above convicts such lines at recall instead.
- A pathed file without x-bit (`./script.sh` before `chmod +x`)
  rejects into the linger. After the chmod, the line needs a retype.
