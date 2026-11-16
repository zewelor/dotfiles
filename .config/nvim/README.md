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
│   │   ├── formatting.lua # Wspólna polityka formatowania projektu
│   │   ├── profile.lua  # Jawny wybór profilu desktop
│   │   ├── ruby.lua     # Root Ruby, narzędzia projektu i źródła gemów tylko do odczytu
│   │   └── tools.lua    # Lista LSP i resolver binarek mise
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
Aktywowane projektowe Ruby LSP i dprint mają pierwszeństwo; pozostałe narzędzia
rozwiązuje mise w kontekście katalogu projektu. Profil `server`
i brak profilu korzystają z uproszczonego trybu, również gdy `mise` jest
dostępne w `PATH`; sam mise dla pojedynczego CLI nie włącza narzędzi edytora.

Desktop wymaga mise i konfiguracji z zadeklarowanymi narzędziami. Ruby LSP używa projektowego
pliku wykonywalnego `ruby-lsp`, gdy został udostępniony przez `PATH` przed startem edytora.
Pozostałe katalogi Ruby zachowują resolver mise; nie jest on fallbackiem po błędzie wrappera. Domyślny Oxfmt jest
natywną binarką mise, więc utrzymywany zestaw LSP i formatterów nie wymaga
Node.js ani npm. Projektowy `node_modules/.bin/oxfmt` ma pierwszeństwo i może
wymagać Node.js zgodnie z konfiguracją projektu. Pluginy kompilowane lokalnie
również wymagają make i kompilatora C.

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
przez `dockerfmt`, w tym shell wewnątrz `RUN`; zapis nadal pomija formatowanie
Dockerfile. Ręczne formatowanie nie zapisuje pliku automatycznie.

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

