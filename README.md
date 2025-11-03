# Dotfiles

Some examples here:
[https://github.com/zdharma-continuum/zinit-configs](https://github.com/zdharma-continuum/zinit-configs)

## Installation

```bash
make install
```

## Local customizations

Local customization can be done by putting files in the ~/.zshrc.d/ directory. These files will be sourced by the main .zshrc file.

## Benchmarking / Profiling

```zsh
zinit times
```

## Neovim config (lazy.nvim)

Minimalistyczna, nowoczesna konfiguracja Neovim zoptymalizowana pod szybkie edycje w terminalu.

### Instalacja

```bash
make install  # Używa stow do symlinkowania .config/nvim → ~/.config/nvim
nvim          # Przy pierwszym uruchomieniu lazy.nvim zainstaluje się automatycznie
```

Po pierwszym uruchomieniu:

1. Lazy.nvim pobierze wszystkie pluginy automatycznie
2. Blink.cmp skompiluje binarne komponenty (Rust)
3. Autoryzuj Copilot: `:Copilot auth` → otwórz link w przeglądarce

### Struktura konfiguracji

```text
.config/nvim/
├── init.lua                    # Entry point (ładuje lazy + options)
├── lua/
│   ├── config/
│   │   ├── lazy.lua           # Bootstrap lazy.nvim, ustawienie leader keys
│   │   └── options.lua        # Wszystkie vim.opt ustawienia
│   └── plugins/               # Pluginy (auto-importowane przez lazy.nvim)
│       ├── blink.lua          # Completion engine
│       ├── copilot.lua        # GitHub Copilot (AI-assisted coding)
│       ├── mini-icons.lua     # Icons (lekka alternatywa dla nvim-web-devicons)
│       ├── neotree.lua        # File explorer (sidebar)
│       ├── solarized.lua      # Colorscheme (light theme)
│       └── which-key.lua      # Keybinding hints (popup menu)
```

---

## 🔌 Pluginy i ich użycie

### **lazy.nvim** — Plugin manager

- **Repo**: [folke/lazy.nvim](https://github.com/folke/lazy.nvim)
- **Cel**: Nowoczesny menedżer pluginów z lazy-loadingiem i automatycznym updatem
- **Komendy**:
  - `:Lazy` — otwórz dashboard z listą pluginów
  - `:Lazy sync` — update wszystkich pluginów
  - `:Lazy clean` — usuń nieużywane pluginy

**Leader key**: `Space` (ustawiony w `lazy.lua`)

---

### **blink.cmp** — Completion engine

- **Repo**: [saghen/blink.cmp](https://github.com/saghen/blink.cmp)
- **Cel**: Szybki, nowoczesny autocompletion (napisany w Rust + Lua)
- **Źródła**: LSP, path, snippets, buffer, **Copilot**
- **Keymaps** (preset: `default`):
  - `Ctrl-Space` — otwórz menu completion lub dokumentację
  - `Ctrl-n` / `Ctrl-p` lub `↑` / `↓` — nawigacja po listach
  - `Ctrl-y` — zaakceptuj wybrane completion
  - `Ctrl-e` — zamknij menu
  - `Tab` / `Shift-Tab` — nawigacja po snippetach (jeśli aktywne)

**Fuzzy matching**: Rust implementation (fallback do Lua, jeśli Rust niedostępny)

---

### **GitHub Copilot** — AI code suggestions

- **Repo**: [zbirenbaum/copilot.lua](https://github.com/zbirenbaum/copilot.lua) + [fang2hou/blink-copilot](https://github.com/fang2hou/blink-copilot)
- **Cel**: AI-asystowane sugestie kodu bezpośrednio w completion menu
- **Requirements**: Node.js >= 18
- **Integracja**: Copilot suggestions pojawiają się jako opcje w blink.cmp (nie inline)
- **Autoryzacja**:

  ```vim
  :Copilot auth
  ```

  Otwórz link w przeglądarce i wklej kod.

**Użycie**:

- Zacznij pisać → Copilot automatycznie sugeruje w menu completion
- Wybierz sugestię używając `Ctrl-n/p` i zaakceptuj `Ctrl-y`
- Copilot ma wyższy priorytet (`score_offset = 100`)

---

### **neo-tree.nvim** — File explorer

- **Repo**: [nvim-neo-tree/neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim)
- **Cel**: Nowoczesny file explorer z drzewem plików (następca NERDTree)
- **Dependencies**: mini.icons (ikony plików i folderów)
- **Keymaps** (domyślne neo-tree):
  - `:Neotree` — otwórz sidebar
  - `:Neotree toggle` — toggle sidebar
  - W sidebar:
    - `Enter` — otwórz plik/folder
    - `a` — dodaj nowy plik
    - `d` — usuń plik
    - `r` — zmień nazwę
    - `?` — help (pełna lista keymaps)

---

### **mini.icons** — Icon provider

- **Repo**: [echasnovski/mini.icons](https://github.com/echasnovski/mini.icons)
- **Cel**: Lekka alternatywa dla nvim-web-devicons (mniej dependencies, szybsze)
- **Funkcje**:
  - Ikony dla plików, folderów, LSP, diagnostics
  - Mock dla nvim-web-devicons (kompatybilność wsteczna)
  - Używany przez: neo-tree, which-key
- **Wymagania**: Nerd Font w terminalu (np. JetBrainsMono Nerd Font)

---

### **which-key.nvim** — Keybinding hints

- **Repo**: [folke/which-key.nvim](https://github.com/folke/which-key.nvim)
- **Cel**: Pokazuje dostępne skróty klawiszowe w popup menu gdy zaczniesz wpisywać kombinację
- **Użycie**:
  - Naciśnij `Space` (leader) → poczekaj ~200ms → pojawi się menu z dostępnymi opcjami
  - `<Space>?` — pokaż wszystkie keybindings dla obecnego bufora
- **Preset**: `modern` (v3.x)
- **Ikony**: ustawione na ASCII. Wyłączone ikony mapowań (`icons.mappings = false`), podmienione etykiety klawiszy (np. `Space` → `SPC`, `Tab` → `TAB`, strzałki → `Left/Right/Up/Down`) oraz proste separatory (breadcrumb `>`, separator `->`, group pusty). Dzięki temu nie pojawiają się brakujące glify nawet bez Nerd Font. Jeśli chcesz wrócić do pełnych ikon NF, usuń te nadpisania w `which-key.lua`.

**Jak to działa**: Gdy naciskasz leader key lub inny prefiks (np. `g`, `z`), which-key automatycznie pokazuje wszystkie dostępne kontynuacje z ich opisami. Nie musisz pamiętać wszystkich skrótów! 🎯

---

## ⌨️ Własne skróty klawiszowe (Keymaps)

**Leader key**: `Space` (spacja)

💡 **Tip**: Naciśnij `Space` i poczekaj - **which-key** pokaże ci wszystkie dostępne opcje!

### Leader mappings (Space + klawisz)

#### Pomoc & Keybindings

- `<Space>?` — Pokaż wszystkie keybindings dla obecnego bufora (which-key)

#### File Explorer & Nawigacja

- `<Space>e` — Toggle Neo-tree (otwórz/zamknij file explorer)
- `<Space>o` — Focus Neo-tree (przeskocz do explorera)

#### Zapisywanie & Wychodzenie

- `<Space>w` — Zapisz plik (`:w`)
- `<Space>q` — Wyjdź (`:q`)
- `<Space>Q` — Wyjdź bez zapisywania (`:qa!`)

#### Okna (Splits)

- `<Space>sv` — Split pionowy (`:vsplit`)
- `<Space>sh` — Split poziomy (`:split`)
- `<Space>sc` — Zamknij obecne okno (`:close`)

### Skróty bez leadera

#### Nawigacja między oknami

- `Ctrl+h` — Przejdź do lewego okna
- `Ctrl+j` — Przejdź do dolnego okna
- `Ctrl+k` — Przejdź do górnego okna
- `Ctrl+l` — Przejdź do prawego okna

#### Zmiana rozmiaru okien

- `Ctrl+↑` — Zwiększ wysokość
- `Ctrl+↓` — Zmniejsz wysokość
- `Ctrl+←` — Zmniejsz szerokość
- `Ctrl+→` — Zwiększ szerokość

#### Wcięcia w trybie Visual

- `<` — Wcięcie w lewo (zachowuje zaznaczenie)
- `>` — Wcięcie w prawo (zachowuje zaznaczenie)

**Pełna lista**: zobacz `.config/nvim/lua/config/keymaps.lua`

---

### **solarized.nvim** — Colorscheme

- **Repo**: [maxmx03/solarized.nvim](https://github.com/maxmx03/solarized.nvim)
- **Cel**: Klasyczny motyw Solarized (wersja light)
- **Ustawienia**:
  - Background: `light`
  - Truecolor: włączony (`termguicolors`)
- **Przełączanie dark/light** (opcjonalnie):

  ```vim
  :set background=dark
  :set background=light
  ```

---

## ⚙️ Core Options (lua/config/options.lua)

Najważniejsze ustawienia edytora:

| Opcja | Wartość | Opis |
|-------|---------|------|
| `number` | `true` | Numery linii (absolutne na bieżącej linii) |
| `relativenumber` | `true` | Relative numbers (łatwiejsze skoki `5j`, `10k`) |
| `clipboard` | `"unnamedplus"` | Współdzielony clipboard z systemem (wymaga `xclip` lub `wl-clipboard`) |
| `expandtab` | `true` | Spacje zamiast tabów |
| `shiftwidth` | `2` | Autoindent width (2 spacje) |
| `ignorecase` + `smartcase` | `true` | Case-insensitive search (chyba że użyjesz wielkich liter) |
| `undofile` | `true` | Persistent undo (historia edycji przetrwa restart) |
| `splitright` / `splitbelow` | `true` | Nowe splity po prawej/na dole |

**Pełna lista**: zobacz `.config/nvim/lua/config/options.lua`

---

## 🚀 Quick Start

### Podstawowy workflow

1. **Otwórz plik**:

   ```bash
   nvim file.txt
   ```

2. **File explorer** (neo-tree):

   ```vim
   :Neotree toggle
   ```

3. **Edycja z autocompletion**:
   - Tryb INSERT → zacznij pisać
   - `Ctrl-Space` → otwórz menu completion
   - `Ctrl-n/p` → wybierz opcję
   - `Ctrl-y` → zaakceptuj

4. **Copilot**:
   - Suggestions automatycznie w menu completion
   - Zaakceptuj jak zwykłe completion (`Ctrl-y`)

5. **Update pluginów**:

   ```vim
   :Lazy sync
   ```

---

## 📦 Rozszerzanie konfiguracji

### Dodawanie nowego pluginu

1. Stwórz nowy plik w `lua/plugins/`, np. `telescope.lua`:

   ```lua
   return {
     'nvim-telescope/telescope.nvim',
     dependencies = { 'nvim-lua/plenary.nvim' },
     config = function()
       -- Twoja konfiguracja
     end,
   }
   ```

2. Restartuj Neovim → Lazy.nvim automatycznie zainstaluje plugin

### Dodawanie LSP (w przyszłości)

Gdy będziesz potrzebować LSP dla konkretnych języków:

```bash
# Dodaj do lua/plugins/lsp.lua
return {
  'neovim/nvim-lspconfig',
  dependencies = { 'williamboman/mason.nvim' },
  -- ... konfiguracja
}
```

---

## 🐛 Troubleshooting

### Copilot nie działa

```vim
:Copilot status       " Sprawdź status
:Copilot auth         " Reautoryzuj
```

### Blink.cmp nie pokazuje suggestions

```vim
:Lazy sync            " Update pluginów
:checkhealth blink    " Sprawdź health
```

---

## 📚 Dalsze zasoby

- [lazy.nvim docs](https://github.com/folke/lazy.nvim)
- [blink.cmp docs](https://github.com/saghen/blink.cmp)
- [neo-tree wiki](https://github.com/nvim-neo-tree/neo-tree.nvim/wiki)
- [Copilot.lua](https://github.com/zbirenbaum/copilot.lua)
- [mini.icons](https://github.com/echasnovski/mini.icons)
- [Nerd Fonts](https://www.nerdfonts.com/)
