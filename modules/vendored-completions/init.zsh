#
# Installs vendored third-party completion files ahead of compinit.
#
# The files are fetched by the autoloaded update-vendored-completions function
# (invoked by zprezto-update, which u() calls and which also runs standalone)
# into a directory outside the prezto repo, so refreshes never dirty the git
# tree (keeps zprezto-update's stash/pull clean).
#
# Configure the raw completion URLs in zpreztorc (the install name is each
# URL's last path segment, so it must end in the completion's own _name):
#   zstyle ':prezto:module:vendored-completions' completions \
#     'https://example.com/raw/_foo'

# The install dir is module-owned and fixed — if desired to move, adjust here:
_vendored_completions_dir="${XDG_DATA_HOME:-$HOME/.local/share}/prezto-vendored-completions"

fpath=($_vendored_completions_dir $fpath)
