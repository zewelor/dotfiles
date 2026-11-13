# 🚀 Konfiguracja Neovim

Nowoczesna, modularna konfiguracja Neovim z [lazy.nvim](https://lazy.folke.io/) jako menedżerem pluginów.

**Wymaganie:** Neovim 0.11 lub nowszy. Konfiguracja korzysta wyłącznie z natywnego API LSP (`vim.lsp.config()` i `vim.lsp.enable()`).

## 📁 Struktura konfiguracji

```
.config/nvim/
├── README.md              # Dokumentacja konfiguracji
├── init.lua              # Entry point - ładuje wszystko
├── lua/
│   ├── config/
│   │   ├── lazy.lua     # Setup lazy.nvim
│   │   ├── options.lua  # Opcje edytora (vim.opt)
│   │   ├── keymaps.lua  # Wszystkie keybindings
│   │   ├── formatting.lua # Wspólna polityka formatowania projektu
│   │   └── profile.lua  # Jawny wybór profilu desktop
│   ├── plugins/         # Każdy plugin = osobny plik
│   │   ├── blink.lua                # Autouzupełnianie
│   │   ├── editorconfig.lua         # EditorConfig (auto-apply .editorconfig)
│   │   ├── gitsigns.lua             # Stage hunks / selected lines / blame
│   │   ├── conform.lua              # Autoformat (format-on-save)
│   │   ├── copilot.lua              # GitHub Copilot (lightweight inline suggestions)
│   │   ├── lsp.lua                  # LSP + mason (language servers)
│   │   ├── mason-tool-installer.lua # Auto-installer narzędzi (formattery)
│   │   ├── mini-align.lua           # Wyrównywanie tekstu
│   │   ├── mini-icons.lua           # Ikony plików
│   │   ├── mini-pairs.lua           # Autopairs
│   │   ├── mini-surround.lua        # Surround (gsa/gsd/gsr)
│   │   ├── neotree.lua              # File explorer
│   │   ├── opencode.lua             # AI Assistant (opencode.nvim)
│   │   ├── snacks.lua               # Utility modules
│   │   ├── telescope.lua            # Wyszukiwanie i fuzzy finder
│   │   ├── treesitter.lua           # Tree-sitter (Neovim 0.11+)
│   │   ├── ts-comments.lua          # Commentstring dla natywnego gc/gcc
│   │   ├── catppuccin.lua           # Motyw kolorów
│   │   └── which-key.lua            # Podpowiedzi skrótów
├── ftdetect/
│   ├── just.lua          # Filetype detection dla Justfile
│   └── sshconfig.lua     # Filetype detection dla ~/.ssh/config.d/*
└── after/
    └── ftplugin/
        ├── dockerfile.lua # Nadpisy dla Dockerfile (RUN: 4 + shell blok: +2)
        ├── go.lua         # Nadpisy dla Go
        ├── just.lua       # Commentstring (#) dla Justfile
        ├── markdown.lua   # Nadpisy dla Markdown (2 spacje + wrap)
        └── tmuxinator.lua # Nadpisy dla tmuxinator
```

`lazy-lock.json` jest stanem lokalnym maszyny i znajduje się w katalogu
`stdpath("state")` Neovima (zwykle `~/.local/state/nvim/`). Aktualizacje
pluginów nie zmieniają dzięki temu repozytorium dotfiles.

`update-all` przekazuje Neovimowi profil zapisany w `~/.zshrc.d/profile.zsh`
użytkownika docelowego (domyślnie `server`, gdy pliku brak).

Pełny zestaw deweloperski jest włączany tylko przez
`DOTFILES_PROFILE=desktop` (warunek `config.profile.is_desktop()`): Mason, LSP, `conform.nvim`, auto-installer
formatterów oraz integracje Copilot i OpenCode wraz z ich skrótami.
Profil `server` i brak profilu korzystają z uproszczonego trybu, również gdy
`mise` jest dostępne w `PATH`. Instalacja mise dla pojedynczego CLI nie
włącza narzędzi deweloperskich edytora.

Desktop nie wymaga mise do uruchomienia Masona i pozostałych LSP. Wyjątkiem
jest Ruby LSP: startuje tylko wtedy, gdy mise jest dostępne i potrafi rozwiązać
`ruby-lsp`. Copilot nadal wymaga Node.js 22+, a OpenCode swojego CLI.

Profil `server` nie ładuje `nvim-treesitter` ani `telescope-fzf-native`, nawet
gdy kompilator jest dostępny. Korzysta ze standardowego podświetlania składni
i sortera Telescope, bez kompilacji parserów i natywnego rozszerzenia FZF.
Te dodatki są włączane tylko przy `DOTFILES_PROFILE=desktop`; brak tej zmiennej
oznacza lekki wariant, tak jak domyślny profil shella. Reguła jest niezależna
od obecności `mise`.

## ⚙️ Core Options

Główne opcje edytora (z `lua/config/options.lua`):

| Opcja | Wartość | Opis |
|-------|---------|------|
| `number` | true | Numery linii |
| `relativenumber` | true | Relatywne numery (do nawigacji) |
| `smartindent` | true | Inteligentne wcięcia |
| `wrap` | false | Bez zawijania długich linii |
| `ignorecase` | true | Ignoruj wielkość liter w wyszukiwaniu |
| `smartcase` | true | ...chyba że wpiszesz wielką literę |
| `termguicolors` | true | True color support |
| `clipboard` | "" | Clipboard systemowy nie jest domyślnym rejestrem; tylko świadome yankowanie (`y`) kopiuje do `+` |
| `undofile` | true | Trwałe undo (po zamknięciu pliku) |
| `mouse` | "" | Wyłączona obsługa myszy |

**Indent settings** (`expandtab`, `tabstop`, `shiftwidth`) są zarządzane przez `.editorconfig` via plugin `editorconfig-vim`. Plik `.editorconfig` znajduje się w `~/dotfiles/.editorconfig` i jest linkowany do `~/.editorconfig` przez stow.

**Clipboard**: konfiguracja emuluje zachowanie SmartYank bez osobnego pluginu. Operacje `delete`/`change` nie nadpisują systemowego schowka, a `TextYankPost` kopiuje do rejestru `+` tylko przy operatorze `y`. W sesji SSH Neovim wymusza wbudowany provider `osc52`, żeby yank mógł trafić do lokalnego schowka terminala także wtedy, gdy autodetekcja zawodzi pod tmuxem.

## 📁 Nadpisy per Filetype

Specyficzne ustawienia dla konkretnych typów plików (w `after/ftplugin/` + `ftdetect/`):

| Język | Plik | Opis nadpisu |
|-------|------|--------------|
| **Markdown** | `markdown.lua` | `wrap`, `linebreak`, `breakindent` (indent zarządzany przez `.editorconfig`) |
| **Dockerfile** | `dockerfile.lua` | Custom indent logic dla kontynuacji `RUN` oraz bloków shell (`if/for/while/case`); basic indent (4 spacje) zarządzany przez `.editorconfig` |
| **Just** | `just.lua` | `commentstring = "# %s"` + `ts-comments.nvim` (ftdetect w `ftdetect/just.lua`) |
| **SSH config** | `sshconfig.lua` | Ustawia `filetype=sshconfig` dla fragmentów `~/.ssh/config.d/*`, żeby działały builtinowe komentarze (`# %s`) |

## 🔌 Pluginy i ich użycie

### **lazy.nvim** — Plugin Manager

- **Repo**: [folke/lazy.nvim](https://github.com/folke/lazy.nvim)
- **Cel**: Nowoczesny, szybki menedżer pluginów
- **Auto-instalacja**: Instaluje się automatycznie przy pierwszym uruchomieniu
- **Keymaps**:
  - `:Lazy` — Otwórz UI managera
  - `:Lazy sync` — Synchronizuj pluginy (install/update/clean)

---

### **gitsigns.nvim** — Stage hunks i blame w buforze

- **Repo**: [lewis6991/gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim)
- **Cel**: Git diff w gutterze, stage/reset hunks i podgląd blame bez wychodzenia z Neovim
- **Keymaps**:
  - `<Space>hs` — Stage hunk pod kursorem
  - `<Space>hs` w Visual — Stage zaznaczone linie z aktualnego hunk'a
  - `<Space>hS` — Stage cały bufor
- **Uwagi**: Plugin korzysta z `signcolumn`, więc `vim.opt.signcolumn = "yes"` zostaje w core options.
- **Przykłady**:
  - Chcesz stage'ować tylko 2 linie z większego hunka: zaznacz je w Visual mode i naciśnij `<Space>hs`.
  - Chcesz stage'ować cały obecny change set w pliku: naciśnij `<Space>hs` w Normal mode.
  - Chcesz ogarnąć commit/branch/stash dla całego repo: `<leader>gg` otwiera LazyGit (floating window przez snacks.nvim).

### Gdy używać czego

- `gitsigns` — gdy pracujesz na fragmencie pliku i chcesz stage'ować tylko wybrane linie/hunki.
- `LazyGit` (`<leader>gg`) — gdy chcesz zrobić commit, przełączyć branch, stash albo ogarnąć stan całego repo.

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
- **Dodatkowe info**: Automatycznie używa `fd` jeśli dostępne. Rozszerzenie `telescope-fzf-native` ładuje tylko w profilu `desktop`, gdy dostępne jest `make`; jego budowanie wymaga kompilatora C. Profil `server` używa standardowego sortera.

---

### **which-key.nvim** — Podpowiedzi Keybindingów

- **Repo**: [folke/which-key.nvim](https://github.com/folke/which-key.nvim)
- **Cel**: Wyświetla popup z dostępnymi skrótami po wciśnięciu `<Space>`
- **Użycie**: Wciśnij `<Space>` i poczekaj ~300ms → zobaczysz listę dostępnych komend

---

### **blink.cmp** — Autouzupełnianie

- **Repo**: [saghen/blink.cmp](https://github.com/saghen/blink.cmp)
- **Cel**: Szybkie, nowoczesne autouzupełnianie kodu
- **Źródła**: `lsp`, `path`, `snippets` oraz `buffer` jako fallback, więc słowa z otwartych buforów pojawiają się dopiero wtedy, gdy LSP nie zwróci sensownych podpowiedzi. Copilot nie jest podpięty jako źródło `blink.cmp`, żeby autouzupełnianie zostało lekkie.
- **Keymaps** (w menu autouzupełniania):
  - `<C-Space>` — Wymuś pokazanie menu
  - `<CR>` — Potwierdź wybór
  - `<C-e>` — Anuluj
  - `<Tab>` / `<S-Tab>` — Nawigacja w menu

---

### **copilot.lua** — GitHub Copilot (lightweight inline suggestions)

- **Repo**: [zbirenbaum/copilot.lua](https://github.com/zbirenbaum/copilot.lua)
- **Cel**: Lżejsza integracja GitHub Copilot przez natywny klient LSP Neovima, bez źródła `blink.cmp`.
- **Tryb pracy**: Auto-sugestie są włączone dla zwykłych plików kodu, ale z opóźnieniem `500ms`; panel, `blink.cmp` source i next-edit suggestions są wyłączone.
- **Wyłączone filetype'y**: `markdown`, `text`, `yaml`, `gitcommit`, `gitrebase`, `help`.
- **Wyłączone pliki**: `.env` i warianty `.env.*`, np. `.env.local` oraz `.env.production`.
- **Wymagania**: Neovim 0.11+ i Node.js 22+.
- **Profil**: Tylko `desktop`; na `server` i bez profilu plugin oraz jego skróty są wyłączone.
- **Keymaps**:
  - `<M-]>` w Insert — Pobierz / pokaż następną sugestię
  - `<M-[>` w Insert — Poprzednia sugestia
  - `<M-l>` w Insert — Akceptuj sugestię
  - `<C-]>` w Insert — Odrzuć sugestię
  - `<Space>ct` — Przełącz auto-trigger dla bieżącego bufora
- **Komendy**:
  - `:Copilot auth` — Zaloguj Copilot
  - `:Copilot status` — Sprawdź status

---

### **opencode.nvim** — AI Assistant (opencode)

- **Repo**: [nickjvandyke/opencode.nvim](https://github.com/nickjvandyke/opencode.nvim)
- **Cel**: Integracja z opencode AI assistant — edytorowo-świadome research, review i requesty
- **Wymagania**: Zainstalowany `opencode` CLI (patrz sekcja "Instalacja opencode CLI" poniżej)
- **Profil**: Tylko `desktop`; na `server` i bez profilu plugin oraz jego skróty są wyłączone.
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

# Lub z repozytorium dotfiles przez mise
cd ~/dotfiles && mise install opencode
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
- **Zapis i `<Space>cf`** korzystają z jednej polityki. Dla YAML (również obecnych podtypów), JS/TS/React, JSON/JSONC/JSON5, CSS, GraphQL i Markdown najbliższa konfiguracja dprint decyduje, czy plugin obsługuje plik. Samo istnienie konfiguracji nie wystarcza. Wspierane nazwy to `dprint.json`, `dprint.jsonc`, `.dprint.json`, `.dprint.jsonc` i warianty `.config/dprint.json(c)`.
- **Dprint 0.64.3+**: wybrana binarka jest sprawdzana przed użyciem. `resolved-config --file` rozpoznaje obsługę pliku, a `fmt --stdin` z pełną ścieżką respektuje `includes`, `excludes` i `.gitignore`. Wykluczone pliki pozostają bez zmian. Brak pluginu, również przez negatywne `associations`, pozwala użyć formattera domyślnego; Markdown bez pluginu jest pomijany.
- **Wybór binarki**: istniejące lokalne `node_modules/.bin/dprint`, następnie efektywna deklaracja mise w katalogu bufora (także globalna), a Mason dopiero po potwierdzonym braku deklaracji. Niezainstalowana lub niejednoznaczna deklaracja mise oraz brak resolvera są błędem, bez przejścia na inną wersję. Nie walidujemy manifestów ani lockfile npm. Zapytania mise pomijają odziedziczone `MISE_DPRINT_VERSION`, zachowując resztę środowiska i reguły zaufania. Narzędzia nie są instalowane przy formatowaniu.
- **Domyślne formatery**: Lua przez `stylua`, Python przez `ruff_format`, TOML przez `taplo`, Go przez `goimports` i `gofumpt`, sh/bash przez `shfmt`, Zsh przez `beautysh`, YAML przez `yamlfmt`, JS/TS/JSON/CSS/GraphQL przez `oxfmt`. Ruby zachowuje reguły opisane poniżej.
- **Wyłączenia**: Dockerfile bez autoformatowania przy zapisie; `eruby.yaml.tmuxinator` bez formatowania również ręcznie. Nienazwany bufor z grupy projektowej wymaga najpierw nadania nazwy.
- **Błędy i czas**: jeden synchroniczny budżet 2000 ms obejmuje rozwiązywanie narzędzia i formatowanie. Błąd konfiguracji, brak wymaganej wersji i timeout są widoczne; wybrany dprint nie przechodzi na inny formatter ani LSP. Błąd nie blokuje zapisu pracy. Brak projektowego kontraktu zachowuje dotychczasowy fallback LSP.
- **Ruby**: dla projektów RuboCop conform uruchamia repo-local `bin/rubocop`, jeśli istnieje; w przeciwnym razie używa dostępnego `rubocop`. Cache RuboCopa trafia do `tmp/rubocop`.
- **Diagnostyka**: `:FormatInfo` pokazuje bieżącą decyzję, źródło binarki, wersję, konfigurację i cwd, bez formatowania. `:ConformInfo` pozostaje informacją o dostępności domyślnych narzędzi i logach; nie odtwarza ostatniego wyboru projektowego. Brak domyślnego formattera nadal nie pokazuje popupu.
- **Keymaps**:
  - `<Space>cf` — Format buffer

#### Potwierdzona zgodność dprint — 2026-11-13

Sprawdzony zestaw to **dprint 0.64.3 + pretty_yaml 0.6.0**, Neovim 0.11.6,
Conform `016802d` i mise 2026.11.7. W R3X deklaracja pozostaje `latest`,
która w tym sprawdzeniu wybierała zainstalowane 0.64.3. To punkt kontrolny
zgodności, a nie przypięcie wersji projektu ani gwarancja dla przyszłego `latest`.

Testy Neovima przeszły **11/11**, w tym test rzeczywistego CLI i pluginu YAML.
Osobna próba modułu z prawdziwym mise i konfiguracją R3X potwierdziła wybór
0.64.3, formatowanie nowego bufora YAML przed pierwszym zapisem, zachowanie
wykluczeń `workflows/` i `config/database.yml` oraz domyślny plan dla JSON bez
obsługującego go pluginu. Próby ładowały moduł z repo i nie zapisywały plików
R3X; nie zastępują podlinkowania nowego modułu i odbioru zwykłej sesji edytora.

Po aktualizacji CLI lub pluginu można powtórzyć [testy formatowania](../../tests/nvim_formatting_test.py)
z lokalnymi, rzeczywistymi plikami:

```sh
DOTFILES_TEST_DPRINT=/path/to/dprint \
DOTFILES_TEST_DPRINT_PLUGIN=/path/to/pretty_yaml-v0.6.0.wasm \
PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 -m unittest discover -s tests -p 'nvim*_test.py' -v
```

Polecenie uruchamiaj z katalogu głównego dotfiles. Bez obu zmiennych test
rzeczywistego CLI jest pomijany. Testy nie pobierają narzędzi ani pluginów;
poprawny wynik testów z atrapami sam nie potwierdza zgodności nowej wersji.

---

### **mason-tool-installer.nvim** — Auto-instalacja narzędzi

- **Repo**: [WhoIsSethDaniel/mason-tool-installer.nvim](https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim)
- **Cel**: Automatycznie instaluje formatery używane przez conform (`stylua`, `shfmt`, `beautysh`, `ruff`, `taplo`, `oxfmt`, `dprint`, `yamlfmt`, `rubyfmt`, `goimports`, `gofumpt`), LSPs (`gopls`) i np. `hadolint`. `rubyfmt` zostaje fallbackiem dla Ruby poza projektami RuboCop.

---

### **mini.icons** — Ikony Plików

- **Repo**: [nvim-mini/mini.icons](https://github.com/nvim-mini/mini.icons)
- **Cel**: Ikony plików dla Neo-tree i pluginów (mock `nvim-web-devicons`)
- **Uwaga**: To nie zastępuje czcionki w terminalu. Aby uniknąć "kwadratów" także w menu autouzupełniania i innych miejscach, ustaw w terminalu czcionkę z ikonami

---

### **catppuccin** — Motyw Kolorów

- **Repo**: [catppuccin/nvim](https://github.com/catppuccin/nvim)
- **Cel**: Soothing pastel theme dla Neovim
- **Aktywny**: `catppuccin` z flavour `latte`, transparentne tło (dopasowane do terminala)
- **Zmiana**: Edytuj `lua/plugins/catppuccin.lua`

---

### **nvim-treesitter** — Lepszy Syntax Highlighting

- **Repo**: [nvim-treesitter/nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
- **Cel**: Parsowanie kodu drzewem składni dla lepszego podświetlania i wcięć
- **Wymagania**: Neovim 0.11+.
- **Profil**: Tylko `DOTFILES_PROFILE=desktop`. Na `server` i bez ustawionego profilu plugin oraz jego build `:TSUpdate` są wyłączone.
- **Auto-install**: Brakujące parsery (lua, vim, bash, python, json, yaml, toml, markdown, dockerfile, git, helm, go) są instalowane automatycznie przy pierwszym starcie. Wymaga kompilacji (gcc/clang).
- **Komendy**:
  - `:TSUpdate` — Zaktualizuj wszystkie parsery
  - `:TSInstall <lang>` — Zainstaluj parser dla języka

---

### **ts-comments.nvim** — Commentstring dla natywnego komentowania

- **Repo**: [folke/ts-comments.nvim](https://github.com/folke/ts-comments.nvim)
- **Cel**: Ustawia poprawny `commentstring` dla wbudowanego `gc` / `gcc`, także dla `Justfile` i innych filetype opartych o tree-sitter
- **Dodatkowe**: Nie zastępuje natywnego komentowania Neovima, tylko je uzupełnia

---

### **LSP** — Language Server Protocol

Zestaw pluginów do inteligentnego uzupełniania i nawigacji po kodzie:

- **mason.nvim**: [williamboman/mason.nvim](https://github.com/williamboman/mason.nvim) — Menedżer serwerów LSP
- **mason-lspconfig.nvim**: [williamboman/mason-lspconfig.nvim](https://github.com/williamboman/mason-lspconfig.nvim) — Bridge mason ↔ lspconfig
- **nvim-lspconfig**: [neovim/nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) — Konfiguracja LSP

**Zainstalowane serwery**:
- `lua_ls` — Lua (konfiguracja Neovim)
- `helm_ls` — Helm charts
- `ruff` — Python (lightweight LSP + linter + formatter)
- `taplo` — TOML (lekki skompilowany LSP + formatter)
- `marksman` — Markdown
- `gopls` — Go
- `ruby_lsp` — Ruby (via `mise` + `gem:ruby-lsp`)

**Konfiguracja API**:
- **Neovim 0.11+**: używa natywnego `vim.lsp.config()` + `vim.lsp.enable()`; `mason-lspconfig` automatycznie włącza serwery Masona.
- **Jawna lista**: `mason_servers` w `lua/plugins/lsp.lua` jest wspólną listą instalacji, konfiguracji i aktywacji LSP Masona. Wcześniej zainstalowane serwery spoza tej listy nie są automatycznie włączane; ich pliki pozostają na dysku.
- **Neovim <0.11**: niewspierany — konfiguracja kończy działanie z czytelnym komunikatem o wymaganej wersji.
- **Ruby**: ścieżka do `ruby-lsp` jest rozwiązywana dynamicznie przez `mise which`; standalone `mise` jest dostępne z `.zshenv`, bez `mise activate` i hooków zmiany katalogu. Jeśli `mise` nie rozwiąże `ruby-lsp`, klient nie startuje zamiast używać potencjalnie przestarzałego wrappera Masona z `$PATH`. Ruby LSP startuje bez `bundle exec`, bo sam używa composed bundle i nie wymaga `ruby-lsp` w Gemfile projektu. W projektach z RuboCopem Ruby LSP aktywuje RuboCop addon, więc nie startujemy osobnego klienta `rubocop`.

**Komendy**:
- `:Mason` — UI menedżera serwerów
- `:MasonInstall <server>` — Zainstaluj serwer
- `:LspInfo` — Info o aktywnych serwerach

**Opcjonalny cleanup — usuń nieużywane serwery z Masona** (nie jest wymagany do ich wyłączenia):
```vim
:MasonUninstall basedpyright jsonls yamlls bashls dockerls docker_compose_language_service
```

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

#### Copilot

- `<Space>ct` — Przełącz auto-trigger dla bieżącego bufora

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

#### Copilot

- `Alt+]` w Insert — Pobierz / pokaż następną sugestię
- `Alt+[` w Insert — Poprzednia sugestia
- `Alt+l` w Insert — Akceptuj sugestię
- `Ctrl+]` w Insert — Odrzuć sugestię

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

#### Zawieszanie procesu

- `<C-z>` — **Wyłączone** w Neovim (zablokowane w `keymaps.lua`; w zsh też wyłączone przez `stty susp undef` w `.zshrc`)

#### Komentowanie

- `Ctrl+/` — Przełącz komentarz wiersza/zaznaczenia (Neovim 0.10+; terminal wysyła to jako `<C-_>`)
- `gc` / `gcc` — Natywne komentowanie Neovima z `commentstring` uzupełnianym przez `ts-comments.nvim`

---

## 🛠️ Instalacja

```bash
# Przejdź do repozytorium dotfiles
cd ~/dotfiles

# Najpierw sprawdź planowane linki
stow -n -v -d .config -t ~/.config nvim

# Zastosuj linkowanie konfiguracji przez GNU Stow
stow -v -d .config -t ~/.config nvim

# Uruchom Neovim - brakujące pluginy zainstalują się automatycznie
nvim
```

Pełny `./install` linkuje konfigurację, ale nie instaluje ani nie aktualizuje
pluginów Neovima. Robi to lazy.nvim przy pierwszym uruchomieniu edytora.

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

### Przywrócenie lokalnych wersji pluginów

```vim
:Lazy restore
```

Polecenie korzysta z lokalnego lockfile'a tej maszyny; jego wersje nie są
synchronizowane przez repozytorium dotfiles.

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