- **Repo**: [stevearc/conform.nvim](https://github.com/stevearc/conform.nvim)
- **Cel**: Formatowanie plików przez zewnętrzne narzędzia
- **Ładowanie**: otwarcie pliku nie ładuje Conforma. Plugin ładuje się przy pierwszym formatowaniu albo użyciu `:ConformInfo` / `:FormatInfo`.
- **Zapis nie uruchamia formattera**. Ręczne `<Space>cf` korzysta z poniższej polityki. Dla YAML (również obecnych podtypów), JS/TS/React, JSON/JSONC/JSON5, CSS, GraphQL i Markdown najbliższa konfiguracja dprint decyduje, czy plugin obsługuje plik. Samo istnienie konfiguracji nie wystarcza. Wspierane nazwy to `dprint.json`, `dprint.jsonc`, `.dprint.json`, `.dprint.jsonc` i warianty `.config/dprint.json(c)`.
- **Dprint 0.64.3+**: wybrana binarka jest sprawdzana przed użyciem. `resolved-config --file` rozpoznaje obsługę pliku, a `fmt --stdin` z pełną ścieżką respektuje `includes`, `excludes` i `.gitignore`. Wykluczone pliki pozostają bez zmian. Brak pluginu, również przez negatywne `associations`, pozwala użyć formattera domyślnego; Markdown bez pluginu jest pomijany.
- **Wybór binarki**: dprint z `PATH`, którego ścieżka leży wewnątrz bieżącego projektu, ma pierwszeństwo. Aktywacja środowiska projektu (np. `source dockerized.sh`) należy do użytkownika; edytor nie wykrywa ani nie wywołuje tego skryptu. Samo istnienie wrappera na dysku nie włącza integracji. Wrapper innego projektu jest pomijany. Dalej wybierane jest lokalne `node_modules/.bin/dprint`, a potem efektywna deklaracja mise w katalogu bufora (także globalna). Błąd wybranego narzędzia nie uruchamia innej wersji. Dla Oxfmt pierwszeństwo ma projektowe `node_modules/.bin/oxfmt`, potem natywna binarka mise. Pozostałe utrzymywane binarki są rozwiązywane przez mise w katalogu projektu. Zapytania mise pomijają odziedziczone `MISE_DPRINT_VERSION`, zachowując resztę środowiska i reguły zaufania. Narzędzia nie są instalowane przy formatowaniu.
- **Oxfmt**: projektowa binarka zachowuje Conformowy stdin i nazwę pliku. Domyślna natywna binarka mise nie obsługuje stdin, więc Conform formatuje tymczasowy plik obok bufora i odczytuje zmieniony wynik. Tymczasowa nazwa może zmienić dopasowanie konfiguracji lub reguł ignorowania zależnych od nazwy pliku; to ograniczenie dotyczy natywnej ścieżki.
- **Domyślne formatery**: Lua przez `stylua`, Python przez `ruff_format`, TOML przez `taplo`, Go przez `goimports`, a następnie `gofumpt`, sh/bash oraz Zsh przez `shfmt` (dla Zsh jawnie `-ln zsh`, wymagane >= 3.13.1), YAML przez `yamlfmt`, JS/TS/JSON/CSS/GraphQL przez natywne `oxfmt`.
- **Go**: Conform wykonuje `goimports`, po nim `gofumpt`, z binarkami rozwiązanymi przez mise w katalogu bufora. Procesy formatterów współdzielą timeout Conform 2000 ms; osobne zapytania `mise which` mają limit 1000 ms każde. Błędy i timeout są widoczne; formatowanie nie przechodzi na gopls.
- **Wcięcia shella**: sh/bash respektują `.editorconfig` zamiast wymuszonych dwóch spacji. Zsh dostaje `-ln zsh`, co wyłącza odczyt opcji formatowania EditorConfig przez shfmt; szerokość wcięcia i wybór tabów przekazujemy z bufora. Pozostałe opcje shfmt z EditorConfig nie są wtedy stosowane. Jeżeli pliku `.editorconfig` nie ma, wbudowany adapter Conforma korzysta z wcięć bufora.
- **Zsh**: sprawdzony shfmt 3.13.1 nie obsługuje całej składni Zsh, np. `${~pattern}`. Błąd parsera jest widoczny i nie zmienia bufora; nie przechodzimy automatycznie na inny formatter. Publiczne pliki shella przeszły kontrolę składni po formatowaniu; nie wykonujemy masowego reformatowania repozytorium.
- **Dockerfile**: ręczne `<Space>cf` używa dockerfmt.
- **Wyłączenia**: `eruby.yaml.tmuxinator` bez formatowania również ręcznie. Nienazwany bufor z grupy projektowej wymaga najpierw nadania nazwy.
- **Błędy i czas**: dla aktywowanego projektowego dprint jeden synchroniczny budżet 10000 ms obejmuje sprawdzenie wersji, konfigurację i formatowanie. Pozostałe projektowe dprint zachowuje budżet 2000 ms; domyślne formatery mają timeout Conform 2000 ms, a każde osobne rozwiązywanie przez mise limit 1000 ms. Błąd konfiguracji, brak wymaganej wersji i timeout są widoczne; wybrany dprint nie przechodzi na inny formatter ani LSP. Błąd nie blokuje zapisu pracy. Brak projektowego kontraktu zachowuje dotychczasowy fallback LSP.
- **Ruby**: projekty z `.rubocop.yml` i Gemfile korzystają z własnych reguł RuboCop. Aktywowany projektowy `ruby-lsp` obsługuje formatowanie przez gotowego klienta LSP; w pozostałych projektach Conform uruchamia repo-local `bin/rubocop`, jeśli istnieje, albo `bundle exec rubocop`, z cache w `tmp/rubocop`. Jeżeli odziedziczony Ruby lub Bundler należy do innego projektu z Gemfile, formatowanie zgłasza błąd zamiast uruchamiać jego wrapper. Poza tym kontraktem `<Space>cf` pomija Ruby; rubyfmt pozostaje ręcznym dodatkiem opisanym poniżej.
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

### Narzędzia Neovim — jawne utrzymanie przez mise

`.config/mise/config.toml` jest jedynym źródłem narzędzi, backendów i wersji.
`lua/config/tools.lua` określa aktywne serwery LSP, resolver działający w katalogu
bufora oraz progi wersji używane przez konfigurację edytora. Utrzymywany zestaw
obejmuje 13 narzędzi: pięć serwerów LSP i osiem formatterów. Ruff i
Taplo są wspólne dla LSP i formatowania. `gem:ruby-lsp` pozostaje istniejącym
narzędziem mise poza tą trzynastką.

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
| shfmt | Formatowanie sh/bash/Zsh |
| dockerfmt | Ręczne formatowanie Dockerfile i shella w `RUN` |
| oxfmt | Natywne formatowanie JS/TS/JSON/CSS/GraphQL, bez npm |
| dprint | Projektowe formatowanie, gdy projekt nie deklaruje własnej binarki |
| yamlfmt | Domyślne formatowanie YAML |

Konfiguracja zawiera też `gem:ruby-lsp` dla katalogów Ruby bez aktywowanego projektowego LSP. Projektowy
RuboCop należy do Bundlera i korzysta z Gemfile/lockfile oraz procedury
aktualizacji projektu. Projektowe `node_modules`, lokalny dprint, mise i pluginy
dprint pozostają pod kontrolą projektu; globalne utrzymanie nie przegląda repozytoriów.
R3X korzysta z własnej konfiguracji mise.
LuaLS nie jest instalowany ani aktywowany; formatowanie Lua przez StyLua pozostaje dostępne.

Wersje bazowe narzędzi Neovim są deklarowane jako `latest` w mise. Dprint musi
być co najmniej 0.64.3; konfiguracja Zsh wymaga shfmt 3.13.1 lub nowszego ze
względu na `-ln zsh`. Mise odpowiada za instalację i aktualizację zadeklarowanych
wersji. Pełna instalacja desktopu uruchamia `mise install` przed przygotowaniem
pluginów. `make install-neovim` sprawdza najpierw pluginy, a następnie uruchamia
`mise install` z katalogu domowego użytkownika docelowego. `update-all` używa
zwykłego etapu `mise upgrade` do aktualizacji tych binarek i osobnego headless
procesu wyłącznie do pluginów. Zwykły start edytora nie instaluje ani nie
aktualizuje narzędzi.

Konfiguracja nie ładuje Masona; narzędziami zarządza mise. Wcześniej zainstalowane
paczki Masona pozostają na dysku i nie są automatycznie usuwane ani aktualizowane.
Komendy `:Mason` i `:MasonInstall` nie są już dostępne. Ruby poza projektem
RuboCop nadal nie ma domyślnego formatowania.

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
- **Auto-install**: Brakujące parsery (lua, vim, bash, python, json, yaml, toml, markdown, dockerfile, git, helm, go) są instalowane automatycznie przy pierwszym starcie. Wymaga kompilacji (gcc/clang).
- **Utrzymanie headless**: etap pluginów pomija startowy auto-install parserów; build czeka na wynik aktualizacji zainstalowanych parserów (limit 5 minut) i propaguje błąd. Ta polityka parserów jest osobna od utrzymania binarek mise.
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
- `ruby_lsp` — Ruby (aktywowany projektowy `ruby-lsp`; poza nim mise)

**Konfiguracja API**:
- **Neovim 0.11.3+**: używa natywnego `vim.lsp.config()` + `vim.lsp.enable()`; nie ma mostu `mason-lspconfig` ani automatycznej aktywacji serwerów Masona.
- **Jawna lista**: `servers` w `lua/config/tools.lua` określa podstawowe aktywowane serwery; Ruby LSP jest konfigurowany osobno. Serwery rozwiązują binarkę przez mise dla katalogu root projektu. Podstawowe serwery zachowują argumenty nvim-lspconfig, a procesy działają z katalogu root.
- **Brak fallbacku**: binarki z Masona lub dowolnego systemowego `PATH` nie zastępują deklaracji mise; wyjątkiem jest jawnie aktywowany projektowy `ruby-lsp` opisany poniżej. Nierozwiązywalne lub niezainstalowane narzędzie kończy się widocznym błędem przy uruchamianiu klienta.
- **Neovim <0.11.3**: niewspierany — konfiguracja kończy działanie z czytelnym komunikatem o wymaganej wersji.
- **Projektowy Ruby LSP**: przed startem Neovima aktywuj środowisko projektu, np. `source dockerized.sh`. Edytor wybiera `ruby-lsp` z `PATH` tylko wtedy, gdy ścieżka pliku wykonywalnego należy do root otwartego projektu. Startuje bez dodatkowych argumentów, z cwd i `PWD` ustawionymi na root; wrapper odpowiada za runtime, bundle, transport stdio i zakończenie procesu. Sam plik `dockerized.sh` nie włącza integracji. Neovim czeka do 2000 ms na zwykłe zakończenie LSP. Zmiana środowiska w terminalu nie zmienia już uruchomionego Neovima; dla innego środowiska otwórz nową sesję.
- **Pozostałe katalogi Ruby**: bez aktywowanego projektowego `ruby-lsp` binarki `ruby` i `ruby-lsp` są sprawdzane przez mise w root i uruchamiane przez `mise -C <root> exec`, z wyłączoną automatyczną instalacją. Błąd aktywowanego wrappera nie przechodzi na mise. Znany problem launchera gema powiązanego z innym Ruby minor pozostaje poza zakresem tej integracji.
- **Root Ruby**: pierwszeństwo ma katalog z `Gemfile`, następnie `.git` (także plik znacznika worktree). Plik Ruby poza repozytorium używa własnego katalogu i konfiguracji mise obowiązującej w tym katalogu. Nienazwany bufor nie uruchamia klienta. Kolejne pliki tego samego root używają istniejącego klienta; katalog i środowisko procesu Neovima pozostają bez zmian.
- **Bundle Ruby**: w Dockerze właścicielem `ruby-lsp` jest developerski bundle projektu. Wrapper uruchamia `bundle exec ruby-lsp` z jawnym Gemfile, wyłączonym auto-install i zamrożonym lockfile. Gemy dev należą do projektu: `.bundle/gems` jest dostępne pod identyczną ścieżką bezwzględną na hoście i w kontenerze dzięki mountowi checkoutu. Cache narzędzi trafia do `.dev/cache`. Oba katalogi są ignorowane przez Git i build obrazu; usunięcie checkoutu usuwa te dane. `gd` otwiera ich źródła tylko do odczytu; taki bufor nie uruchamia kolejnego LSP ani formatowania. Katalogi bez aktywowanego projektowego LSP zachowują start mise bez `BUNDLE_GEMFILE` i composed bundle Ruby LSP.
- **Formatowanie przez projektowy Ruby LSP**: projektowe `.rubocop.yml` i Gemfile wybierają wyłącznie gotowego klienta `ruby_lsp` danego bufora. Brak klienta z obsługą formatowania jest widocznym błędem, bez uruchamiania innego RuboCopa. Projekt bez konfiguracji RuboCop pomija formatowanie przez ten mechanizm. Dodatek RuboCop pozostaje wewnątrz Ruby LSP; nie uruchamiamy drugiego klienta LSP.
- **Błędy Ruby**: brak mise, niepoprawny wynik resolvera i nieudany start wskazują root projektu. Nieudany root jest pomijany do końca sesji, aby kolejne bufory nie powtarzały tego samego błędu; po poprawieniu zależności uruchom Neovima ponownie. Szczegóły błędów procesu są w `:LspLog`. Błąd jednego root nie wyłącza innych projektów ani pozostałych LSP. Bez mise konfiguracje desktop nadal są rejestrowane; start hostowych klientów wymaga mise, a aktywowany projektowy Ruby LSP korzysta z własnego pliku wykonywalnego.

Opcjonalny odbiór na przygotowanych, jednorazowych kopiach projektów w katalogu
tymczasowym, z ich własnymi `.bundle/gems` (bez buildów ani instalacji podczas testu):

```bash
python3 tests/nvim_docker_acceptance.py --ruby-base /tmp/odbior/ruby_base \
  --r3x /tmp/odbior/r3x --output /tmp/odbior/wynik.json
```

W kopiach trzeba wcześniej wykonać `./dockerized.sh setup`. Po przeniesieniu checkoutu
lub zmianie platformy/Ruby przygotuj środowisko ponownie; natywne gemy i nazwa obrazu
Compose mogą zależeć od poprzedniego środowiska. Osobisty cache nie jest wymagany.
Opcja `--reverse` odwraca kolejność projektów. Test jawnie przełącza projektowy `PATH` przy otwieraniu kopii i korzysta z zainstalowanych pluginów,
blokuje hostowe narzędzia Ruby, sprawdza diagnostykę, formatowanie niezapisanego bufora,
definicje i zwykłe zamknięcie kontenerów. Usuwa własne pliki testowe; nie wymusza
usuwania kontenerów. Pozostałe po błędzie kontenery zgłasza do ręcznej inspekcji.
Ścieżki oryginalnych projektów i ich cache są odrzucane.

**Komendy**:
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
`make install-neovim` najpierw uzupełnia pluginy przez
`bin/maintain-neovim plugins install`; na desktopie następnie uruchamia `mise install`
w katalogu domowym użytkownika docelowego i odświeża completions. Server przygotowuje
wyłącznie lekki zestaw pluginów, bez instalacji mise, narzędzi językowych i kompilacji
parserów. Pełna instalacja przygotowuje pluginy w obu profilach; desktop instaluje
narzędzia mise wcześniej w etapie `tools`. Przy braku Neovima >= 0.11.3 pomija
jego utrzymanie, zachowuje Vim i kontynuuje pozostałe etapy; jawna sekcja
`make install-neovim` nadal odmawia działania bez wspieranej wersji.
`update-all` aktualizuje binarki
przez mise i pluginy w osobnym procesie `bin/maintain-neovim plugins update`;
nie uruchamia dodatkowego etapu narzędzi Neovim. Server zachowuje lekki zestaw
pluginów i nie przygotowuje narzędzi Neovima. Zwykły start edytora nadal może
bootstrapować lazy.nvim i brakujące pluginy.
Nieudane buildy maintenance zapisuje w `stdpath("state")/pending-plugin-builds.json`.
Kolejne `install` lub `update` ponawia je także przy istniejącym checkoutcie;
po udanym buildzie wpis jest usuwany. Sprawne pluginy nie są przebudowywane
przy kolejnym `install`.

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
