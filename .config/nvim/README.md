# 🚀 Konfiguracja Neovim

Nowoczesna, modularna konfiguracja Neovim z [lazy.nvim](https://lazy.folke.io/) jako menedżerem pluginów.

## 📁 Struktura konfiguracji

```
.config/nvim/
├── init.lua              # Entry point - ładuje wszystko
├── lua/
│   ├── config/
│   │   ├── lazy.lua     # Setup lazy.nvim
│   │   ├── options.lua  # Opcje edytora (vim.opt)
│   │   └── keymaps.lua  # Wszystkie keybindings
│   ├── plugins/         # Każdy plugin = osobny plik
│   │   ├── blink.lua                # Autouzupełnianie
│   │   ├── conform.lua              # Autoformat (format-on-save)
│   │   ├── copilot.lua              # GitHub Copilot
│   │   ├── lsp.lua                  # LSP + mason (language servers)
│   │   ├── mason-tool-installer.lua # Auto-installer narzędzi (formattery)
│   │   ├── mini-align.lua           # Wyrównywanie tekstu
│   │   ├── mini-icons.lua           # Ikony plików
│   │   ├── mini-pairs.lua           # Autopairs
│   │   ├── mini-surround.lua        # Surround (gsa/gsd/gsr)
│   │   ├── neotree.lua              # File explorer
│   │   ├── opencode.lua             # AI Assistant (opencode.nvim)
│   │   ├── telescope.lua            # Wyszukiwanie i fuzzy finder
│   │   ├── treesitter.lua           # Tree-sitter (Neovim 0.11+)
│   │   ├── solarized.lua            # Motyw kolorów
│   │   └── which-key.lua            # Podpowiedzi skrótów
│   └── after/
│       └── ftplugin/
│           └── markdown.lua  # Nadpisy dla Markdown (2 spacje + wrap)
└── lazy-lock.json       # Zablokowane wersje pluginów
```

## ⚙️ Core Options

Główne opcje edytora (z `lua/config/options.lua`):

| Opcja | Wartość | Opis |
|-------|---------|------|
| `number` | true | Numery linii |
| `relativenumber` | true | Relatywne numery (do nawigacji) |
| `expandtab` | true | Spacje zamiast tab |
| `tabstop` | 2 | Szerokość tabulacji |
| `shiftwidth` | 2 | Wcięcie przy `>>` |
| `smartindent` | true | Inteligentne wcięcia |
| `wrap` | false | Bez zawijania długich linii |
| `ignorecase` | true | Ignoruj wielkość liter w wyszukiwaniu |
| `smartcase` | true | ...chyba że wpiszesz wielką literę |
| `termguicolors` | true | True color support |
| `clipboard` | "unnamedplus" | Współdzielony clipboard z systemem |
| `undofile` | true | Trwałe undo (po zamknięciu pliku) |
| `mouse` | "" | Wyłączona obsługa myszy |

## 🔌 Pluginy i ich użycie

### **lazy.nvim** — Plugin Manager

- **Repo**: [folke/lazy.nvim](https://github.com/folke/lazy.nvim)
- **Cel**: Nowoczesny, szybki menedżer pluginów
- **Auto-instalacja**: Instaluje się automatycznie przy pierwszym uruchomieniu
- **Keymaps**:
  - `:Lazy` — Otwórz UI managera
  - `:Lazy sync` — Synchronizuj pluginy (install/update/clean)

---

### **neo-tree.nvim** — File Explorer

- **Repo**: [nvim-neo-tree/neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim)
- **Cel**: Nowoczesny file explorer w stylu VSCode
- **Keymaps**:
  - `<Space>e` — Toggle Neo-tree (`:Neotree toggle`)
  - `<Space>o` — Focus Neo-tree (`:Neotree focus`)
- **W Neo-tree**:
  - `a` — Dodaj plik/folder
  - `d` — Usuń
  - `r` — Zmień nazwę
  - `?` — Pomoc ze wszystkimi skrótami

---

### **telescope.nvim** — Fuzzy Finder

- **Repo**: [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- **Cel**: Błyskawiczne wyszukiwanie plików i treści z fuzzy matchingiem
- **Keymaps**:
  - `<Space>ff` — Szukaj plików przez Telescope (`find_files`)
  - `<Space>fg` — Szukaj w treści z ripgrep (`live_grep`)
- **Dodatkowe info**: Automatycznie używa `fd` jeśli dostępne oraz ładuje rozszerzenie `telescope-fzf-native` gdy dostępne `make`

---

### **which-key.nvim** — Podpowiedzi Keybindingów

- **Repo**: [folke/which-key.nvim](https://github.com/folke/which-key.nvim)
- **Cel**: Wyświetla popup z dostępnymi skrótami po wciśnięciu `<Space>`
- **Użycie**: Wciśnij `<Space>` i poczekaj ~300ms → zobaczysz listę dostępnych komend

---

### **blink.cmp** — Autouzupełnianie

- **Repo**: [saghen/blink.cmp](https://github.com/saghen/blink.cmp)
- **Cel**: Szybkie, nowoczesne autouzupełnianie kodu
- **Uwaga o kompatybilności**: Źródło Copilota w menu autouzupełniania jest aktywne tylko na Neovim 0.11+ (na starszych wersjach jest automatycznie wyłączone).
- **Keymaps** (w menu autouzupełniania):
  - `<C-Space>` — Wymuś pokazanie menu
  - `<CR>` — Potwierdź wybór
  - `<C-e>` — Anuluj
  - `<Tab>` / `<S-Tab>` — Nawigacja w menu

---

### **copilot.lua** — GitHub Copilot

- **Repo**: [zbirenbaum/copilot.lua](https://github.com/zbirenbaum/copilot.lua)
- **Cel**: Integracja z GitHub Copilot AI
- **Wymagania**: Neovim 0.11+ (na starszych wersjach plugin jest automatycznie wyłączony).
- **Setup**: Zaloguj przez `:Copilot auth`
- **Jak działa z blink.cmp**: Inline podpowiedzi są wyłączone, Copilot jest wpięty jako źródło w menu autouzupełniania (przez `blink-copilot`).
  - Akceptujesz je tak samo jak inne pozycje w menu — `<CR>` (Enter).

---

### **opencode.nvim** — AI Assistant (opencode)

- **Repo**: [nickjvandyke/opencode.nvim](https://github.com/nickjvandyke/opencode.nvim)
- **Cel**: Integracja z opencode AI assistant — edytorowo-świadome research, review i requesty
- **Wymagania**: Zainstalowany `opencode` CLI (patrz sekcja "Instalacja opencode CLI" poniżej)
- **Integracja**: Używa snacks.nvim dla lepszego UI (input + picker)
- **Context placeholders**: `@this` (zaznaczenie/kursor), `@buffer`, `@diagnostics`, `@diff`, itp.
- **Komendy**:
  - `:checkhealth opencode` — Sprawdź status integracji
- **Keymaps**:
  - `<leader>oa` — Ask opencode (z kontekstem `@this`)
  - `<leader>ox` — Wybierz i wykonaj akcję/prompt
  - `<leader>ot` — Toggle okno opencode (otwórz/zamknij terminal)
  - `<S-C-u>` — Scroll opencode w górę (half page)
  - `<S-C-d>` — Scroll opencode w dół (half page)
- **Użycie step-by-step**:
  1. Upewnij się, że `opencode` CLI jest zainstalowany i działa w terminalu
  2. Uruchom Neovim — plugin automatycznie połączy się z działającym serwerem lub uruchomi własny
  3. Użyj `<leader>oa` aby zapytać AI o kod pod kursorem / zaznaczeniu
  4. Użyj `<leader>ox` aby wybrać z gotowych promptów (explain, fix, review, test, itp.)
  5. Edytuj kod — zmiany od opencode automatycznie przeładują buffery

#### Instalacja opencode CLI

```bash
# Via Homebrew (macOS/Linux)
brew install anomalyco/opencode/opencode

# Lub przez mise (zgodnie z zasadami repo)
mise use -g github:anomalyco/opencode
```

**Ważne**: Uruchom `opencode` z flagą `--port` aby udostępnić serwer dla Neovim:
```bash
opencode --port
```

---

### **mini.align** — Interaktywne wyrównywanie

- **Repo**: [nvim-mini/mini.align](https://github.com/nvim-mini/mini.align)
- **Cel**: Szybkie wyrównywanie kolumn/tekstów z opcją podglądu na żywo
- **Keymaps**:
  - `ga` — Wyrównaj zakres (Normal: po ruchu/operatorze, Visual: na zaznaczeniu)
- **Dodatkowe**: Podczas wyrównywania możesz użyć wbudowanych modyfikatorów, np. `s` (wzorzec split), `j` (justowanie), `m` (delimiter), `t` (trim). Podgląd na żywo (`gA` w pluginie) został pominięty, żeby unikać zależności od wewnętrznych API.

---

### **mini.pairs** — Autopairs

- **Repo**: [nvim-mini/mini.pairs](https://github.com/nvim-mini/mini.pairs)
- **Cel**: Automatyczne domykanie par `()`, `[]`, `{}`, `""`, `''`
- **Keymaps**: brak (działa w insert mode)

---

### **mini.surround** — Surround (gsa/gsd/gsr)

- **Repo**: [nvim-mini/mini.surround](https://github.com/nvim-mini/mini.surround)
- **Cel**: Szybkie dodawanie/usuwanie/zamiana "otoczek" (cudzysłowy, nawiasy, tagi)
- **Keymaps**:
  - `gsa` — Add surrounding (Normal/Visual)
  - `gsd` — Delete surrounding
  - `gsr` — Replace surrounding
  - `gsf` — Find surrounding
  - `gsh` — Highlight surrounding
  - `gsn` — Update `n_lines` (zasięg szukania)

---

### **conform.nvim** — Autoformat (format-on-save)

- **Repo**: [stevearc/conform.nvim](https://github.com/stevearc/conform.nvim)
- **Cel**: Formatowanie plików przez zewnętrzne narzędzia
- **Autoformat on save**: `lua`, `sh`, `python`, `yaml`, `json` (Markdown wyłączony)
- **Keymaps**:
  - `<Space>cf` — Format buffer

---

### **mason-tool-installer.nvim** — Auto-instalacja narzędzi

- **Repo**: [WhoIsSethDaniel/mason-tool-installer.nvim](https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim)
- **Cel**: Automatycznie instaluje formatery używane przez conform (`stylua`, `shfmt`, `ruff`, `prettier`) i np. `hadolint`

---

### **mini.icons** — Ikony Plików

- **Repo**: [nvim-mini/mini.icons](https://github.com/nvim-mini/mini.icons)
- **Cel**: Ikony plików dla Neo-tree i pluginów (mock `nvim-web-devicons`)
- **Uwaga**: To nie zastępuje czcionki w terminalu. Aby uniknąć "kwadratów" także w menu autouzupełniania i innych miejscach, ustaw w terminalu czcionkę z ikonami

---

### **solarized-osaka.nvim** — Motyw Kolorów

- **Repo**: [craftzdog/solarized-osaka.nvim](https://github.com/craftzdog/solarized-osaka.nvim)
- **Cel**: Piękny motyw Solarized z wariantami light/dark
- **Aktywny**: `solarized-osaka` (dark mode)
- **Zmiana**: Edytuj `lua/plugins/solarized.lua`

---

### **nvim-treesitter** — Lepszy Syntax Highlighting

- **Repo**: [nvim-treesitter/nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
- **Cel**: Parsowanie kodu drzewem składni dla lepszego podświetlania i wcięć
- **Wymagania**: Neovim 0.11+ (na starszych wersjach plugin jest automatycznie wyłączony).
- **Parsery**: instalowane po upgrdzie (polecane: lua, vim, bash, python, json, yaml, toml, markdown, dockerfile, git, helm)
- **Komendy**:
  - `:TSUpdate` — Zaktualizuj wszystkie parsery
  - `:TSInstall <lang>` — Zainstaluj parser dla języka

---

### **LSP** — Language Server Protocol

Zestaw pluginów do inteligentnego uzupełniania i nawigacji po kodzie:

- **mason.nvim**: [williamboman/mason.nvim](https://github.com/williamboman/mason.nvim) — Menedżer serwerów LSP
- **mason-lspconfig.nvim**: [williamboman/mason-lspconfig.nvim](https://github.com/williamboman/mason-lspconfig.nvim) — Bridge mason ↔ lspconfig
- **nvim-lspconfig**: [neovim/nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) — Konfiguracja LSP
- **SchemaStore.nvim**: [b0o/SchemaStore.nvim](https://github.com/b0o/SchemaStore.nvim) — Schematy JSON/YAML dla `jsonls` i `yamlls` (podpowiedzi + walidacja; wspiera `$schema`)

**Zainstalowane serwery**:
- `lua_ls` — Lua (konfiguracja Neovim)
- `bashls` — Bash/Zsh
- `yamlls` — YAML (K8s, docker-compose; ESPHome: `!secret`, `!lambda`)
- `jsonls` — JSON (walidacja `$schema`)
- `helm_ls` — Helm charts
- `basedpyright` — Python
- `marksman` — Markdown
- `dockerls` — Dockerfile
- `docker_compose_language_service` — docker-compose

**Komendy**:
- `:Mason` — UI menedżera serwerów
- `:MasonInstall <server>` — Zainstaluj serwer
- `:LspInfo` — Info o aktywnych serwerach

**Keymaps** (aktywne gdy LSP jest podłączony):
- `gd` — Go to definition
- `gD` — Go to declaration
- `gr` — Find references
- `gi` — Go to implementation
- `K` — Hover documentation
- `<C-k>` — Signature help
- `<Space>rn` — Rename symbol
- `<Space>ca` — Code action
- `[d` / `]d` — Previous/next diagnostic

---

## ⌨️ Własne skróty klawiszowe

### Z Leaderem (Leader = `<Space>`)

#### File Explorer

- `<Space>e` — Toggle Neo-tree (`:Neotree toggle`)
- `<Space>o` — Focus Neo-tree (`:Neotree focus`)

#### Wyszukiwanie (Telescope)

- `<Space>ff` — Szukaj plików (Telescope `find_files`)
- `<Space>fg` — Live grep w projekcie (Telescope `live_grep`)

#### Zapisywanie i wychodzenie

- `<Space>w` — Zapisz plik (`:w`)
- `<Space>q` — Wyjdź (`:q`)
- `<Space>Q` — Wyjdź ze wszystkich bez zapisywania (`:qa!`)

#### Okna (splits)

- `<Space>sv` — Podziel pionowo (`:vsplit`)
- `<Space>sh` — Podziel poziomo (`:split`)
- `<Space>sc` — Zamknij obecny split (`:close`)

#### Formatowanie

- `<Space>cf` — Formatuj plik (conform.nvim)

#### LSP (aktywne gdy serwer LSP jest podłączony)

- `<Space>rn` — Rename symbol
- `<Space>ca` — Code action

---

#### AI Assistant (opencode.nvim)

- `<Space>oa` — Ask opencode o kod pod kursorem/zaznaczeniu (`@this`)
- `<Space>ox` — Wybierz akcję/prompt z listy (explain, fix, review, test...)
- `<Space>ot` — Toggle okno opencode (otwórz/zamknij terminal AI)

---

### Bez Leadera

#### LSP (aktywne gdy serwer LSP jest podłączony)

- `gd` — Go to definition
- `gD` — Go to declaration
- `gr` — Find references
- `gi` — Go to implementation
- `K` — Hover documentation
- `<C-k>` — Signature help
- `[d` — Previous diagnostic
- `]d` — Next diagnostic

---

#### Otwieranie linków

- `gx` — Otwórz link pod kursorem lub zaznaczenie (`:Browse`)
- `<C-LeftMouse>` — Otwórz link pod kursorem myszy (`:Browse`) w plikach tekstowych/Markdown; w pozostałych zachowuje domyślne skakanie po tagach

#### Wyrównywanie (mini.align)

- `ga` — Wyrównaj tekst (Normal: po ruchu/operatorze, Visual: na zaznaczeniu)

---

#### AI Assistant (opencode.nvim)

- `Shift+Ctrl+u` — Scroll opencode w górę (half page)
- `Shift+Ctrl+d` — Scroll opencode w dół (half page)

---

#### Surround (mini.surround)

- `gsa` — Dodaj otoczkę (Normal/Visual)
- `gsd` — Usuń otoczkę
- `gsr` — Zamień otoczkę
- `gsf` — Znajdź otoczkę
- `gsh` — Podświetl otoczkę
- `gsn` — Zmień zasięg szukania (`n_lines`)

#### Nawigacja między oknami

- `<C-h>` — Do lewego okna
- `<C-j>` — Do dolnego okna
- `<C-k>` — Do górnego okna
- `<C-l>` — Do prawego okna
- `<Tab>` — Cyklicznie do następnego okna
- `<S-Tab>` — Cyklicznie do poprzedniego okna

#### Zmiana rozmiaru okien

- `<C-Up>` — Zwiększ wysokość
- `<C-Down>` — Zmniejsz wysokość
- `<C-Left>` — Zmniejsz szerokość
- `<C-Right>` — Zwiększ szerokość

#### Numery linii

- `Ctrl+n Ctrl+n` — Cyklicznie przełącz numerację: wył. (chowa też signcolumn) → absolutna → relatywna

#### Wcięcia w Visual mode

- `<` — Wcięcie w lewo (i zachowaj zaznaczenie)
- `>` — Wcięcie w prawo (i zachowaj zaznaczenie)

#### Komentowanie

- `Ctrl+/` — Przełącz komentarz wiersza/zaznaczenia (Neovim 0.10+; terminal wysyła to jako `<C-_>`)

---

## 🛠️ Instalacja

```bash
# Backup starej konfiguracji (jeśli istnieje)
mv ~/.config/nvim ~/.config/nvim.backup
mv ~/.local/share/nvim ~/.local/share/nvim.backup

# Skopiuj tę konfigurację
cp -r ~/dotfiles/.config/nvim ~/.config/

# Uruchom Neovim - pluginy zainstalują się automatycznie
nvim
```

Przy pierwszym uruchomieniu:

1. `lazy.nvim` zainstaluje się automatycznie
2. Wszystkie pluginy zostaną zainstalowane
3. Po zakończeniu instalacji zrestartuj Neovim

## 📝 Dodawanie nowego pluginu

1. **Stwórz nowy plik** w `lua/plugins/nazwa.lua`:

   ```lua
   -- nazwa-pluginu - krótki opis
   return {
     "author/plugin-name",
     dependencies = { "other/plugin" },  -- opcjonalne
     opts = {},
     config = function()
       -- setup tutaj
     end,
   }
   ```

2. **Jeśli plugin ma keymaps**, dodaj je do `lua/config/keymaps.lua`

3. **Zaktualizuj ten README.md**:
   - Dodaj sekcję w "🔌 Pluginy i ich użycie"
   - Zaktualizuj "⌨️ Własne skróty klawiszowe"

4. **Zrestartuj Neovim** lub uruchom `:Lazy sync`

## 🔍 Troubleshooting

### Pluginy się nie instalują

```vim
:Lazy sync
```

### Copilot nie działa

```vim
:Copilot auth
```

### Kwadraty / brak ikon (Neo-tree, menu autouzupełniania)

- Zainstaluj [Nerd Font](https://www.nerdfonts.com/)
- Ustaw tę czcionkę w ustawieniach terminala i zrestartuj terminal.
- Uwaga: `mini.icons` zapewnia mapowania ikon dla pluginów, ale nie dostarcza glifów — te musi mieć czcionka terminala.

### Sprawdź health

```vim
:checkhealth
```

## 📚 Przydatne Linki

- [Lazy.nvim Docs](https://lazy.folke.io/)
- [Neovim Docs](https://neovim.io/doc/)
- [Which-key.nvim](https://github.com/folke/which-key.nvim)
- [Neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim)

---

**Tip**: Wciśnij `<Space>` i poczekaj chwilę - `which-key` pokaże wszystkie dostępne komendy! 🚀
