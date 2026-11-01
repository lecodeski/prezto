# Adjudications

Settled review verdicts — trade-offs, rejected findings, verified non-problems.
A review re-flags an entry only with a new verified fact. Each entry: verdict —
reason — evidence.

## `cm` (`modules/utility/bin/cm`)

### Model and effort

- **OAuth path stays on `claude-haiku-4-5` without effort** — accepted. With the
  Claude Code OAuth token, the raw Messages API answers `429` for every 5.x
  model — Haiku 5.5 and Sonnet 5.5 failed on the first call, Haiku 4.5 got
  `200` at the same time (verified 2026-10-28). Haiku 4.5 rejects
  `output_config.effort`, so the OAuth path sends none
- **Second model ID on the OAuth path** — accepted cost of the `429` workaround.
  When the `429` lifts or Haiku 4.5 retires, `cm -t` shows a failed api call
  with `claude-haiku-4-5`
- **OAuth path on Haiku 5.5 with `429` → `claude -p` fallback** — rejected.
  Every commit would take the fallback — 4.7 s for a one-line diff, 15 s for a
  30-line diff, against 0.6–2.7 s on the direct path (measured 2026-10-28)
- **Different models on the OAuth path (4.5) and the `claude -p` fallback
  (5.5)** — accepted. The fallback runs only after a failed api call — same
  `429` reason as above
- **`effort=low` on Haiku 5.5** — chosen. With adaptive thinking, the model
  skips thinking on trivial diffs — most commits here change 1–6 lines — and
  thinks briefly on large ones. `medium` more than doubled output tokens in
  Anthropic's tests. `thinking: disabled` leaks reasoning-like text into the
  reply more often, which would land in the commit message. Latency on the
  API-key path is not measured yet
- **`max_tokens` 4000** — required. Haiku 5.5 thinking counts toward
  `max_tokens` — the old 400 could end the reply before any text. The value is
  a cap only and costs nothing unused

### Authentication

- **Keychain item `anthropic-api-key` ranks above the OAuth token** — chosen.
  A global `ANTHROPIC_API_KEY` export also reaches Claude Code, which can then
  bill the API instead of the subscription
- **Broken API key does not fall through to OAuth** — accepted. A revoked or
  rotated key sends `cm` to the slow `claude -p` fallback — `cm` still works.
  A second api-call chain costs more code than this rare case is worth
- **Keychain access dialog blocks `cm`** — non-problem. An item created with
  `security add-generic-password` lists `/usr/bin/security` as trusted, so the
  lookup runs without a dialog
- **Key prompt when no API key is found** — chosen. Only on a tty and with
  `security` on PATH — input hidden, Enter skips to OAuth. The key goes to
  `security -i` on stdin, never into argv, where `ps` shows it. Enter asks
  again on the next run — no skip memory until it annoys
- **Pasted key reaches the Keychain once the API accepts it** — required.
  Stored at once, a mistyped key suppressed the prompt for good and sent every
  run to the slow fallback. Python exits 3 when the API accepted the key but
  the reply is unusable — `cm` stores on every exit code but 1, so a bad
  prefix or a stopped reply does not lose a good key
- **Key not stored after a network error, timeout, 429, or 5xx** — kept. Exit
  1 means the key is unproven — storing it there brings back the mistyped key
  that stays for good. The next run asks again
- **Key prompt needs a tty on stdin and stderr** — required. With stderr
  redirected, `read -p` wrote its prompt nowhere and `cm` waited blind
- **Every fallback prints a `💥` line with its cause** — chosen by the user,
  the style of `u` in `runcoms/zshrc`. Covered: no API key → OAuth on Haiku
  4.5, no key and no OAuth token or no python 3 → `claude -p`, API call failed
  or stopped, reply without text, prefix outside `cm.type`
- **`💥` format exists in bash (`warn`) and in Python (`fall`)** — kept. Python
  writes straight to stderr — one shared helper needs a second channel from
  Python to bash, more code than the two definitions
- **No `command -v security` guard** — non-problem. Off macOS, `2>/dev/null`
  also swallows bash's `command not found`, and the value stays empty
  (verified in bash). The extra spawn per run is negligible
- **`429` quirk stays out of `CLAUDE.md`** — DRY. This file and the one-line
  `cm` comment at the OAuth override carry it — `CLAUDE.md` lists the auth
  sources only
