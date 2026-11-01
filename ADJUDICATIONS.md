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
- **No `command -v security` guard** — non-problem. Off macOS, `2>/dev/null`
  also swallows bash's `command not found`, and the value stays empty
  (verified in bash). The extra spawn per run is negligible
- **`429` quirk documented only in the `cm` comment** — DRY. The repo
  `CLAUDE.md` lists the auth sources, not the quirk

### Response handling

- **`stop_reason` other than `end_turn` → fallback** — chosen. A truncated text
  block never gets committed
- **`sys.exit(str)` inside the `try`** — kept. `SystemExit` is no `Exception`,
  so the handler lets it through. A later `except BaseException` would catch it
  — a hypothetical refactor, YAGNI
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

### Measurement method

- **Build the history window from `git log $c^`, never from `HEAD`** — a
  commit inside its own window gets its old subject copied — same text, same
  emoji
