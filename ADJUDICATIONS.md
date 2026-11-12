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
- **Sonnet 5.5 at `effort=medium` on the API-key path and the fallback** —
  chosen by the user. Measured via `claude -p` on 6 diffs × 3 runs, neutral
  `main` history (2026-11-12) — "feat" means the 2 true feature diffs, "small"
  the alias, setting, and removal diffs:

  | model, effort | feat | small right | large diff | small diff | cost/large | over 50 chars |
  |---|---|---|---|---|---|---|
  | Haiku 5.5 low | 2/6 | most | ~3 s | ~3 s | — | — |
  | Haiku 5.5 high | 6/6 | 7/9 | 11–23 s | 1–3 s | ~$0.002 | 7/18 |
  | Sonnet 5.5 low | 4/6 | 9/9 | ~2 s | ~1 s | ~$0.003 | 7/18 |
  | **Sonnet 5.5 medium** (3 runs) | 18/18 | 27/27 | ~2.3 s | ~1.2 s | ~$0.003 | 35/54 |
  | Sonnet 5.5 high | 6/6 | 9/9 | 8–12 s | ~1 s | ~$0.014 | 4/18 |
  | Opus 5.5 high | 4/6 | 9/9 | 5–19 s | 1–4 s | ~$0.016 | 1/18 |

  Fastest with the best types, about $0.40 for 300 commits a month. Haiku at
  `high` thinks 3–5× longer than Sonnet and is slower on large diffs. `medium`
  thinks rarely — one run in 54 took 13 s. `thinking: disabled` leaks
  reasoning-like text into the reply more often. Latency on the direct
  API-key path is not measured yet — `claude -p` adds no start-up time to
  these numbers
- **Subjects over 50 characters at `medium`** — accepted by the user. 35/54
  were too long — 24 of them by 1–3 characters, mostly the backticks and the
  emoji the prompt itself asks for, at most +11. Without thinking the model
  does not count exactly
- **`effort=high` for exact length** — rejected. 4/18 over 50, but 8–12 s per
  large diff
- **Length check in `cm` with one retry** — rejected. 17/18 within 50 after the
  retry, but large diffs took ~7 s on average, and a second miss would need its
  own rule
- **Length rule "not counting backticks and the emoji"** — rejected. Sonnet
  used the room: raw over-50 rose from 65 % to 75 %, text over-50 from 35 % to
  42 %, and thinking set in more often
- **Opus 5.5** — rejected. Costlier, less steady, `feat` 4/6
- **Effort chosen by diff size (`low` small, `high` large)** — rejected by the
  user. One fixed effort is simpler
- **`max_tokens` 16000** — required. Thinking counts toward `max_tokens` and
  can grow on a 12000-character diff — 4000 could end the reply before any
  text. The value is a cap only and costs nothing unused

### Authentication

- **Keychain item `anthropic-api-key` ranks above the OAuth token** — chosen.
  A global `ANTHROPIC_API_KEY` export also reaches Claude Code, which can then
  bill the API instead of the subscription
- **Broken API key does not fall through to OAuth** — accepted. A revoked or
  rotated key sends `cm` to the slow `claude -p` fallback — `cm` still works.
  A second api-call chain costs more code than this rare case is worth.
- **A key mistyped at the prompt replaces a valid OAuth token for that one run
  only** — accepted. The API answers `401`, the `💥` line names it, and the run
  goes through `claude -p` (about 3 s with `--safe-mode --tools ""`). The key is
  never stored — exit 1 means unproven — so the next run finds no key, takes
  the OAuth token again, and asks again. Nothing hides OAuth for good. A retry
  with the OAuth token after the `401` is the second api-call chain above
- **Keychain access dialog blocks `cm`** — non-problem. An item created with
  `security add-generic-password` lists `/usr/bin/security` as trusted, so the
  lookup runs without a dialog
- **Key prompt when no API key is found** — chosen. Only on a tty — input
  hidden, Enter skips to OAuth. The key goes to `security -i` on stdin, never
  into argv, where `ps` shows it. Enter asks again on the next run — no skip
  memory until it annoys
- **Without `security`, the pasted key goes to
  `${XDG_CONFIG_HOME:-~/.config}/cm/anthropic-api-key`, mode 600** — chosen.
  Read after the Keychain, before the OAuth token. Written by the `printf`
  builtin, so it never shows in `ps`. Plaintext, but the same protection Claude
  Code gives its own `~/.claude/.credentials.json` on Linux
