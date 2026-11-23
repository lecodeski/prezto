# Adjudications

Settled decisions of this fork — each with its verdict and reason. Reviews
re-flag an entry only with new verified facts.

## Signing check (`modules/utility/bin/check-signing-config`)

Goal: a repo with a wrong signing config must not produce a commit that
GitHub shows as "Unverified".

- **Client-side hook, not a GitHub ruleset** — a personal account has no
  central ruleset, only one per repo. An org ruleset needs GitHub Team. The
  goal is local misconfig, and the hook catches it before the commit exists.
- **Config-based hook (`[hook "signing"]` in `runcoms/gitconfig`), not
  `core.hooksPath`** — git runs it in every repo and runs the repo's own hooks
  too. `core.hooksPath` would replace them.
- **Check the config at `pre-commit` and `pre-merge-commit`, not the
  signatures at `pre-push`** — simpler, no rev ranges, no stdin parsing.
  Accepted cost: rebase and cherry-pick skip the hook — the config was checked
  when the original commit came to exist.
- **Rule: the committer email is a valid uid of `user.signingkey`** — this is
  the binding GitHub checks for GPG. Rejected: a central identity list with
  `includeIf` — it needs a second config for each identity.
- **Committer email from `git var GIT_COMMITTER_IDENT`, not `user.email`** —
  GitHub compares the committer email, and `GIT_COMMITTER_EMAIL` overrides the
  config.
- **Misconfig gets a 💥 rejection, never a silent fallback** — `commit.gpgSign`
  off, `user.signingkey` unset, a key spec that matches several keys, a
  revoked or expired key or uid, an unknown key.
- **Strict match: exact case, literal principals** — GitHub documents no
  case rule, and it never reads the allowed-signers file. The strict side only
  rejects, and it says so with 💥. A wildcard principal maps many emails to one
  key — the opposite of the check.
- **SSH: `gpg.ssh.allowedSignersFile` is required** — an ssh key carries no
  email, and this file is the only local map from email to ssh key. GitHub
  links the two through the account instead — key and committer email must
  belong to the same account.
- **SSH key from `${key%.pub}.pub`** — `user.signingkey` may name the private
  key. The hook reads the public key next to it.
- **`gpg.openpgp.program`, then `gpg.program`, then `gpg`** — the hook must
  read the keyring that git signs with.
- **x509 is unsupported** — it falls into the gpg branch and gets rejected. No
  repo here uses it.
- **bash, not zsh** — git starts hooks outside zsh, and bash 3.2 ships with
  macOS.
- **Bare command name in the gitconfig, found via `PATH`** — no hard-coded repo
  path. Accepted cost: a git client without the shell `PATH` cannot find the
  hook and rejects every commit — it fails closed.
- **`git commit --no-verify` skips the hook** — accepted.