- **`includeIf` for SSH and HTTPS remotes** — required. A `lecodeski` clone
  over `https://github.com/…` matched no `includeIf` and silently lost the
  types
- **No `includeIf` for `ssh://git@github.com/lecodeski/…`** — YAGNI. Every
  remote here uses the `git@github.com:` form — the block is two lines once
  one shows up
- **A repo with both a `lecodeski` SSH and HTTPS remote gets `cm.type` twice**
  — accepted. Both `includeIf` blocks fire, so the list doubles in the prompt —
  `valid()` still works. No single `hasconfig` glob covers both forms:
  `**github.com?lecodeski/**` and `**github.com[:/]lecodeski/**` match the SSH
  form only (tested 2026-11-01). Deduplication in `cm` and `/commit` costs a
  pipe stage for a case that does not occur here
- **Keychain account from `id -un`, not `$USER`** — required. Under `set -u`,
  an environment without `USER` aborted `cm` after a successful API call and
  lost the commit

### Response handling

- **`stop_reason` other than `end_turn` → fallback** — chosen. A truncated text
  block never gets committed
- **HTTP error shows `error.message` from the body** — required.
  `str(HTTPError)` alone read `HTTP Error 400: Bad Request` and hid the cause —
  a wrong model ID or parameter sent every run to the slow fallback unexplained
- **Reply without text → fallback with cause** — required. Haiku 5.5 can end
  a turn with its whole answer in thinking — Anthropic documents it at
  `xhigh`. Before, no text block gave `API call failed ()`, and a blank text
  block fell back without a `💥` line. The `try` now covers only the request,
  so no `sys.exit` runs inside it
- **HTTP 200 body without `stop_reason` or `content` → fallback with cause,
  exit 3** — required. A proxy page or a changed schema raised a bare
  traceback and, on exit 1, lost a just-pasted key
- **`cm -t` reports `ok`, `failed`, or `rejected`** — required. A reply that
  only failed the `cm.type` check showed as `failed`, like a network error
- **Aborts and fallbacks share `warn` and the `💥` prefix** — chosen. `u` uses
  `💥` for aborts too. The rejection text comes from one helper, `rejected`,
  with the suffix `falling back to claude -p` or `aborting`
- **Abort after `cm`'s own `git add -A` leaves the index staged** — kept,
  decided by the user
- **30 s urllib timeout with Haiku 5.5 thinking** — open. Measure with `cm -t`
  once the API key exists — raise it only on a real timeout
- **`refusal` via `claude -p` could commit refusal text** — open, not verified.
  Not new — before this change, a refusal without a text block also went to
  the fallback. Rare for commit diffs

### Commit-type prompt

- **Commit types come from `git config cm.type`, not from the history** —
  chosen. The house types live in `runcoms/gitconfig-cm`, which
  `runcoms/gitconfig` includes per remote URL (`git@github.com:lecodeski/**`).
  Config decides which taxonomy applies — Haiku only picks within it
- **Meanings appear in the prompt only when `cm.type` is set** — required.
  Measured with Haiku 4.5, a `feat:`/`chore:` history, 4 diffs × 4 runs —
  foreign `add:`/`mod:` prefixes: no meanings 0/16, meanings always on 3/16,
  meanings behind "Only if that set is …" in the prompt 2/16, meanings left
  out 0/16 (2026-10-29). Once Haiku reads the meanings, it uses them
- **Regex over the recent subjects as the taxonomy switch** — replaced by
  `cm.type`. It guessed — Commitizen's default `bump: version X → Y` subject
  switched the house taxonomy on in `feat:` repos, and 15 `fix:` subjects in a
  row locked the set to `fix`
- **`git config --local cm.type` per repo instead of `includeIf`** — rejected
  as the default. `.git/config` is not versioned — a fresh clone loses it. It
  stays available for a single foreign repo with its own types
- **Subject validated as `type(scope):` against `cm.type`** — chosen. A prefix
  outside the list or a missing scope fails like an empty reply — the api path
  falls back to `claude -p`, and a second miss stops `cm` before `git commit`.
  Without `cm.type` there is no check
- **Repos without `cm.type` get only the history** — accepted. `cm` reads no
  repo docs — Haiku infers the convention from the 15 subjects. Measured with
  Haiku 4.5, 6 diffs × 4 runs (2026-10-30): plain-subject history 0/24
  prefixes added, `feat:`/`chore:` history 0/24 foreign prefixes and the bug
  fix 4/4 as `fix`