- **Key file written via `mktemp` + `mv`, not under `umask 077`** — required.
  `umask` left an existing file at its old mode — `mktemp` always creates 600,
  and `mv` replaces the old file with its mode in one step
- **`export ANTHROPIC_API_KEY` in `~/.profile` as the store** — rejected.
  Every process inherits it — Claude Code then can bill the API instead of the
  subscription, and every tool sees the key. `secret-tool` and `pass` —
  rejected for now: both need a desktop session or a gpg agent, which an SSH
  login often lacks
- **Pasted key is stored once the API accepts it** — required.
  Stored at once, a mistyped key suppressed the prompt for good and sent every
  run to the slow fallback. Python exits 3 when the API accepted the key but
  the reply is unusable — `cm` stores on every exit code but 1, so a bad
  prefix or a stopped reply does not lose a good key
- **A failed store prints a `💥` line** — required. `security -i` exits
  non-zero when its add fails (161 in the sandbox), and the key-file branch
  fails on `mkdir` or the write — without the line the key vanished silently
  and the prompt came back
- **Key not stored after a network error, timeout, 400, 429, or 5xx** — kept.
  Exit 1 means the key is unproven — storing it there brings back the mistyped
  key that stays for good. The next run asks again. Passing the HTTP status
  from Python to bash as a second signal costs more than this rare case
- **Locked or denied keychain is named, not hidden behind "no API key"** —
  required. Over SSH to the Mac the login keychain is often locked — then
  `security` exits 128 (seen by the user) or 36 (`errSecInteractionNotAllowed`,
  derived, not seen). `cm` prints a `💥` line with the
  way out (`security unlock-keychain` or `ANTHROPIC_API_KEY`). Any other exit
  code but 0 and 44 (item not found) gets a `💥` line with the code only — the
  unlock hint fits a locked keychain, not every failure. Both skip the key
  prompt — storing would fail and the prompt would come back on every run
- **"No API key" `💥` line on every platform** — decided by the user, after a
  short-lived macOS-only variant. `ANTHROPIC_API_KEY` works everywhere, so a
  missing key is a fallback off macOS too
- **Key prompt needs a tty on stdin and stderr** — required. With stderr
  redirected, `read -p` wrote its prompt nowhere and `cm` waited blind
- **Every fallback prints a `💥` line with its cause** — chosen by the user,
  the style of `u` in `runcoms/zshrc`. Covered: no API key → OAuth on Haiku
  4.5, no key and no OAuth token or no python 3 → `claude -p`, API call failed
  or stopped, reply without text, prefix outside `cm.type`
- **`💥` format exists in bash (`warn`) and in Python (`fall`)** — kept. Python
  writes straight to stderr — one shared helper needs a second channel from
  Python to bash, more code than the two definitions
- **One `command -v security` check sets `has_security`** — required. It picks
  the store for a pasted key (Keychain or key file) and gates the API-key
  lookup with its locked-keychain check. The OAuth lookup runs unguarded — off macOS,
  `2>/dev/null` also swallows bash's `command not found` (verified in bash)
- **`429` quirk stays out of `CLAUDE.md`** — DRY. This file and the one-line
  `cm` comment at the OAuth override carry it — `CLAUDE.md` lists the auth
  sources only
- **Keychain account from `id -un`, not `$USER`** — required. Under `set -u`,
  an environment without `USER` aborted `cm` after a successful API call and
  lost the commit

### Response handling

- **`stop_reason` other than `end_turn` → fallback** — chosen. A truncated text
  block never gets committed
- **HTTP error shows `error.message` from the body** — required.
  `str(HTTPError)` alone read `HTTP Error 400: Bad Request` and hid the cause —
  a wrong model ID or parameter sent every run to the slow fallback unexplained.
  Reading and parsing the body share one `try`, and the cause is cut at 200
  characters — a failing read gave a traceback, an HTML error page several KB
- **Reply without text → fallback with cause** — required. Haiku 5.5 can end
  a turn with its whole answer in thinking — Anthropic documents it at
  `xhigh`. Before, no text block gave `API call failed ()`, and a blank text
  block fell back without a `💥` line. The `try` now covers only the request,
  so no `sys.exit` runs inside it
- **HTTP 200 body without `stop_reason` or `content` → fallback with cause,
  exit 1** — required. A proxy page or a changed schema raised a bare
  traceback. Exit 1, not 3 — a captive portal answers 200 to any key, so only
  an Anthropic-shaped reply proves the key
