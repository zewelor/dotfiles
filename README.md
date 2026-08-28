# Dotfiles

Some examples here:
[https://github.com/zdharma-continuum/zinit-configs](https://github.com/zdharma-continuum/zinit-configs)

## Installation

```bash
git clone https://github.com/zewelor/dotfiles && cd dotfiles && make install
```

`make base` installs the core packages and Zinit, but does not install `mise`.
The desktop profile bootstraps the official standalone `mise` into
`~/.local/bin/mise` via `make mise`, using a versioned release installer whose
SHA-256 is pinned in `Makefile`. Server installs do not require `mise`; when it
is present, `update-all` can self-update the installed binary. Renovate checks
the bootstrap monthly and updates the release version together with the
installer's SHA-256. `.zshenv` exposes mise and its shims through a static
`PATH` without prompt or directory-change hooks. Zinit only manages shell
plugins and the small intentional CLI exceptions. `./install` asks once before
applying all successful Stow dry-runs. For automation, set both values
explicitly:

```bash
DOTFILES_PROFILE=server DOTFILES_STOW_APPLY=1 ./install
```

## Health Checks & Testing

Use the built-in health checks and regression test suite before or after bigger changes:

```bash
make test    # run offline regression tests directly (zsh tests/vault_test.zsh)
make doctor  # fast repo-local checks (syntax, stow dry-run, required tools, offline Vault tests)
make verify  # deeper environment drift checks for the current machine
```

- `make test` runs the offline regression test suite directly (`zsh tests/vault_test.zsh`) using mocks without contacting a cluster.
- `make doctor` is meant to stay fast and offline; it runs syntax checks, stow dry-runs, tool availability, and the offline Vault helper suite.
- `make verify` runs all `make doctor` checks plus interactive shell startup and local workstation state verification.

### Shell requirement (zsh)

The `./install` script aborts if your **login shell** is not `zsh` to avoid the common “installed but nothing changed” confusion when the user stays in `bash` (e.g. on Raspberry Pi OS).

Switch your login shell to zsh:

```bash
chsh -s "$(command -v zsh)"
```

Then log out and log back in (or reboot).

**Override (not recommended):**

```bash
DOTFILES_ALLOW_NON_ZSH_SHELL=1 ./install
```

**Font locations**:

- **Current user** (default): `~/.local/share/fonts/`
- The tracked JetBrains Mono Nerd Font set contains only `Regular`, `Bold`,
  `Italic`, and `BoldItalic`. `make update-fonts` preserves that four-style set.

## Local customizations

Local customization can be done by putting files in the ~/.zshrc.d/ directory. These files will be sourced by the main .zshrc file.

## Terminal emulators

- Foot is the only managed terminal emulator and the KDE default.
- Its configuration lives in `~/.config/foot/foot.ini` and uses the transparent Catppuccin Latte theme.
- On desktop installs, `./install` offers to install `foot` with `foot-terminfo` when it is missing.

## Summarize

- `.summarize/config.json` is a seed, not a Stow package. Summarize rewrites
  `~/.summarize/config.json` during `refresh-free`, so the runtime copy must be a
  regular user-owned file.
- `./install` migrates the old repository symlink once, preserves an existing
  runtime-owned config, and creates new copies with mode `0600`.
- `summarize-refresh-free` refreshes OpenRouter free models and keeps
  `cli/agy` as the first fallback candidate.

## rclone NAS mount (desktop only)

The install script can configure rclone to mount a NAS via WebDAV with local caching. This is useful for remote access over VPN where NFS/SMB performance suffers from latency.

### Setup

During `./install`, answer **Y** to "Would you like to setup rclone with password from Vault?"

The password is fetched from Vault at `secret/configs/rclone` (key: `nas_pass`).

**Requirements**: Mount point `/mnt/nas` must exist. The install script does not
create it; create it manually if needed:

```bash
sudo mkdir -p /mnt/nas && sudo chown $USER:$USER /mnt/nas
```

Also ensure `user_allow_other` is enabled in `/etc/fuse.conf` for the `--allow-other` mount option.

### Files

| File | Description |
|------|-------------|
| `.config/rclone/rclone.conf.template` | Template in git (without password) |
| `.config/systemd/user/rclone-nas.service` | Systemd service (stow symlinks it) |
| `~/.config/rclone/rclone.conf` | Generated config (with password, not in git) |

### Testing

```bash
# List NAS root
rclone lsd nas:/

# List specific folder
rclone ls nas:/Multimedia/Music

# Check mount status
systemctl --user status rclone-nas.service

# Manual mount (if service not running)
rclone mount nas:/ /mnt/nas --vfs-cache-mode full --vfs-cache-max-size 5G
```

### Systemd service

The service auto-starts on login and mounts NAS to `/mnt/nas`:

```bash
# Enable (done by install script)
systemctl --user enable --now rclone-nas.service

# Restart after config changes
systemctl --user restart rclone-nas.service

# View logs
journalctl --user -u rclone-nas.service -f
```

### Vault secret

Password is stored in Vault at `secret/configs/rclone` (key: `nas_pass`, obscured format).

Generate obscured password: `rclone obscure "your_plaintext_password"`

## Storage Box media SMB automount (desktop only)

The Storage Box media share is mounted independently from the existing rclone
NAS mount. It uses native kernel CIFS through the private HAProxy relay and does
not require rclone:

```text
//storage-media.svc.lan/<storagebox_media_username> -> /mnt/storagebox/media
```

The setup reads `storagebox_media_username` and `storagebox_media_password`
from `secret/auth/hetzner` in Vault. It manages only the generated user secret:
`~/.config/storagebox/media.credentials`, with directory mode `0700` and file
mode `0600`. The credentials are never stored in Git or printed.

Requirements:

- `curl` and `jq` for reading Vault;
- `cifs-utils` for the eventual CIFS mount;
- the management VPN/relay when testing DNS and the mount.

During `./install`, answer **Y** to:

```text
Would you like to setup Storage Box media? [y/N]
```

Answering **N** or pressing Enter skips the feature completely: no helper,
DNS, Vault, file, or `sudo` operation is attempted. Answering **Y** reuses an
existing `VAULT_TOKEN` or prompts for it, refreshes the credentials, and prints
only the missing manual actions. The helper never runs `sudo`, edits
`/etc/fstab`, creates the mountpoint, or mounts the share.

Initial setup stays under `./install`. To rerun only this setup or rotate its
credentials later, call the stowed helper directly:

```bash
~/bin/setup-storagebox-media-mount
```

If private Stow has not completed yet, rerun `./install` instead.

Add the canonical line below with `sudoedit /etc/fstab`, replacing `<username>`
with `storagebox_media_username` from Vault if the helper has not printed the
concrete line yet:

```fstab
//storage-media.svc.lan/<username> /mnt/storagebox/media cifs credentials=/home/omen/.config/storagebox/media.credentials,uid=1000,gid=1000,forceuid,forcegid,file_mode=0644,dir_mode=0755,iocharset=utf8,vers=3.1.1,seal,rw,nosuid,nodev,_netdev,x-systemd.automount,x-systemd.idle-timeout=15min,x-systemd.mount-timeout=30s,nofail 0 0
```

Use the numeric UID and GID printed by `id -u` and `id -g` if they differ from
`1000`. `x-systemd.automount` makes systemd generate the mount and automount
units from `fstab`; `x-systemd.idle-timeout=15min` attempts to unmount the share
after 15 idle minutes, while `x-systemd.mount-timeout=30s` bounds a failed mount
attempt. `_netdev` treats it as a network mount and `nofail` keeps an unavailable
relay from blocking boot.

After adding or changing the line, activate the generated automount and trigger
it before running the read/write canary. `daemon-reload` regenerates the units
but does not start a newly added automount in the current boot:

```bash
sudo install -d -m 0755 /mnt/storagebox/media
sudo systemctl daemon-reload
sudo systemctl restart mnt-storagebox-media.automount
systemctl is-active mnt-storagebox-media.automount
ls /mnt/storagebox/media >/dev/null
findmnt --mountpoint /mnt/storagebox/media --output SOURCE,TARGET,FSTYPE,OPTIONS
canary=$(mktemp -p /mnt/storagebox/media .dotfiles-canary.XXXXXX)
printf 'storagebox canary\n' > "$canary" && grep -qx 'storagebox canary' "$canary" && rm -- "$canary"
```

Then verify that the still-active automount reconnects after the CIFS mount is
disconnected:

```bash
sudo umount /mnt/storagebox/media
systemctl is-active mnt-storagebox-media.automount
ls /mnt/storagebox/media >/dev/null
findmnt --mountpoint /mnt/storagebox/media --output SOURCE,TARGET,FSTYPE,OPTIONS
```

If DNS does not resolve, start the VPN/relay before the mount and canary. The
helper still writes the credentials and prints the pending instructions.

Rollback is limited to the manual system change: remove the Storage Box line
with `sudoedit /etc/fstab`, reload systemd, and unmount it. The old `/mnt/nas`
rclone/WebDAV mount remains unchanged throughout:

```bash
sudo systemctl stop mnt-storagebox-media.automount
sudo umount /mnt/storagebox/media  # only if it is still mounted
sudoedit /etc/fstab
sudo systemctl daemon-reload
```

## Scheduled user jobs

- Repo-managed scheduled jobs live in `~/.config/systemd/user/` and are synced by `stow` like the rest of the dotfiles.
- Put public jobs in `.config/systemd/user/` and private jobs in `prv/.config/systemd/user/`.
- Register units in `install` via `setup_user_systemd_units()` so `./install` reloads `systemd --user` and enables them automatically.
- Use `Persistent=true` in timers when a missed run should fire on the next login/resume instead of being skipped.

### Daily briefing timer

- Script: `prv/bin/daily_briefing/run.sh`
- Units: `prv/.config/systemd/user/daily-briefing.service` and `prv/.config/systemd/user/daily-briefing.timer`
- Schedule: every day at `07:00`
- Catch-up behavior: if the laptop was asleep or you were logged out at `07:00`, `Persistent=true` makes the missed run execute when the user session comes back.

Useful commands:

```bash
systemctl --user status daily-briefing.timer
systemctl --user list-timers daily-briefing.timer
journalctl --user -u daily-briefing.service -f
```

## Benchmarking / Profiling

```zsh
zinit times
```

## Shell Tools

### Git worktrees — normal clone bootstrap

- **Purpose**: bootstrap a repository into a worktree-friendly layout with a normal clone (no bare repo)
- **Bootstrap command**: `gwtclone <repo-url> [target-dir]`
- **Resulting layout**:

```text
my-project/
└── main/          ← normal clone, default branch checked out
```

- **Behavior**:
  - detects the remote default branch via `git ls-remote`
  - clones normally into `<target-dir>/<default-branch>/`
  - changes the current shell into the clone directory
- **Follow-up commands**:
  - `gwta feature-x` — create a new sibling worktree and cd into it
  - `gwtcd feature-x` — cd into an existing worktree by branch name (Tab completion suggests only worktree branches)
  - `git worktree list` — inspect worktrees

### eza — Modern ls replacement

- **Repo**: [eza-community/eza](https://github.com/eza-community/eza)
- **Purpose**: A modern replacement for `ls` with icons, colors, and git integration
- **Installation**: Automatic via zinit (downloaded from GitHub releases)
- **Theme**: Catppuccin Latte (eza uses default terminal colors)

**Aliases**:

| Alias | Command | Description |
|-------|---------|-------------|
| `ls` | `eza --icons --group-directories-first` | Default listing with icons |
| `l` | `eza -1a --icons ...` | One file per line, including hidden |
| `ll` | `eza -lh --icons ...` | Long format with human-readable sizes |
| `la` | `eza -lah --icons ...` | Long format including hidden files |
| `lt` | `eza -T --icons ...` | Tree view |
| `lr` | `ll -R` | Recursive listing |
| `lk` | `ll -Sr` | Sorted by size (largest last) |

**Useful flags** (can be combined with aliases):

```bash
ll --git          # Show git status for each file
ll -s modified    # Sort by modification time
ll -s size        # Sort by file size
lt -L 2           # Tree view, 2 levels deep
ls --no-icons     # Disable icons (faster on slow terminals)
```


---

### zoxide — Smarter cd with frecency

- **Repo**: [ajeetdsouza/zoxide](https://github.com/ajeetdsouza/zoxide)
- **Purpose**: A smarter `cd` command that learns your most-used directories
- **Installation**: Automatic via zinit (downloaded from GitHub releases)

**How it works**: zoxide tracks the directories you visit and ranks them by "frecency" (frequency + recency). When you type `z foo`, it jumps to the most likely directory matching "foo".

**Commands**:

| Command | Description |
|---------|-------------|
| `z foo` | Jump to the best match for "foo" |
| `z foo bar` | Jump to directory matching both "foo" and "bar" |
| `z -` | Jump to the previous directory |
| `zi foo` | Interactive selection (requires fzf) |
| `zoxide query foo` | Show what zoxide would match |
| `zoxide query -l` | List all tracked directories |

**Examples**:

```bash
# After visiting ~/projects/my-awesome-app a few times:
z awesome        # Jumps to ~/projects/my-awesome-app
z my app         # Also works (multiple keywords)
z proj           # Jumps to most frecent directory containing "proj"

# Interactive mode (with fzf)
zi               # Browse all tracked directories
zi proj          # Browse directories matching "proj"
```

**Tips**:

- `cd` is aliased to `z`, so your muscle memory works
- zoxide learns as you navigate; it gets better over time
- Use `zi` when you're not sure which directory you want
- Database stored at `~/.local/share/zoxide/db.zo`

---

### btop — Resource monitor

- **Repo**: [aristocratos/btop](https://github.com/aristocratos/btop)
- **Purpose**: A resource monitor that shows CPU, memory, disk, and network usage in a beautiful and interactive way
- **Installation**: Automatic via `Makefile` (`APT_PACKAGES_CORE`)
- **Theme**: Catppuccin Latte (via `~/.config/btop/themes/`)

**Config**:

- `~/.config/btop/btop.conf` — managed by dotfiles (stow)
- `~/.config/btop/themes/catppuccin_latte.theme` — default theme

To change flavor, replace the theme file in `~/.config/btop/themes/` and update `color_theme` in `~/.config/btop/btop.conf`.

---

### Catppuccin theme accents

Most tools in this repo use Catppuccin **Latte** as the base flavor. Some tools (lazygit, atuin) also allow picking an **accent color** within that flavor:

- **Available accents**: `blue` (default), `flamingo`, `green`, `lavender`, `maroon`, `mauve`, `peach`, `pink`, `red`, `rosewater`, `sapphire`, `sky`, `teal`, `yellow`
- **Tools that support accents**:
  - `lazygit` — `.config/lazygit/config.yml`
  - `atuin` — `.config/atuin/config.toml` + theme file in `.config/atuin/themes/`

To switch the accent, replace the theme file/config reference with the desired accent name. For example, for `atuin` change `catppuccin-latte-blue` → `catppuccin-latte-mauve` (and ensure the matching theme file exists).

---

### tmux and tmuxinator — session helpers

- **Repo**: [tmuxinator/tmuxinator](https://github.com/tmuxinator/tmuxinator)
- **Purpose**: `tat` handles current-directory tmux sessions, while `mux` runs tmuxinator project sessions
- **Installation**: Automatic via `mise` in `./install` (`gem:tmuxinator`)

**Session commands**:

| Command | Behavior |
|---------|----------|
| `tat` | Attaches to or creates a tmux session named after the current directory |
| `mux <project>` | Runs `tmuxinator <project>` |

**Project configs**:

- `prv/.tmuxinator/*.yml`

**Projects still using tmuxinator:**

- `cc-workers`, `dottales`, `esphome` (project-exit hooks and docker lifecycle)

---

## Neovim config (lazy.nvim)

The configuration requires Neovim 0.11+. Plugin revisions are machine-local;
lazy.nvim stores its runtime lockfile under Neovim's state directory instead of
the Stow-managed configuration. The canonical Neovim structure, plugin list,
keymaps and workflows live in
[`.config/nvim/README.md`](./.config/nvim/README.md).
