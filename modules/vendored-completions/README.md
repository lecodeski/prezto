# Vendored Completions

Installs third-party zsh completion files that ship neither with zsh nor with
[zsh-completions][1]: this module's `update-vendored-completions` function
fetches them from their raw upstream URLs and hot-reloads them into the running
shell.

This module must be loaded **before** the _`completion`_ module, so its install
directory joins `$fpath` ahead of `compinit`.

## Configuration

List the raw completion URLs in _`${ZDOTDIR:-$HOME}/.zpreztorc`_:

```sh
zstyle ':prezto:module:vendored-completions' completions \
  'https://github.com/wbingli/zsh-claudecode-completion/raw/refs/heads/main/_claude'
```

The install name is each URL's last path segment (`${url:t}`), so a URL **must**
end in the completion's own `_name` — nothing to restate or mistype. URLs whose
last segment is not a plain `_name` (query junk, no leading underscore) or that
collide on a name are rejected before any download.

## Install directory

Files land in
`${XDG_DATA_HOME:-$HOME/.local/share}/prezto-vendored-completions`, outside the
prezto repo, so refreshes never dirty its git tree and repo updates stay stash /
pull-clean. The directory is module-owned and fixed — a plain global set in
_`init.zsh`_. Relocate it by editing that line. The updater prunes stray `_*`
files from it, so nothing else may write there.

## Update & Reload: `update-vendored-completions`

Autoloaded with the module; callable standalone, and in this repo wired into
[`zprezto-update`][3], whose kernel file lock also serializes it. Per configured
URL it:

1. downloads to a dot-prefixed temp file in the install dir
    1. hidden from compinit if an interrupt strands it
    2. an atomic same-filesystem `mv` away from being installed
2. validates a complete `#compdef` header naming at least one command, no CRLF,
   and `zsh -n` syntax check over the body
    1. this catches corruption (truncation, an HTML error page served `200`,
       etc.) — **not** a compromised-but-valid upstream
    2. **trust in the configured URL is inherent**
3. installs and hot-reloads it into the current shell
    1. only when the content changed
4. prunes any `_*` files in the install dir no longer configured
    1. re-autoloading a same-named system completion if one survives elsewhere
       on `$fpath`.

When anything changed it drops the `compinit` dump, so the next shell rescans
`$fpath` instead of reusing a stale one.

It returns nonzero on a failed URL, empty config, missing `curl`, or a refused
lock — a forcing function to fix the URL or drop the module. What callers make
of that is their call (see [Updating][3]).

### Shadowing caveat

The _`completion`_ module prepends its bundled zsh-completions right before
`compinit`, so a vendored file whose name collides with one of those is shadowed
and never loads. Rather than patch that module and fight upstream merges, the
updater checks `$fpath` for a shadower every run and fails loudly.

## Authors

_The authors of this module should be contacted via the [issue tracker][2]._

- [Big Lecodeski](https://github.com/lecodeski)

[1]: ../completion/README.md
[2]: https://github.com/lecodeski/prezto/issues
[3]: ../../README.md#updating