- **`cm -t` reports `ok`, `failed`, or `rejected`** — required. A reply that
  only failed the `cm.type` check showed as `failed`, like a network error
- **Aborts and fallbacks share `warn` and the `💥` prefix** — chosen. `u` uses
  `💥` for aborts too — every abort, from "not a repository" to a failed
  `git commit`, goes through `die`, which appends `aborting`. The rejection
  text comes from `rejection()`, with the suffix `falling back to claude -p` or
  `aborting`
- **`PYTHONIOENCODING=utf-8` for the API call** — required. On Windows/Git
  Bash a piped stdout uses the ANSI code page — `print` of a subject with an
  emoji raised `UnicodeEncodeError` and sent every run to the fallback
- **Abort after `cm`'s own `git add -A` leaves the index staged** — kept,
  decided by the user
- **30 s urllib timeout with Haiku 5.5 thinking** — open. Measure with `cm -t`
  once the API key exists — raise it only on a real timeout
- **`refusal` via `claude -p` could commit refusal text** — open, not verified.
  Not new — before this change, a refusal without a text block also went to
  the fallback. Rare for commit diffs

### Commit-type prompt

- **Commit types come from `git config cm.type`, not from the history** —
  chosen. The house types live in the `[cm]` section of `runcoms/gitconfig`.
  Config holds the data, `cm` decides — Haiku only picks within the list
- **`cm` decides where the types apply, config holds data only** — chosen.
  `cm.prefix=false` → no prefix, `cm.prefix=true` → types, unset → types in an
  own repo: no remote, or a remote URL that contains a `cm.own` value
  (`lecodeski/`). Any other repo follows its history. Tested 2026-11-12: no
  remote, `lecodeski` over SSH, HTTPS, and `ssh://` → types; `mayflower` → none;
  `cm.prefix` overrides both ways
- **Repos without a remote get the types** — required by the user. A fresh
  `git init` has no other local convention, so it needs the prefixes most
- **`includeIf` layers as the switch** — rejected. Several `includeIf` blocks
  plus a reset runcom with an empty `type =` — "house everywhere, reset for any
  remote, house again for own remotes" — rebuilt an `if` in config files, and
  the reset file configured nothing. Before that, `includeIf` per own remote
  could not reach repos without a remote — git has no "no remote" or negated
  condition
- **`includeIf "gitdir:~/…"` per path** — rejected. Own and client repos share
  the home directory without a fixed root
- **`init.templateDir` with `cm.type`** — rejected. `git clone` applies the
  template too, so client clones would get the house types
- **Meanings appear in the prompt only when `cm.type` is set** — required.
  Measured with Haiku 4.5, a `feat:`/`chore:` history, 4 diffs × 4 runs —
  foreign `add:`/`mod:` prefixes: no meanings 0/16, meanings always on 3/16,
  meanings behind "Only if that set is …" in the prompt 2/16, meanings left
  out 0/16 (2026-10-29). Once Haiku reads the meanings, it uses them
- **Regex over the recent subjects as the taxonomy switch** — replaced by
  `cm.type`. It guessed — Commitizen's default `bump: version X → Y` subject
  switched the house taxonomy on in `feat:` repos, and 15 `fix:` subjects in a
  row locked the set to `fix`
- **`git config --local cm.type` per repo as the default** — rejected.
  `.git/config` is not versioned — a fresh clone loses it. It stays available
  for a single foreign repo with its own types, and `cm.prefix` is the light
  per-repo switch
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
- **Prefix meanings live once — `cm.type` in `runcoms/gitconfig`** — chosen.
  `cm` and `/commit` both read git config — `CLAUDE.md` only points there. An
  own repo without its own `CLAUDE.md` still gets the types
- **`feat` = "a feature — too big for add or mod"** — the user's wording, also
  for a feature that is only half done. `add` and `mod` say "small". 3
  feature-sized diffs × 3 runs via `claude -p`, neutral `main` history
  (2026-11-12), Haiku 5.5: `feat` 2/9 at `low`, 1/9 at `medium`, 6/9 at
  `high`. Sonnet 5.5 at `medium` gets both true feature diffs right in 18/18
  runs — see the model table above. The fallback-hardening diff mostly gets
  `fix`, which is close to a fix. A sharper wording — `feat` "a new capability,
  or one part of it", `fix` "never a new capability" — gave Haiku 2/9 at `low`,
  no better
