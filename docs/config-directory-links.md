# Configuration directory links

The default is a real directory with individual managed file links. The base
Stow package keeps `--no-folding`; `~/.config` itself always stays real. This
prevents an application from writing logs, generated settings or credentials
into the checkout through a directory link.

A whole-directory link is an explicit exception when the complete tree belongs
to the repository and the application's maintained state lives elsewhere. A
small tracked directory alone is not evidence that the application never writes
there. Local overrides, generated files and mutable plugin checkouts need their
own ownership decision before a directory can qualify.

## Why Neovim is an exception

The base installer links `~/.config/nvim` directly to `.config/nvim` in the
checkout and excludes that tree from the base Stow package. This keeps one owner
for the directory and makes new Lua modules available immediately. Loading an
existing module in an already running editor still requires an explicit reload
or a new editor session.

The maintained configuration already sends writes outside this tree:

- `lua/config/lazy.lua` installs plugins in `stdpath("data")/lazy` and keeps the
  lockfile in `stdpath("state")`.
- `lua/config/options.lua` puts undo, swap and backup paths in `stdpath("state")`.
- `lua/plugins/treesitter.lua` installs parsers in `stdpath("data")/site`.
- `maintain.lua` records pending builds in `stdpath("state")`.

These are the current configuration's guarantees, not a promise about every
future plugin. Do not add plugin-generated state or machine-specific settings
to the linked configuration tree. Reassess the exception if a plugin needs to
write there.

The installer accepts an existing link to this checkout. It refuses an existing
real directory, regular file, foreign link or dangling link without replacing
it. Link creation uses `ln -sT` without force, so a target created between the
check and the write also causes a visible failure.

## Neovim directory link migration

For an older installation with a real `~/.config/nvim` directory:

1. Inspect the tree, including hidden entries and link targets. Preserve and
   resolve any local configuration or runtime files before changing ownership.
   Do not merge generated state into the repository.
2. Choose an unused backup name beside `nvim`, then move the old directory there.
   Keeping the backup at the same depth preserves its relative file links.
3. Run `make install-base` from the checkout and accept its Stow application
   prompt. The base stage creates the directory link; it does not install or
   update Neovim plugins. A new installation needs a saved profile first, as
   described in the main README.
4. Check the link target and start a fresh editor session. For example, open an
   existing file with `nvim path/to/file:12`.

For GNU `mv` versions supporting `--update=none-fail`, this move refuses to
overwrite an existing backup and reports a collision as an error:

```sh
mv -T --update=none-fail -- "$HOME/.config/nvim" "$HOME/.config/nvim.before-directory-link"
```

If the destination exists, choose another name. Preserve the backup rather than
removing it as part of installation. To undo the migration, first verify that
`~/.config/nvim` is the expected repository link, remove that link alone, and
move the preserved directory back. The installer will again require migration
before its next base installation.

## Other candidates

Inspection of tracked files and local directory-entry metadata found the
following possibilities. Only Neovim is enabled as an exception. The observations
below are not proof of every application's write behavior.

| Directory | Evidence and remaining decision |
| --- | --- |
| `delta` | A theme fragment included by `.gitconfig`; the inspected directory contains only its managed link. Strongest next candidate, but there is little benefit while it remains one file. |
| `yamlfmt` | One formatter configuration and no observed local state. Verify the CLI's configuration-generation behavior before changing ownership. |
| `workmux` | One tracked configuration and no observed local state in this directory. Verify where the installed version writes sessions, locks and generated configuration. |
| `lazygit` | One tracked theme/configuration file and no observed local state in this directory. Verify the installed version's state and configuration-update paths first. |

Keep the following directories real:

- `Code`, `btop`, `herdr`, `jesseduffield/lazydocker` and `opencode` have observed
  application-owned logs, runtime data, plugin state or dependencies.
- `mise`, `k9s`, `mc` and `rclone` contain or require local, machine-specific or
  credential-bearing configuration; repository ownership of the entire directory
  is not established.
- `tmux` includes a plugin submodule. Treat its plugin checkout/update ownership
  separately before considering a directory link.

Do not turn these candidates into an automatic allowlist. Each additional
exception needs a concrete benefit, a checked write-path contract, and tests
that preserve unowned data and reject publication conflicts.