- **Scope on every prefix** — chosen by the user, the Conventional Commits
  `type(scope):` form. Without `cm.type`, bash decides whether the history
  uses prefixes at all — a subject that starts with `word:` or `word(scope):`.
  No prefix in the window → the prompt says "Use no commit-type prefix" and
  names no scope. Unambiguous, unlike the old taxonomy regex — it asks only
  "prefix or not", never "which taxonomy"
- **One prefixed subject in the window switches on prefix mode** — kept,
  decided by the user. A tool-made `chore(release): 1.2.0` in a plain repo
  turns prefixes on, and new prefixed subjects keep it on. No majority rule
- **`!` breaking-change marker** — allowed in both the history regex and the
  `cm.type` check, so the two agree
- **`claude -p` reply trimmed of leading whitespace** — required. The api path
  strips its reply — without the trim, a leading blank line failed the anchored
  `type(scope):` check and stopped `cm`
- **Scope sentence always in the prompt** — rejected. In a plain-subject
  history it produced `Fix(fzf):` subjects 2/24. Gated as above: plain 0/24
  prefixes, `feat:` history 24/24 with scope, `cm.type` repo 24/24 valid
  `type(scope):` (Haiku 4.5, 6 diffs × 4 runs, 2026-10-31)
- **Scope makes subjects longer** — accepted. The 50-character rule stays —
  Haiku 4.5 already overshot it before the scope, e.g.
  ``add(zshrc): integrate `cargo install-update` into upgrade workflow 📦``
- **Loop-breaker is a clause of the prefix rule, not a bullet of its own** —
  chosen. A bullet that says "pick the prefix" can push a prefix into a repo
  without one. It breaks the loop where frequent `refac:` subjects make every
  new subject `refac:`
- **Prefix meanings live once — `cm.type` in `runcoms/gitconfig-cm`** —
  chosen. `cm` and `/commit` both read git config — `CLAUDE.md` only points
  there. A repo under the `includeIf` remote without its own `CLAUDE.md` still
  gets the types
- **Haiku 4.5 types the `fts` sort fix (`7b2913dc`) as `refac`** — known
  limit. The diff only adds `LC_ALL=C` — the bug is not visible in it. With
  the `feat:` history the same diff got `fix` 4/4
- **`/commit` (`~/.claude/commands/commit.md`) reads `cm.type` with one `!`
  line, no gating logic** — decided by the user. The line is data, not a
  switch — the session agent applies the rules itself. Without `cm.type`, repo
  docs define the meanings. A bash gate like the one in `cm` stays out —
  overkill for an in-session agent
- **House types also apply in a `lecodeski` fork of a foreign project** —
  kept, decided by the user. `includeIf` keys on the remote owner, not on the
  repo's convention — no per-repo opt-out
- **`valid()` checks the first line only** — required. Before, `${1%%:*}`
  could span the subject and the body — `add(cm` passed when the body held
  `):`
- **Type names not regex-escaped in `valid()`** — YAGNI. The types are plain
  words — a name like `c++` does not exist
- **Malformed `cm.type` value without `=`** — no guard. The abort message
  names the allowed prefixes, so a broken entry shows at once
- **Subject ends with exactly one emoji** — aligned with `CLAUDE.md`, in `cm`
  and `/commit`. Before, "at least one emoji" also let one lead the subject.
  Haiku 4.5, 3 histories × 6 diffs × 4 runs: 71/71 replies end with exactly
  one emoji (2026-11-01)
- **Header comment on `cm.type` and the "Auth resolution" comment in `cm`** —
  kept, decided by the user
- **Multi-line comments on the prefix regex and on `valid()`** — asked for by
  the user. They explain each regex part, `<<<`, and `%%` — an exception to the
  one-line comment rule
- **Scope with a colon (`mod(zsh:opts):`) fails `valid()`** — YAGNI. The
  prompt asks for one short word — a colon or a path is no scope
- **`cm` prompt names `type(scope)!:` and "no other" prefix** — synced with
  `/commit`, which already allowed `!` and said "No other prefix". Haiku 4.5,
  6 diffs × 4 runs (2026-11-02): no `!` in 70 replies without a breaking
  change, `cm.type` repo 24/24 valid, and `fsmonitor` off went from `del` 4/4
  to `mod` 3/4

### Measurement method

- **Build the history window from `git log $c^`, never from `HEAD`** — a
  commit inside its own window gets its old subject copied — same text, same
  emoji
