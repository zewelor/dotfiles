# Dotfiles

Some examples here:
[https://github.com/zdharma-continuum/zinit-configs](https://github.com/zdharma-continuum/zinit-configs)

## Installation

```bash
make install
```

**Font locations**:

- **Current user** (default): `~/.local/share/fonts/`

## Local customizations

Local customization can be done by putting files in the ~/.zshrc.d/ directory. These files will be sourced by the main .zshrc file.

## rclone NAS mount (desktop only)

The install script can configure rclone to mount a NAS via WebDAV with local caching. This is useful for remote access over VPN where NFS/SMB performance suffers from latency.

### Setup

During `./install`, answer **Y** to "Would you like to setup rclone with password from Vault?"

The password is fetched from Vault at `secret/configs/rclone` (key: `nas_pass`).

**Requirements**: Mount point `/mnt/nas` must exist. The install script will offer to create it with sudo, or you can create it manually:

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

## Web app launchers

- Config file: `webapps/apps.tsv` (`name|slug|app_url|icon_filename|extra_flags`); directory is excluded from `stow`, installers handle generation.
- Add entry: drop a 256x256 PNG into `webapps/icons/` (any filename), put that filename in column 4 of `apps.tsv`; the installer errors if the file is missing.
- Generated files live in `~/.local/share/applications/dotfiles-<slug>.desktop` with icons at `~/.local/share/icons/hicolor/256x256/apps/dotfiles-<slug>.png`.
- Prefix `dotfiles-` avoids clashes with distro/system entries.
- Browser selection: `$BROWSER` (validated) or auto-detected Brave/Chrome/Chromium. Global flags: `DOTFILES_BROWSER_FLAGS`; Wayland toggle: `DOTFILES_CHROMIUM_WAYLAND=1|0`.
- Icons: installer copies `webapps/icons/<icon_filename>` per row into `~/.local/share/applications/icons/` (no resizing, so use a size that looks good in your DE).
- Stale entries check: installer lists `dotfiles-*` entries not declared in `apps.tsv` and offers to remove them (non-interactive: only warns).

## Benchmarking / Profiling

```zsh
zinit times
```

## Shell Tools

### eza — Modern ls replacement

- **Repo**: [eza-community/eza](https://github.com/eza-community/eza)
- **Purpose**: A modern replacement for `ls` with icons, colors, and git integration
- **Installation**: Automatic via zinit (downloaded from GitHub releases)
- **Theme**: Solarized Light (`.config/eza/theme.yml`)

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

**Note**: On slow filesystems (`/mnt/nas*`), the `ls` function falls back to plain `ls --color=auto` for performance.

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

## Neovim config (lazy.nvim)

Minimal, modern Neovim configuration optimized for fast terminal editing.

### Neovim installation

```bash
make install  # Uses stow to symlink .config/nvim → ~/.config/nvim
nvim          # On the first launch, lazy.nvim installs automatically
```

After the first launch:

1. Lazy.nvim automatically installs all plugins
2. Blink.cmp compiles native components (Rust)
3. Authorize Copilot: `:Copilot auth` → open the link in your browser

### Configuration structure

```text
.config/nvim/
├── init.lua                    # Entry point (loads lazy + options)
├── lua/
│   ├── config/
│   │   ├── lazy.lua           # Bootstrap lazy.nvim, leader keys
│   │   └── options.lua        # All vim.opt settings
│   └── plugins/               # Plugins (auto-imported by lazy.nvim)
│       ├── blink.lua          # Completion engine
│       ├── copilot.lua        # GitHub Copilot (AI-assisted coding)
│       ├── mini-icons.lua     # Icons (lightweight alternative to nvim-web-devicons)
│       ├── neotree.lua        # File explorer (sidebar)
│       ├── solarized.lua      # Colorscheme (light theme)
│       └── which-key.lua      # Keybinding hints (popup menu)
```

---

## 🔌 Plugins and usage

### **lazy.nvim** — Plugin manager

- **Repo**: [folke/lazy.nvim](https://github.com/folke/lazy.nvim)
- **Purpose**: Modern plugin manager with lazy-loading and automatic updates
- **Commands**:
  - `:Lazy` — open the dashboard with the plugin list
  - `:Lazy sync` — update all plugins
  - `:Lazy clean` — remove unused plugins

**Leader key**: `Space` (set in `lazy.lua`)

---

### **blink.cmp** — Completion engine

- **Repo**: [saghen/blink.cmp](https://github.com/saghen/blink.cmp)
- **Purpose**: Fast, modern autocompletion (Rust + Lua)
- **Sources**: LSP, path, snippets, buffer, **Copilot**
- **Keymaps** (preset: `default`):
  - `Ctrl-Space` — open completion menu or docs
  - `Ctrl-n` / `Ctrl-p` or `↑` / `↓` — navigate items
  - `Ctrl-y` — accept selected completion
  - `Ctrl-e` — close menu
  - `Tab` / `Shift-Tab` — navigate snippets (when active)

**Fuzzy matching**: Rust implementation (falls back to Lua if Rust is unavailable)

---

### **GitHub Copilot** — AI code suggestions

- **Repo**: [zbirenbaum/copilot.lua](https://github.com/zbirenbaum/copilot.lua) + [fang2hou/blink-copilot](https://github.com/fang2hou/blink-copilot)
- **Purpose**: AI-assisted code suggestions directly in the completion menu
- **Requirements**: Node.js >= 18
- **Integration**: Copilot suggestions appear as options in blink.cmp (not inline)
- **Authorization**:

  ```vim
  :Copilot auth
  ```

  Open the link in your browser and paste the code.

**Usage**:

- Start typing → Copilot suggests in the completion menu automatically
- Select a suggestion with `Ctrl-n/p` and accept with `Ctrl-y`
- Copilot has higher priority (`score_offset = 100`)

---

### **neo-tree.nvim** — File explorer

- **Repo**: [nvim-neo-tree/neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim)
- **Purpose**: Modern file explorer with a tree view (successor to NERDTree)
- **Dependencies**: mini.icons (file/folder icons)
- **Keymaps** (neo-tree defaults):
  - `:Neotree` — open sidebar
  - `:Neotree toggle` — toggle sidebar
  - In the sidebar:
    - `Enter` — open file/folder
    - `a` — add new file
    - `d` — delete file
    - `r` — rename
    - `?` — help (full keymap list)

---

### **mini.icons** — Icon provider

- **Repo**: [nvim-mini/mini.icons](https://github.com/nvim-mini/mini.icons)
- **Purpose**: Lightweight alternative to nvim-web-devicons (fewer dependencies, faster)
- **Features**:
  - Icons for files, folders, LSP, diagnostics
  - Mock for nvim-web-devicons (backward compatible)
  - Used by: neo-tree, which-key
- **Requirements**: Nerd Font in your terminal

---

### **which-key.nvim** — Keybinding hints

- **Repo**: [folke/which-key.nvim](https://github.com/folke/which-key.nvim)
- **Purpose**: Shows available keybindings in a popup as you start a key sequence
- **Usage**:
  - Press `Space` (leader) → wait ~200ms → a menu appears with available options
  - `<Space>?` — show all keybindings for the current buffer
- **Preset**: `modern` (v3.x)
- **Icons**: set to ASCII. Mapping icons disabled (`icons.mappings = false`), labels adjusted (e.g., `Space` → `SPC`, `Tab` → `TAB`, arrows → `Left/Right/Up/Down`) and simple separators (breadcrumb `>`, separator `->`, group empty). This avoids missing glyphs even without a Nerd Font. If you want full NF icons back, remove these overrides in `which-key.lua`.

**How it works**: When you press the leader key or another prefix (e.g., `g`, `z`), which-key shows all available continuations with descriptions. You don’t have to memorize every mapping! 🎯

---

## ⌨️ Custom keymaps

**Leader key**: `Space`

💡 **Tip**: Press `Space` and wait — **which-key** will show everything available!

### Leader mappings (Space + key)

#### Help & Keybindings

- `<Space>?` — Show all keybindings for the current buffer (which-key)

#### File Explorer & Navigation

- `<Space>e` — Toggle Neo-tree (open/close file explorer)
- `<Space>o` — Focus Neo-tree (jump to explorer)

#### Save & Quit

- `<Space>w` — Save file (`:w`)
- `<Space>q` — Quit (`:q`)
- `<Space>Q` — Quit all without saving (`:qa!`)

#### Windows (Splits)

- `<Space>sv` — Vertical split (`:vsplit`)
- `<Space>sh` — Horizontal split (`:split`)
- `<Space>sc` — Close current window (`:close`)

### Non-leader mappings

#### Window navigation

- `Ctrl+h` — Go to the left window
- `Ctrl+j` — Go to the bottom window
- `Ctrl+k` — Go to the top window
- `Ctrl+l` — Go to the right window

#### Resize windows

- `Ctrl+↑` — Increase height
- `Ctrl+↓` — Decrease height
- `Ctrl+←` — Decrease width
- `Ctrl+→` — Increase width

#### Indent in Visual mode

- `<` — Indent left (keeps selection)
- `>` — Indent right (keeps selection)

#### Toggles & saving

- `Ctrl+N` twice — Cycle line numbers: off → absolute → relative
- `Ctrl+S` — Save file in Normal and Insert mode (`:w`)

**Full list**: see `.config/nvim/lua/config/keymaps.lua`

---

### **solarized.nvim** — Colorscheme

- **Repo**: [maxmx03/solarized.nvim](https://github.com/maxmx03/solarized.nvim)
- **Purpose**: Classic Solarized theme (light variant)
- **Settings**:
  - Background: `light`
  - Truecolor: on (`termguicolors`)
- **Toggle dark/light** (optional):

  ```vim
  :set background=dark
  :set background=light
  ```

---

## ⚙️ Core Options (lua/config/options.lua)

Key editor settings:

| Option | Value | Description |
|-------|---------|------|
| `number` | `true` | Line numbers (absolute on the current line) |
| `relativenumber` | `true` | Relative numbers (easier jumps like `5j`, `10k`) |
| `clipboard` | `"unnamedplus"` | Shared clipboard with the OS (requires `xclip` or `wl-clipboard`) |
| `expandtab` | `true` | Use spaces instead of tabs |
| `shiftwidth` | `2` | Autoindent width (2 spaces) |
| `ignorecase` + `smartcase` | `true` | Case-insensitive search unless uppercase used |
| `undofile` | `true` | Persistent undo (history survives restarts) |
| `splitright` / `splitbelow` | `true` | New splits on the right/bottom |

**Full list**: see `.config/nvim/lua/config/options.lua`

---

## 🚀 Quick Start

### Basic workflow

1. **Open a file**:

   ```bash
   nvim file.txt
   ```

2. **File explorer** (neo-tree):

   ```vim
   :Neotree toggle
   ```

3. **Editing with autocompletion**:
   - INSERT mode → start typing
   - `Ctrl-Space` → open completion menu
   - `Ctrl-n/p` → select an item
   - `Ctrl-y` → accept

4. **Copilot**:
   - Suggestions appear automatically in the completion menu
   - Accept like a regular completion (`Ctrl-y`)

5. **Update plugins**:

   ```vim
   :Lazy sync
   ```

---

## 📦 Extending the configuration

### Adding a new plugin

1. Create a new file in `lua/plugins/`, e.g., `telescope.lua`:

   ```lua
   return {
     'nvim-telescope/telescope.nvim',
     dependencies = { 'nvim-lua/plenary.nvim' },
     config = function()
       -- Your configuration
     end,
   }
   ```

2. Restart Neovim → Lazy.nvim will automatically install the plugin

### Adding LSP (later)

When you need LSP for specific languages:

```bash
# Add to lua/plugins/lsp.lua
return {
  'neovim/nvim-lspconfig',
  dependencies = { 'williamboman/mason.nvim' },
  -- ... configuration
}
```

---

## 🐛 Troubleshooting

### Copilot not working

```vim
:Copilot status       " Check status
:Copilot auth         " Re-authenticate
```

### Blink.cmp doesn’t show suggestions

```vim
:Lazy sync            " Update plugins
:checkhealth blink    " Check health
```

---

## 📚 Further resources

- [lazy.nvim docs](https://github.com/folke/lazy.nvim)
- [blink.cmp docs](https://github.com/saghen/blink.cmp)
- [neo-tree wiki](https://github.com/nvim-neo-tree/neo-tree.nvim/wiki)
- [Copilot.lua](https://github.com/zbirenbaum/copilot.lua)
- [mini.icons](https://github.com/nvim-mini/mini.icons)
- [Nerd Fonts](https://www.nerdfonts.com/)