- **Optional type argument, `cm feat`** — chosen by the user. It fixes the
  type in the prompt and in `rejection()`. Where `cm.type` applies, the type
  must be in it, else `cm` aborts with the list — elsewhere any type passes.
  The model still picks the scope and writes the message
- **4 of 18 Haiku `high` runs hung about 300 s** — measurement artefact. The
  same runs showed blocked connections to `downloads.claude.ai` in the
  sandbox. With `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` no later run hung
- **Measure only on a stable `cm`** — method. A run that reads the prompt
  from `cm` while `cm` changes, or reads `cm.type` from a removed file, measures
  a different prompt — two such runs were thrown away
- **Haiku 4.5 types the `fts` sort fix (`7b2913dc`) as `refac`** — known
  limit. The diff only adds `LC_ALL=C` — the bug is not visible in it. With
  the `feat:` history the same diff got `fix` 4/4
- **`/commit` (`~/.claude/commands/commit.md`) reads `cm.type`, `cm.prefix`,
  `cm.own`, and the remotes with `!` lines, no gating logic** — decided by the
  user. The lines are data — the session agent applies the same three rules
  as `cm` itself. Without types, repo docs define the meanings. A bash gate
  like the one in `cm` stays out — overkill for an in-session agent
- **House types also apply in a `lecodeski` fork of a foreign project** —
  kept, decided by the user. `cm.own` matches the remote owner, not the repo's
  convention — `git config cm.prefix false` or a local `cm.type` turns it off
  per repo
- **`rejection()` checks the first line only** — required. Before, `${1%%:*}`
  could span the subject and the body — `add(cm` passed when the body held
  `):`
- **`rejection()` matches `type(scope)!?:` on the whole subject** — required.
  Cutting at the first colon with `${subject%%:*}` let a subject without any
  colon pass whole — `fix(cm)` with no description got committed
- **One `rejection()` both checks and explains** — required. It cuts the
  subject once, prints the reason and succeeds on a breach, fails silently
  otherwise. Before, `valid()` and `rejected` each cut the first line, and
  `rejected` read the global `msg`, which worked only before `msg=''`. It also
  rejects an empty subject, so the final check is one line. On the api path an
  `if`/`elif` tests `msg` once and sets `state` — an empty reply there is
  `failed`, since Python already printed its cause
- **Type names not regex-escaped in `rejection()`** — YAGNI. The types are plain
  words — a name like `c++` does not exist
- **Malformed `cm.type` value without `=`** — no guard. The abort message
  names the allowed prefixes, so a broken entry shows at once
- **Subject ends with exactly one emoji** — aligned with `CLAUDE.md`, in `cm`
  and `/commit`. Before, "at least one emoji" also let one lead the subject.
  Haiku 4.5, 3 histories × 6 diffs × 4 runs: 71/71 replies end with exactly
  one emoji (2026-11-01)
- **Header comment on `cm.type` and the "Auth resolution" comment in `cm`** —
  kept, decided by the user
- **Multi-line comments on the prefix regex and on `rejection()`** — asked for by
  the user. They explain each regex part, `<<<`, and `%%` — an exception to the
  one-line comment rule
- **Scope with a colon (`mod(zsh:opts):`) fails `rejection()`** — YAGNI. The
  prompt asks for one short word — a colon or a path is no scope
- **`cm` prompt names `type(scope)!:` and "no other" prefix** — synced with
  `/commit`, which already allowed `!` and said "No other prefix". Haiku 4.5,
  6 diffs × 4 runs (2026-11-02): no `!` in 70 replies without a breaking
  change, `cm.type` repo 24/24 valid, and `fsmonitor` off went from `del` 4/4
  to `mod` 3/4

### Structure

- **Key lookup and store live in `find_key` and `store_key`** — chosen. The
  auth block only decides the order — a new store or source changes one
  function
- **Each fallback warning sits where its cause is known** — chosen. "no python
  3" after the python probe, "no API key and no valid OAuth token" at the end of
  the auth block, the OAuth line in the model override. Before, a two-arm `case`
  on `auth_mode` re-derived the causes later
- **Keychain warning only when no key was found** — required. A key file or
  env key after a locked keychain made the run succeed under a misleading
  "keychain locked" `💥` line
- **All whitespace stripped from an API key at its source** — required. A CR or
  LF in the key — a CRLF key file, an env key with a trailing newline — made
  urllib reject the header, and its error text put the whole key into the `💥`
  line. Stripping only CR left the LF case open. The strip sits at the end of
  `find_key` and right after the prompt's `read`, before the emptiness checks —
  one strip after the auth decision let a whitespace-only key choose the
  API-key path with `x-api-key: ''`. The OAuth `tr -d '\r'` pipe stage is gone
