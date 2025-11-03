# Dotfiles

Some examples here:
[https://github.com/zdharma-continuum/zinit-configs](https://github.com/zdharma-continuum/zinit-configs)

## Installation

```bash
make install
```

### Fonts (Nerd Fonts)

The setup automatically installs MesloLGS NF (with icon support) to `~/.local/share/fonts/` (modern XDG default):

```bash
make install-fonts  # Download and install MesloLGS NF
```

**Font locations**:

- **Current user** (default): `~/.local/share/fonts/`
- System-wide (requires sudo): `/usr/share/fonts/`

After installation, set your terminal font to **MesloLGS NF Regular**.

## Local customizations

Local customization can be done by putting files in the ~/.zshrc.d/ directory. These files will be sourced by the main .zshrc file.

## Benchmarking / Profiling

```zsh
zinit times
```

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

- **Repo**: [echasnovski/mini.icons](https://github.com/echasnovski/mini.icons)
- **Purpose**: Lightweight alternative to nvim-web-devicons (fewer dependencies, faster)
- **Features**:
  - Icons for files, folders, LSP, diagnostics
  - Mock for nvim-web-devicons (backward compatible)
  - Used by: neo-tree, which-key
- **Requirements**: Nerd Font in your terminal (e.g., JetBrainsMono Nerd Font)

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
- [mini.icons](https://github.com/echasnovski/mini.icons)
- [Nerd Fonts](https://www.nerdfonts.com/)
