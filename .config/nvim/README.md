# 🚀 Konfiguracja Neovim

Nowoczesna, modularna konfiguracja Neovim z [lazy.nvim](https://lazy.folke.io/) jako menedżerem pluginów.

**Wymaganie:** Neovim 0.11.3 lub nowszy (minimum nvim-lspconfig). Konfiguracja korzysta wyłącznie z natywnego API LSP (`vim.lsp.config()` i `vim.lsp.enable()`).

## 📁 Struktura konfiguracji

```
.config/nvim/
├── README.md              # Dokumentacja konfiguracji
├── init.lua              # Entry point - ładuje wszystko
├── maintain.lua          # Jawne headless utrzymanie pluginów
├── LICENSE.fileline      # Licencja lokalnej adaptacji fileline.nvim
├── lua/
│   ├── config/
│   │   ├── lazy.lua     # Setup lazy.nvim
│   │   ├── options.lua  # Opcje edytora (vim.opt)
│   │   ├── keymaps.lua  # Wszystkie keybindings
│   │   ├── fileline.lua # Otwieranie istniejącego pliku przez plik:linia
│   │   └── profile.lua  # Jawny wybór profilu desktop
│   ├── plugins/         # Każdy plugin = osobny plik
│   │   ├── blink.lua                # Autouzupełnianie
│   │   ├── gitsigns.lua             # Stage hunks / selected lines / blame
│   │   ├── conform.lua              # Ręczne formatowanie
│   │   ├── lsp.lua                  # Natywny LSP; narzędzia zarządzane przez mise
│   │   ├── mini-align.lua           # Wyrównywanie tekstu
│   │   ├── mini-icons.lua           # Ikony plików
│   │   ├── mini-pairs.lua           # Autopairs
│   │   ├── mini-surround.lua        # Surround (gsa/gsd/gsr)
│   │   ├── neotree.lua              # File explorer
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
        ├── go.lua         # Nadpisy dla Go
        ├── just.lua       # Commentstring (#) dla Justfile
        ├── markdown.lua   # Nadpisy dla Markdown (2 spacje + wrap)
        └── tmuxinator.lua # Nadpisy dla tmuxinator
```

`lazy-lock.json` jest stanem lokalnym maszyny i znajduje się w katalogu
`stdpath("state")` Neovima (zwykle `~/.local/state/nvim/`). Aktualizacje
pluginów nie zmieniają dzięki temu repozytorium dotfiles.

Instalator bazowy linkuje cały katalog `~/.config/nvim` do tej konfiguracji.
Nowe moduły są widoczne od razu; ponowne linkowanie przez Stow nie jest potrzebne.
To jawny wyjątek od `--no-folding`: katalog zawiera wyłącznie konfigurację,
a utrzymywany stan Neovima pozostaje w katalogach danych i stanu.
[Uzasadnienie i migracja starszych instalacji](../../docs/config-directory-links.md).

`update-all` przekazuje Neovimowi profil zapisany w `~/.zshrc.d/profile.zsh`
użytkownika docelowego (domyślnie `server`, gdy pliku brak).

Pełny zestaw deweloperski jest włączany tylko przez
`DOTFILES_PROFILE=desktop` (warunek `config.profile.is_desktop()`): natywny LSP,
`conform.nvim`.
Formatery korzystają z przygotowanego `PATH`. Dprint sam wybiera konfigurację
projektu, a przy jej braku globalny plugin Oxc WASM. Profil `server` i brak
profilu zachowują lekki edytor, bez formatterów i LSP; obecność mise nie włącza
narzędzi edytora.

Desktop wymaga mise i konfiguracji z zadeklarowanymi narzędziami. Dprint i jego
plugin Oxc WASM nie wymagają Node.js ani npm. Pluginy kompilowane lokalnie
nadal wymagają make i kompilatora C.

Profil `server` nie ładuje `nvim-treesitter` ani `telescope-fzf-native`, nawet
gdy kompilator jest dostępny. Korzysta ze standardowego podświetlania składni
i sortera Telescope, bez kompilacji parserów i natywnego rozszerzenia FZF.
Te dodatki są włączane tylko przy `DOTFILES_PROFILE=desktop`; brak tej zmiennej
oznacza lekki wariant, tak jak domyślny profil shella. Reguła jest niezależna
od obecności `mise`.

Neovim ustawia `MISE_AUTO_INSTALL=false` przed załadowaniem pluginów.
Dotyczy to wszystkich profili i procesów potomnych, także `:terminal`.
Brakujące narzędzia mise wymagają jawnego przygotowania; `mise install`
pozostaje dostępne. Instalację narzędzi desktopu przygotowuje
`make install-neovim`, a aktualizację wykonuje `update-all`.

## Otwieranie pliku na konkretnej linii

```sh
nvim plik.lua:12
nvim plik.lua:1-60
nvim 'katalog ze spacjami/plik.lua:12'
```

W edytorze działają również `:e plik.lua:12` i `:e plik.lua:1-60`. Lokalny moduł
`lua/config/fileline.lua` obsługuje formaty `plik:linia` i `plik:początek-koniec`
dla istniejącego, czytelnego pliku, w obu profilach. Zakres otwiera plik na
pierwszej wskazanej linii, bez zaznaczania tekstu. Linia `0` oznacza pierwszą,
a numer większy od długości pliku wskazuje ostatnią linię. Rzeczywisty plik
o nazwie np. `plik.lua:12` lub `plik.lua:1-60` ma pierwszeństwo. Brak pliku
bazowego pozostawia zwykły nowy bufor z pełną nazwą; sufiksy kolumn i nawiasy
nie mają osobnej obsługi.
Odwołania z pozycją nie obsługują wielu splitów tworzonych przy starcie
przez `-o`/`-O`; w tym przypadku użyj natywnego `+linia plik`.

To uproszczona lokalna adaptacja
[fileline.nvim](https://github.com/lewis6991/fileline.nvim/tree/c116aa8dd7aa7e1db6938f872285e598dc9ee00b)
na licencji MIT (`LICENSE.fileline`). Nie jest pobierana ani aktualizowana przez
menedżer pluginów; zmiany tego kodu przechodzą przez repozytorium dotfiles.

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
| `autoread` | true | Przeładuj niezmodyfikowany bufor po wykryciu zewnętrznej zmiany |
| `mouse` | "" | Wyłączona obsługa myszy |

`autoread` działa niezależnie od pluginów agentów. `:checktime` jawnie sprawdza zewnętrzne zmiany; lokalnie zmodyfikowany bufor wymaga rozstrzygnięcia przez użytkownika.

**Indent settings** (`expandtab`, `tabstop`, `shiftwidth`) są zarządzane przez wbudowaną obsługę `.editorconfig` w Neovimie. Plik `.editorconfig` znajduje się w `~/dotfiles/.editorconfig` i jest linkowany do `~/.editorconfig` przez stow.

**Clipboard**: konfiguracja emuluje zachowanie SmartYank bez osobnego pluginu. Operacje `delete`/`change` nie nadpisują systemowego schowka, a `TextYankPost` kopiuje do rejestru `+` tylko przy operatorze `y`. W sesji SSH Neovim wymusza wbudowany provider `osc52`, żeby yank mógł trafić do lokalnego schowka terminala także wtedy, gdy autodetekcja zawodzi pod tmuxem.

## 📁 Nadpisy per Filetype

Specyficzne ustawienia dla konkretnych typów plików (w `after/ftplugin/` + `ftdetect/`):

| Język | Plik | Opis nadpisu |
|-------|------|--------------|
| **Markdown** | `markdown.lua` | `wrap`, `linebreak`, `breakindent` (indent zarządzany przez `.editorconfig`) |
| **Just** | `just.lua` | `commentstring = "# %s"` + `ts-comments.nvim` (ftdetect w `ftdetect/just.lua`) |
| **SSH config** | `sshconfig.lua` | Ustawia `filetype=sshconfig` dla fragmentów `~/.ssh/config.d/*`, żeby działały builtinowe komentarze (`# %s`) |

Dockerfile używa standardowych wcięć Neovima zamiast własnego parsera bloków
shellowych w `RUN`. Rozpoznawanie `fdockerfile` i wariantów oraz wcięcia z
`.editorconfig` pozostają aktywne. Na desktopie `<Space>cf` formatuje cały bufor
przez `dockerfmt`, w tym shell wewnątrz `RUN`. Formatowanie przy zapisie jest
domyślnie wyłączone. Ręczne formatowanie nie zapisuje pliku automatycznie.

Dockerfmt jest gotową binarką zarządzaną przez mise i korzysta z wbudowanego
adaptera Conforma. Przy wejściu przez stdin dostaje szerokość wcięcia i wybór
tabów z bufora. Może modernizować zapisy, np. `MAINTAINER` na `LABEL`;
przejrzyj wynik przed zapisem. Brak narzędzia lub błąd nie przełącza formatowania
na LSP. Instalacja narzędzi desktopu i `update-all` obejmują też dockerfmt;
`bin/update-shell-completions` odświeża jego statyczne uzupełnianie Zsh.

## 🔌 Pluginy i ich użycie

### **lazy.nvim** — Plugin Manager

- **Repo**: [folke/lazy.nvim](https://github.com/folke/lazy.nvim)
- **Cel**: Nowoczesny, szybki menedżer pluginów
- **Instalacja braków**: Zwykły start pobiera brakujący manager i brakujące pluginy. Już zainstalowanych pluginów nie aktualizuje; nowe wersje wdrażamy jawnie przez `update-all` lub `:Lazy update`.
- **Aktualizacje**: Lazy nie sprawdza ich okresowo w tle. Sprawdzaj je jawnie przez `:Lazy check`; aktualizacje wykonuje `update-all` albo świadome `:Lazy update`.
- **Keymaps**:
  - `:Lazy` — Otwórz UI managera
  - `:Lazy sync` — Synchronizuj pluginy (install/update/clean)

---

### **gitsigns.nvim** — Stage hunks i blame w buforze

- **Repo**: [lewis6991/gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim)
- **Cel**: Git diff w gutterze, stage/reset hunks i podgląd blame bez wychodzenia z Neovim
- **Keymaps**:
  - `<Space>ghs` — Stage hunk pod kursorem
  - `<Space>ghs` w Visual — Stage zaznaczone linie z aktualnego hunk'a
  - `<Space>ghS` — Stage cały bufor
  - `<Space>ghd` — Diff bieżącego bufora z aktualną bazą Gitsigns (domyślnie indeks).
    Zapis bufora indeksu aktualizuje staged.
  - `<Space>ghD` — Diff bieżącego bufora z ostatnim commitem (`HEAD`).
- **Uwagi**: Plugin korzysta z `signcolumn`, więc `vim.opt.signcolumn = "yes"` zostaje w core options.
- **Przykłady**:
  - Chcesz stage'ować tylko 2 linie z większego hunka: zaznacz je w Visual mode i naciśnij `<Space>ghs`.
  - Chcesz dodać do indeksu wszystkie zmiany w bieżącym buforze: naciśnij `<Space>ghS` w Normal mode.
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

Integracje Copilot i OpenCode w edytorze są wycofane. Zewnętrzne CLI agentów pozostają niezależne; źródła podpowiedzi Blinka pozostają bez zmian.

- **Repo**: [saghen/blink.cmp](https://github.com/saghen/blink.cmp)
- **Cel**: Szybkie, nowoczesne autouzupełnianie kodu
- **Dopasowanie**: `prefer_rust_with_warning` preferuje Rust i pozwala Blinkowi pobrać gotową bibliotekę bez kompilatora Rust. Gdy biblioteka jest niedostępna, Blink ostrzega i używa Lua.
- **Źródła**: `lsp`, `path`, `snippets` oraz `buffer` jako fallback, więc słowa z otwartych buforów pojawiają się dopiero wtedy, gdy LSP nie zwróci sensownych podpowiedzi.
- **Keymaps** (preset `enter`, `preselect = false`, podczas wpisywania):
  - `<C-Space>` — Pokaż menu; przy otwartym menu pokaż/ukryj dokumentację
  - `<Enter>` — Zatwierdź wskazaną podpowiedź; bez wskazanej pozycji wstaw nowy wiersz
  - `<Tab>` — Przejdź dalej w snippet lub wykonaj zwykły Tab
  - `<S-Tab>` — Poprzednie pole snippet; poza snippet zwykłe działanie klawisza
  - `<Up>` / `<C-p>` — Poprzednia podpowiedź
  - `<Down>` / `<C-n>` — Następna podpowiedź
  - `<C-e>` — Anuluj

Menu nie zaznacza pierwszej podpowiedzi automatycznie. Wskaż ją strzałkami lub
`<C-n>`/`<C-p>`, a potem zatwierdź Enterem.

W wierszu poleceń `:` menu otwiera się od razu, bez zaznaczenia pierwszej
pozycji. Strzałki góra/dół wybierają pozycję przy otwartym menu, a po jego
zamknięciu wracają do historii komend. Strzałki lewo/prawo przesuwają kursor.
Enter wykonuje tekst wiersza poleceń.

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

### **conform.nvim** — Ręczne formatowanie

Conform ładuje się przy pierwszym `<Space>cf`, `<Space>uf` lub `:ConformInfo`.

**Formatowanie przy zapisie jest domyślnie wyłączone.** `<Space>cf` wywołuje Conform synchronicznie,
z limitem 2 sekund, bez formatowania przez LSP. Zmienia bufor; zapis i staging
pozostają oddzielnymi, świadomymi krokami. `:ConformInfo` pokazuje narzędzia i błędy.

`<Space>uf` włącza lub wyłącza formatowanie przed zapisem bieżącego bufora
i pokazuje stan w powiadomieniu. Ustawienie znika po usunięciu bufora lub
zamknięciu Neovima.

| Pliki | Formatter |
|---|---|
| Lua | StyLua |
| Python | Ruff |
| TOML | Taplo |
| Go | goimports, następnie gofumpt |
| sh/bash/Zsh | shfmt (Zsh wymaga 3.13.1+ i dostaje `-ln zsh`) |
| YAML, JS/TS/React, JSON/JSONC/JSON5, CSS, GraphQL, Markdown | dprint: konfiguracja projektu, a przy jej braku globalny plugin Oxc |
| Dockerfile, fdockerfile i warianty | dockerfmt |
| Ruby, ERB | brak formattera |

Zasada: **konfiguracja projektu ma pierwszeństwo; poza nią dprint używa
globalnego pluginu Oxc (silnika Oxfmt) w WASM, bez Node.js**.
Mise przygotowuje binarki, a Neovim uruchamia je z `PATH`.

Dprint używa reguł repo (`dprint.json`, `dprint.jsonc`, warianty z kropką oraz
`.config/dprint.json(c)`). Binarka pochodzi z `PATH`, zwykle z mise. Nie ma
specjalnego wyboru wrapperów `.dev/bin`, odpytywania mise o wersje ani inspekcji
pluginów dprint przed każdym formatowaniem. Przy konfiguracji dprint to dprint
rozstrzyga obsługę i wykluczenia plików. Brak binarki, błędna konfiguracja lub
nieobsługiwany typ nie przełączają formatowania na inny program. Konfiguracja
globalna nie uzupełnia brakujących pluginów projektu. Dostępne formatery sprawdzisz przez
`:ConformInfo`.

Conform przekazuje niezapisany bufor i oryginalną ścieżkę przez stdin. Nie tworzy
plików tymczasowych obok źródła. Błąd pozostawia bufor bez zmian, bez przejścia
na LSP. Nie utrzymujemy osobnych binarek Oxfmt ani yamlfmt. Plugin Oxc nie czyta
`.oxfmtrc`; jego opcje należą do sekcji `oxc` w konfiguracji dprint. Wynik może
różnić się od osobnego Oxfmt zależnie od wersji silnika i ustawień.

Utrzymanie configu i wersji pluginów opisują [globalne ustawienia dprint](#globalne-ustawienia-dprint).

Shfmt dla sh/bash wykorzystuje `.editorconfig`; jeżeli pliku nie ma, wbudowany
adapter Conforma korzysta z wcięć bufora.
Jawne `-ln zsh` wyłącza odczyt opcji formatowania EditorConfig przez shfmt;
dla Zsh przekazujemy więc szerokość wcięcia i wybór tabów z bufora. Pozostałe
opcje shfmt z EditorConfig nie są wtedy stosowane. ERB jest celowo pomijane.

Dockerfmt używa gotowej binarki mise i wbudowanego adaptera Conforma. Ponieważ
stdin nie obsługuje `.editorconfig`, Conform przekazuje szerokość wcięcia i wybór
tabów z bufora. Formatter obsługuje shell w `RUN`, ale może też modernizować
zapisy Dockerfile, np. `MAINTAINER` na `LABEL`; przejrzyj wynik przed zapisem.
Brak narzędzia albo błąd formatowania nie przełącza się na formatowanie LSP.

Narzędzia muszą być wcześniej przygotowane. Edytor ustawia
`MISE_AUTO_INSTALL=false` we wszystkich profilach. Ustawienie dziedziczą procesy
potomne, także `:terminal`; jawne `mise install` pozostaje dostępne.
Dprint może potrzebować przygotowanego cache pluginów;
konfiguracja Neovima nie zarządza tym cache ani nie gwarantuje pracy offline.
Projektowe `format`/`check` pozostają właściwym odbiorem zmian, także dla Ruby.

### Narzędzia Neovim — jawne utrzymanie przez mise

`.config/mise/config.toml` jest jedynym źródłem narzędzi, backendów i wersji.
`lua/plugins/lsp.lua` określa aktywne serwery LSP, a `lua/plugins/conform.lua`
formatery uruchamiane z `PATH`. Utrzymywany zestaw obejmuje 11 narzędzi:
pięć serwerów LSP i osiem formatterów. Ruff i
Taplo są wspólne dla LSP i formatowania.

| Narzędzie mise | Użycie |
|---|---|
| helm_ls | LSP `helm_ls` |
| ruff | LSP `ruff` i Conform `ruff_format` |
| taplo | LSP `taplo` i Conform TOML |
| marksman | LSP `marksman` |
| gopls | LSP Go |
| goimports | Organizacja importów Go |
| gofumpt | Formatowanie Go |
| stylua | Formatowanie Lua |
| tree-sitter | CLI do budowania parserów, przygotowywane przez mise |
| shfmt | Formatowanie sh/bash/Zsh |
| dockerfmt | Ręczne formatowanie Dockerfile i shella w `RUN` |
| dprint | Formatowanie z configiem projektu lub globalnym pluginem Oxc WASM |

Projektowy RuboCop należy do Bundlera i korzysta z Gemfile/lockfile oraz procedury
aktualizacji projektu. Projektowe `node_modules`, lokalny dprint, mise i pluginy
dprint pozostają pod kontrolą projektu; globalne utrzymanie nie przegląda repozytoriów.
R3X korzysta z własnej konfiguracji mise.
LuaLS nie jest instalowany ani aktywowany; formatowanie Lua przez StyLua pozostaje dostępne.

Wersje bazowe narzędzi Neovim są deklarowane jako `latest` w mise, z wyjątkiem
Tree-sitter CLI przypiętego do 0.26.1. Dprint musi
być co najmniej 0.64.3; konfiguracja Zsh wymaga shfmt 3.13.1 lub nowszego ze
względu na `-ln zsh`. Mise odpowiada za instalację i aktualizację zadeklarowanych
wersji. Pełna instalacja desktopu uruchamia `mise install` przed przygotowaniem
pluginów. `make install-neovim` najpierw sprawdza wymagania, potem uruchamia
`mise install` z katalogu domowego użytkownika docelowego, a na końcu przygotowuje pluginy. `update-all` używa
zwykłego etapu `mise upgrade` do aktualizacji tych binarek i osobnego headless
procesu wyłącznie do pluginów. Zwykły start edytora nie instaluje ani nie
aktualizuje narzędzi.

Konfiguracja nie ładuje Masona; narzędziami zarządza mise. Wcześniej zainstalowane
paczki Masona pozostają na dysku i nie są automatycznie usuwane ani aktualizowane.
Komendy `:Mason` i `:MasonInstall` nie są już dostępne. Ruby nie ma domyślnego
formatowania w edytorze. Usunięcie deklaracji `gem:ruby-lsp` nie odinstalowuje
istniejących narzędzi ani Ruby wymaganego np. przez tmuxinator.

Narzędzia mise nie są instalowane przy
formatowaniu. Pluginy kompilowane lokalnie wymagają make i kompilatora C; Go jest
deklarowanym runtime'em dla gopls i goimports. Systemowe zależności przygotowuje
operator, dotfiles ich nie instalują.

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
- **Wymagania**: Neovim 0.11.3+.
- **Profil**: Tylko `DOTFILES_PROFILE=desktop`. Na `server` i bez ustawionego profilu plugin oraz aktualizacja parserów są wyłączone.
- **Zgodność**: plugin jest przypięty do `f873ec2955098fc4b7c3abfe891bdd49fa7947e2`, zgodnego z Neovimem 0.11. Nowszy upstream wymaga 0.12. Zmianę przypięcia należy połączyć z decyzją o wersji Neovima i rzeczywistym odbiorem parserów.
- **Instalacja parserów**: desktop przy starcie doinstalowuje brakujące lub niekompletne parsery w tle. Sprawne parsery zachowują swoje wersje; aktualizacje pozostają jawne przez `update-all`. `make install-neovim` również przygotowuje parsery. Lista języków jest w `lua/plugins/treesitter.lua`. Po zakończeniu instalacji podświetlanie uruchamia się także w już otwartych buforach.
- **Wymagania desktopu**: kompilator C i Tree-sitter CLI >= 0.26.1. Pierwsza instalacja pobiera źródła parserów. Błędy instalacji są widoczne, a kolejny start ponawia instalację niekompletnych języków. Mise dostarcza gotową binarkę CLI; kompilator pozostaje zależnością systemową. Bezpośrednie `bin/maintain-neovim plugins install|update` sprawdza CLI przed uruchomieniem Lazy i nie instaluje go samoczynnie.
- **Utrzymanie headless**: operacje czekają na wynik (limit 5 minut) i propagują błąd. Instalacja najpierw uzgadnia istniejący checkout Tree-sittera z przypięciem, zanim załaduje jego kod. Pozostałe sprawne pluginy zachowują swoje wersje. Niekompletne parsery lub brakujące reguły `highlights` są naprawiane. Oba tryby uzgadniają parsery z manifestem przypiętego pluginu; parsery już zgodne z manifestem nie są przebudowywane.
- **Odbiór**: `tests/nvim_parser_maintenance_test.py` w jednorazowym HOME instaluje i aktualizuje wymagane parsery, odtwarza awarie zapisu reguł i kompilatora oraz brak parsera, sprawdza ponowienie przy starcie, podświetlanie i zapytania highlights. Wymaga jawnej ścieżki do checkoutu upstream i przygotowanego CLI; pobiera źródła parserów.
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

- **nvim-lspconfig**: [neovim/nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) — Konfiguracja LSP

**Zainstalowane serwery**:
- `helm_ls` — Helm charts
- `ruff` — Python (lightweight LSP + linter + formatter)
- `taplo` — TOML (lekki skompilowany LSP + formatter)
- `marksman` — Markdown
- `gopls` — Go

**Konfiguracja API**:
- **Neovim 0.11.3+**: używa natywnego `vim.lsp.config()` + `vim.lsp.enable()`; nie ma mostu `mason-lspconfig` ani automatycznej aktywacji serwerów Masona.
- **Jawna lista**: `vim.lsp.enable(...)` w `lua/plugins/lsp.lua` określa aktywowane serwery. Pięć podstawowych serwerów korzysta z komend i argumentów nvim-lspconfig oraz przygotowanego `PATH`, bez osobnego `mise -C <root> which`.
- **Katalog procesu i root**: standardowe serwery dziedziczą cwd Neovima. Root projektu nadal jest wykrywany przez nvim-lspconfig i przekazywany przez protokół LSP; nie ustawia cwd procesu. Shim mise wybiera wersję według cwd procesu, więc otwarcie pliku z innego repo nie gwarantuje jego własnej wersji serwera.
- **Dostępność**: brak standardowego serwera w `PATH` oznacza brak klienta; Neovim nie szuka wtedy binarki przez mise ani jej nie instaluje. Dostępność i przyczyny problemów sprawdzisz przez `:checkhealth vim.lsp` / `:LspLog`.
- **Neovim <0.11.3**: niewspierany — konfiguracja kończy działanie z czytelnym komunikatem o wymaganej wersji.
- **Ruby**: Ruby LSP jest wyłączone dla wszystkich projektów, również z aktywowanym `.dev/bin/ruby-lsp`. Edytor nie wybiera runtime, nie uruchamia Bundlera ani transportu Docker. Własne wrappery i usługi projektów pozostają pod kontrolą projektu; ta zmiana ich nie usuwa.
- **Źródła gemów**: nie ma już specjalnego hooka ustawiającego `.bundle/gems` tylko do odczytu. Pliki mają zwykłe zachowanie edytora i uprawnienia systemowe.

**Komendy**:
- `:LspInfo` — Info o aktywnych serwerach; nvim-lspconfig lub lokalny alias zapewnia dostęp do `:checkhealth vim.lsp`

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

- `<Space>cf` — Formatuj bufor (desktop)
- `<Space>uf` — Przełącz formatowanie przy zapisie bieżącego bufora (desktop)

#### LSP (aktywne gdy serwer LSP jest podłączony)

- `<Space>rn` — Rename symbol
- `<Space>ca` — Code action

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

Mapowania mają opisy widoczne przez `:nmap <C-Up>` i analogiczne polecenia dla pozostałych strzałek.

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
cd ~/dotfiles
# Pełna instalacja przygotowuje pluginy Neovima dla wybranego profilu.
make install

# Uzupełnij pluginy Neovima; na desktopie także zadeklarowane narzędzia mise.
make install-neovim

# Mise aktualizuje zadeklarowane binarki; update-all osobno aktualizuje pluginy.
update-all
```

Samodzielna sekcja wymaga zapisanego profilu (`make install-profile`),
konfiguracji bazowej (`make install-base`) i Neovima >= 0.11.3. Desktop wymaga
również konfiguracji mise (`make install-tools`) i swoich zależności budowania.
Nieznany profil jest odrzucany.
`make install-neovim` najpierw sprawdza wymagania przez
`bin/maintain-neovim plugins check`, bez instalacji narzędzi ani uruchamiania sesji Neovima.
Na desktopie następnie uruchamia `mise install` w katalogu domowym użytkownika
docelowego, a dopiero potem przygotowuje pluginy przez
`bin/maintain-neovim plugins install` i odświeża completions. Server po sprawdzeniu
wymagań przygotowuje wyłącznie lekki zestaw pluginów, bez instalacji mise,
narzędzi językowych i kompilacji parserów. Pełna instalacja przygotowuje pluginy w obu profilach; desktop instaluje
narzędzia mise wcześniej w etapie `tools`. Przy braku Neovima >= 0.11.3 pomija
jego utrzymanie, zachowuje Vim i kontynuuje pozostałe etapy; jawna sekcja
`make install-neovim` nadal odmawia działania bez wspieranej wersji.
`update-all` aktualizuje binarki
przez mise i pluginy w osobnym procesie `bin/maintain-neovim plugins update`;
nie uruchamia dodatkowego etapu narzędzi Neovim. Server zachowuje lekki zestaw
pluginów i nie przygotowuje narzędzi Neovima. Zwykły start edytora nadal może
bootstrapować lazy.nvim i brakujące pluginy.
Desktop automatycznie doinstalowuje brakujące parsery Tree-sitter w tle; ich aktualizacje pozostają częścią jawnego utrzymania. Server nie instaluje ani nie buduje parserów.
Nieudane buildy maintenance zapisuje w `stdpath("state")/pending-plugin-builds.json`.
Kolejne `install` lub `update` ponawia je także przy istniejącym checkoutcie;
po udanym buildzie wpis jest usuwany. Sprawne pluginy nie są przebudowywane
przy kolejnym `install`.

### Globalne ustawienia dprint

Globalny `~/.config/dprint/dprint.jsonc` jest linkowany przez Stow do
`.config/dprint/dprint.jsonc` w tym repo. `make install-neovim` przygotowuje cache
wersji zapisanych w configu, bez zmiany przypiętych numerów. `update-all` oraz
`bin/maintain-neovim plugins update` najpierw uruchamiają
`dprint config update --global`, aby wybrać najnowsze wersje pluginów, a potem
`dprint install --global`, aby przygotować ich cache. Nowe numery trafiają przez
link do pliku w repo — przejrzyj diff i commituj aktualizację. Nie powstaje
osobna kopia configu. Brak configu wymaga ponownego `make install-base`.
Globalne reguły dotyczą także CLI dprint poza edytorem;
`*-lock.json` i `pnpm-lock.yaml` są domyślnie pomijane.

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