- **`claude -p` fallback runs `--safe-mode --tools ""`** — required. With the
  default tools, text in the staged diff could make Haiku read files or run an
  allowlisted command — a prompt injection from the commit itself. `--safe-mode`
  also drops plugins, hooks, skills, CLAUDE.md and MCP servers, and replaces
  `--strict-mcp-config --mcp-config '{…}'`. `--setting-sources user` stays —
  without it, `--safe-mode` still warns on workspace settings in an untrusted
  dir (tested 2026-11-11, both runs 3 s against 4.7 s before)
- **Fallback prompt names the rejection** — required. After a `cm.type`
  rejection, `claude -p` got the same prompt and the same model, so it likely
  repeated the mistake and `cm` aborted. The request now ends with "A previous
  draft was rejected: … Fix that."
- **Hand-made key file not checked for mode 600** — kept. `stat` options differ
  between macOS and Linux — a portable check is clumsy. The file `cm` writes is
  always 600, a hand-made one is the user's call
- **Key file read with `read -r`, first line only** — required. `$(<file)`
  kept inner lines, so a comment line glued itself onto the key
- **`$(<file)` for the credentials file too** — required. `$(cat …)` next to
  `$(<…)` was two idioms for one job and one extra process
- **Failed `git commit` keeps the message** — required. With `commit.gpgSign`
  a cancelled pinentry, or a failing hook, lost the generated message, and a
  retry paid a new API call. `cm` writes it to `COMMIT_EDITMSG` itself — git
  writes that file only after the `pre-commit` hook — and names the retry
  `git commit -F …` (tested with a failing `pre-commit` hook and a failing
  `gpg.program`)
- **Exit 36/128 reads "keychain locked or access cancelled"** — required. 128
  is the low byte of `errSecUserCanceled` (-128): over SSH no unlock dialog can
  show, but a denied access dialog gives 128 too — "locked" alone was wrong
  there
- **OAuth line says "no usable API key"** — required. After "keychain locked",
  "no API key" contradicted it — the key exists, it is unreachable
- **`error.message` passed through `str()`** — required. A proxy body
  `{"error":{"message":null}}` made `cause[:200]` raise outside the `try` —
  a bare traceback instead of the `💥` line
- **Comment above `find_key` stays** — kept, decided by the user
- **Orphan `anthropic-api-key.XXXXXX` after a failed write or `mv`** — kept.
  Only on a full disk or a write error — removing it costs more syntax than the
  case is worth, and the file is mode 600
- **Python starts three times on the OAuth path** — kept. About 20–40 ms on a
  0.6–2.7 s path — parsing the credentials inside the API script would pull
  auth selection and its warnings out of bash
- **Names `choice_rule`, `scope_rule`, `has_security`** — required. `pick` and
  `scope` held prompt sentences, `kc` meant "`security` exists"
- **`2>&1` dropped on `command -v`** — required. `command -v` prints nothing to
  stderr when the name is missing
- **Tabs in the `[cm]` section of `runcoms/gitconfig`** — rejected as a finding. Git writes config
  files with tabs — the format's own convention beats the repo-wide
  `.editorconfig` default. `.editorconfig` now says so for `runcoms/gitconfig*`,
  and the user's global `CLAUDE.md` names the rule
- **`api_model`/`api_effort` and `auth_mode`/`secret` as a data clump** —
  rejected. bash has no records — an `env` array adds a level of indirection
  and saves no line, and choosing the model in Python moves the `429`
  workaround away from where `cm -t` reports the model
- **Commit-type source named twice in `CLAUDE.md`** — rejected as a finding.
  DRY targets code — a doc may repeat a fact where a reader needs it
- **Trailing-whitespace cleanup in `runcoms/gitconfig` inside this branch** —
  rejected as a finding. Three lines, no behaviour change
- **"Review verdicts live in `ADJUDICATIONS.md`" in `CLAUDE.md`** — rejected as
  a finding. Meta-doc for reviewers, harmless
- **Non-JSON HTTP error body keeps its newlines in the `💥` line** — rejected.
  Rare, still readable, cut at 200 characters
- **`auth_mode` tested in bash and again in Python** — rejected as a finding.
  Linear script, one value read at its point of use

### Measurement method

- **Build the history window from `git log $c^`, never from `HEAD`** — a
  commit inside its own window gets its old subject copied — same text, same
  emoji
