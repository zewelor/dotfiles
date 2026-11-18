# Neovim: przegląd kodu i drobne poprawki

Konfiguracja wymaga **Neovima 0.11.3+** (minimum nvim-lspconfig). Służy do czytania kodu, przeglądania zmian
agentów i ręcznej edycji. Projektowe komendy formatowania, testy, hooki i CI są
źródłem kontroli jakości. Edytor nie uruchamia Docker Compose ani nie wybiera
runtime Ruby projektu.

## Struktura i profile

- `init.lua` — sprawdzenie wersji i załadowanie konfiguracji.
- `lua/config/options.lua` — opcje, schowek i dodatkowe rozpoznawanie filetype.
- `lua/config/keymaps.lua` — wspólne skróty.
- `lua/config/fileline.lua` — otwieranie odwołań `plik:linia`.
- `lua/config/lazy.lua` — konfiguracja managera pluginów.
- `lua/config/profile.lua` — granica profilu desktop.
- `lua/plugins/` — małe specyfikacje pluginów, LSP i Conform.
- `after/ftplugin/` oraz `ftdetect/` — ustawienia i rozpoznawanie typów plików.
- `maintain.lua` — jawne utrzymanie pluginów i parserów.

`DOTFILES_PROFILE=desktop` włącza LSP, formatowanie, Tree-sitter
oraz natywny sorter Telescope. `server` i brak profilu zachowują lekki edytor:
bez serwerów językowych, formatterów i kompilacji parserów. Obecność mise sama
nie włącza profilu desktop. Pozostałe pluginy, np. Git i wyszukiwanie, są wspólne.

Instalator linkuje cały katalog `~/.config/nvim` do repozytorium; zmiany plików
są widoczne w nowej sesji bez ponownego Stow. Cache, pluginy, lokalny
`lazy-lock.json` i stan utrzymania pozostają w katalogach XDG użytkownika.
Zobacz [zasady linkowania](../../docs/config-directory-links.md).

## Codzienna praca

| Skrót | Działanie |
|---|---|
| `<Space>ff` / `<Space>fg` | Telescope: pliki / wyszukiwanie tekstu przez ripgrep |
| `<Space>e` / `<Space>o` | Neo-tree: pokaż / przejdź do drzewa plików |
| `<Space>gg` | LazyGit przez Snacks, jeżeli `lazygit` jest dostępny |
| `<Space>ghs` | Gitsigns: stage hunka; w Visual tylko zaznaczone linie |
| `<Space>ghS` | Stage całego bufora |
| `<Space>ghd` / `<Space>ghD` | Gitsigns: diff z bazą Gitsigns (domyślnie indeks) / z HEAD |
| `<Space>cf` | Ręczne formatowanie (desktop) |
| `<Space>uf` | Przełącz formatowanie przy zapisie bieżącego bufora (desktop) |
| `<Space>w`, `<C-s>` | Zapis pliku |
| `<Space>q` / `<Space>Q` | Zamknij okno / zakończ bez zapisywania zmian |
| `<Space>sv` / `<Space>sh` / `<Space>sc` | Split pionowy / poziomy / zamknięcie splitu |
| `<C-h/j/k/l>` | Przejście między oknami; LSP przejmuje `<C-k>` dla signature help |
| `<Tab>` / `<S-Tab>` | Następne / poprzednie okno |
| `<C-Up>` / `<C-Down>` | Zwiększ / zmniejsz wysokość okna |
| `<C-Right>` / `<C-Left>` | Zwiększ / zmniejsz szerokość okna |
| `<Space>?` | Pokaż globalne skróty w Which-key |
| `<C-n><C-n>` | Numery linii: wyłączone → absolutne → relatywne |
| `<` / `>` w Visual | Wcięcie i zachowanie zaznaczenia |
| `gc`, `gcc`, `<C-_>` (Ctrl+/) | Natywne komentowanie |
| `ga` | Wyrównanie tekstu przez mini.align |
| `gsa`, `gsd`, `gsr` | Dodaj / usuń / zmień otoczenie przez mini.surround |
| `gsf`, `gsh`, `gsn` | Znajdź / podświetl otoczenie / zmień zasięg |

Which-key podpowiada skróty po prefiksie. Mini.pairs domyka nawiasy i cudzysłowy.
Opisy skrótów zmiany rozmiaru okien można sprawdzić przez `:nmap <C-Up>`
i analogiczne polecenia dla pozostałych strzałek.
Blink zapewnia uzupełnianie ścieżek, snippets, LSP i słów bufora; ustawienia
klawiszy pochodzą z presetu `enter` pluginu z wyłączonym automatycznym zaznaczaniem podpowiedzi. Dopasowanie podpowiedzi preferuje
Rust (`prefer_rust_with_warning`): Blink pobiera gotową bibliotekę dla wspieranego
systemu, a przy jej niedostępności ostrzega i używa Lua. Kompilator Rust nie jest
wymagany przy korzystaniu z gotowej biblioteki. Nie utrzymujemy integracji Copilot
ani OpenCode w edytorze; zewnętrzne CLI agentów pozostają niezależne.

### Skróty wewnątrz pluginów

W **Neo-tree**: `a` dodaje plik/folder, `d` usuwa, `r` zmienia nazwę,
a `?` pokazuje pełną pomoc. `<Space>e` otwiera/zamyka drzewo;
`<Space>o` przenosi do niego fokus.

W **Blinku**, podczas wpisywania (preset `enter`, `preselect = false`):

| Skrót | Działanie |
|---|---|
| `<C-Space>` | Pokaż menu; przy otwartym menu pokaż/ukryj dokumentację |
| `<Enter>` | Zatwierdź wskazaną podpowiedź; bez wskazanej pozycji wstaw nowy wiersz |
| `<Tab>` | Przejdź dalej w snippet lub wykonaj zwykły Tab |
| `<S-Tab>` | Poprzednie pole snippet; poza snippet zwykłe działanie klawisza |
| `<Up>` / `<C-p>` | Poprzednia podpowiedź |
| `<Down>` / `<C-n>` | Następna podpowiedź |
| `<C-e>` | Anuluj podpowiedź |
| `<C-b>` / `<C-f>` | Przewiń dokumentację w górę / dół |

Menu nie zaznacza pierwszej podpowiedzi automatycznie. Wskaż ją strzałkami lub
`<C-n>`/`<C-p>`, a potem zatwierdź Enterem. Normal-mode Tab nadal przełącza okna,
a Normal-mode `<C-k>` ma znaczenie opisane w tabeli nawigacji.

W wierszu poleceń `:` menu otwiera się od razu bez zaznaczania pierwszej
pozycji (`preselect = false`): `<Tab>` / `<S-Tab>`, `↑` / `↓` oraz
`<C-n>` / `<C-p>` wybierają z listy, `<C-e>` zamyka menu (przywracając historię
pod `↑` / `↓`), `←` / `→` przesuwają kursor w komendzie, a `<Enter>` wykonuje
wpisane polecenie.

- `<C-Space>` otwiera menu ręcznie.
- `<C-y>` wstawia wybraną podpowiedź lub pierwszą, jeśli żadna nie jest
  zaznaczona. Polecenie wykonasz Enterem.
- `<End>` zamyka otwarte menu.

**Mini.align:** `ga` w Normal czeka na ruch wybierający zakres; w Visual
wyrównuje zaznaczenie. W trakcie wyrównywania `s` wybiera wzorzec podziału,
`j` justowanie, `m` separator łączenia, a `t` usuwa zbędne spacje.

**Mini.surround** obsługuje ruchy Vima. `gsaiw)` otacza słowo nawiasami,
`gsa]` otacza zaznaczenie w Visual, a `.` powtarza ostatnią zmianę otoczenia w Normal.

**Git:** do stage pojedynczych linii zaznacz je w Visual i użyj `<Space>ghs`.
W Normal ten sam skrót stage'uje hunk pod kursorem; `<Space>ghS` cały bufor.
`<Space>ghd` otwiera diff bieżącego bufora z bazą Gitsigns (domyślnie indeks).
Zapis bufora indeksu aktualizuje staged. `<Space>ghD` porównuje z `HEAD`. W tym widoku
działają `]c`/`[c` oraz `do`/`dp`. Commit, branch i stash obsługuj w LazyGit
(`<Space>gg`), jeśli binarka jest dostępna przy starcie Neovima.

Schowek systemowy jest aktualizowany przy yankowaniu, a nie przy delete/change.
Po SSH używany jest wbudowany provider OSC52. Undo jest trwałe, myszy nie
używamy, `<C-z>` jest wyłączone. `autoread` pozwala Neovimowi przeładować
niezmodyfikowany bufor przy wykryciu zewnętrznej zmiany; `:checktime` sprawdza
ją jawnie. Zmodyfikowany lokalnie bufor wymaga rozstrzygnięcia przez użytkownika.
Motyw to Catppuccin Latte z przezroczystym tłem; ikony dostarcza mini.icons.

## Pliki, wcięcia i EditorConfig

Wbudowany EditorConfig Neovima odczytuje reguły repozytorium. Globalny
`~/.editorconfig` jest linkowany z dotfiles. Nie potrzebuje osobnego pluginu.
Markdown zachowuje zawijanie i końcowe spacje; wcięcia wynikają z `.editorconfig`.
Fragmenty `~/.ssh/config.d/*` mają filetype `sshconfig`; `Justfile` ma `just`.
Pliki tmuxinatora zawierające ERB mają `eruby.yaml.tmuxinator` i nie są formatowane.
Pliki `.yaml`, `.yml` i `.tpl` pod `templates/` chartu z `Chart.yaml` otrzymują
typ `helm`, również w podkatalogach. `Chart.yaml` i `values.yaml` mają typ `yaml`.

Dockerfile używa standardowego mechanizmu wcięć Neovima. `fdockerfile` i jego
warianty są rozpoznawane jako Dockerfile. Usunięty własny parser zagnieżdżonego
shella w `RUN` ustępuje standardowym wcięciom Neovima. `=`/Enter może dawać inne
wcięcia wewnątrz `if`/`case`; na desktopie `<Space>cf` formatuje cały bufor przez
gotowy `dockerfmt`.

Odwołania z odpowiedzi agentów i logów można otwierać bezpośrednio:

```sh
nvim plik.lua:12
nvim plik.lua:12-20
nvim 'katalog ze spacjami/plik.lua:12'
```

Działa również `:e plik.lua:12`. Zakres otwiera początkową linię bez zaznaczenia.
Istniejący plik zawierający dwukropek w nazwie ma pierwszeństwo. Brak pliku
pozostawia zwykły nowy bufor. Dla kilku splitów przez `-o`/`-O` użyj `+linia`.
To mała lokalna adaptacja fileline.nvim na licencji MIT (`LICENSE.fileline`).

## Formatowanie

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

## Nawigacja LSP

Desktop używa standardowych konfiguracji nvim-lspconfig i natywnego API
`vim.lsp.config` / `vim.lsp.enable`: Helm, Ruff, Taplo, Marksman i gopls.
Ruby LSP jest odłożone i nie jest uruchamiane. Nie ma własnego resolvera runtime,
transportu Docker ani Masona jako dodatkowego managera narzędzi.

Wyłączenie Ruby LSP dotyczy wszystkich projektów, także `ruby_base` i `dottales`,
które nadal mają własne wrappery `.dev/bin` i usługę LSP. Te integracje projektowe
pozostają bez zmian do osobnej migracji; ta konfiguracja Neovima ich nie uruchamia.

Polecenia pochodzą z `PATH` uruchomionego Neovima; standardowe konfiguracje
serwerów ustalają root i argumenty. Przy mise znaczenie mają jego zwykłe reguły
wyboru wersji. Ten prosty model nie gwarantuje izolacji środowisk różnych
projektów w jednej sesji. Nie uruchamiaj edytora z przypadkowym PATH zawierającym
wrappery innego projektu. Zmiana środowiska terminala nie zmienia już działającego
procesu. Dla informacji o klientach użyj `:checkhealth vim.lsp` i `:LspLog`.

Po podłączeniu LSP: `gd` definicja, `gD` deklaracja, `gr` referencje, `gi`
implementacja, `K` dokumentacja, `<C-k>` signature help, `<Space>rn` rename,
`<Space>ca` code action, `[d`/`]d` diagnostyka. LSP pozostaje pomocą przy czytaniu
kodu, a nie warunkiem działania projektu.

## Instalacja i utrzymanie

Przy starcie Lazy automatycznie pobiera brakujący manager i brakujące pluginy.
Nie aktualizuje już zainstalowanych pluginów i nie sprawdza okresowo nowych wersji.
Aktualizacje uruchamiaj jawnie przez `update-all` lub `:Lazy update`.
Desktop automatycznie doinstalowuje brakujące lub niekompletne parsery Tree-sitter
w tle; aktualizacje pozostają częścią jawnego utrzymania opisanego poniżej.

```sh
# Desktop: pełna instalacja albo sam etap Neovima po przygotowaniu profilu/base/mise.
make install
make install-neovim

# Aktualizacja narzędzi i pluginów według zapisanego profilu.
update-all

# Tylko pluginy/parsery, także dla przygotowanego profilu server:
bin/maintain-neovim plugins update
```

Polecenia instalacji/aktualizacji zmieniają środowisko użytkownika. Uruchamiaj
je świadomie. `make install-neovim` wymaga zapisanego profilu desktop lub server,
gotowej konfiguracji bazowej oraz Neovima 0.11.3+. Desktop wymaga też mise.
Najpierw sprawdza te zależności bez zmian
(`bin/maintain-neovim plugins check`), potem przygotowuje narzędzia mise
(w tym Tree-sitter CLI i dprint), następnie globalne pluginy formattera oraz
pluginy Neovima i parsery. Ten etap narzędzi i parserów
dotyczy tylko desktopu. Pełna instalacja przygotowuje lekki zestaw pluginów
serwera przed wybraniem Neovima jako edytora; nie wymaga tam mise ani kompilatora.
Pełna instalacja desktopu przygotowuje mise wcześniej. Starszy
Neovim jest pomijany podczas pełnej instalacji na rzecz Vima; samodzielna sekcja
wymaga wspieranej wersji.

Mise jest właścicielem binarek; lista i wersje są w `.config/mise/config.toml`.
Ruby nadal może być potrzebne innym narzędziom, np. tmuxinatorowi; wycofanie
Ruby LSP go nie usuwa. Istniejące paczki Masona nie są automatycznie kasowane.

Jawne utrzymanie instaluje brakujące pluginy i wymagane parsery desktopu.
Oba tryby uzgadniają parsery z manifestem przypiętej rewizji pluginu; zgodne
parsery nie są ponownie budowane. Desktop wymaga make,
kompilatora C i Tree-sitter CLI >= 0.26.1. CLI jest zadeklarowane w mise jako
gotowa binarka; bezpośrednie utrzymanie sprawdza je oraz dprint przed startem Lazy
i nie instaluje tych CLI samoczynnie. `update-all` przygotowuje narzędzia mise przed
pluginami. Server korzysta z natywnego syntax
i standardowego sortera Telescope bez tych buildów. `fd`, jeśli dostępne,
służy do wyszukiwania plików; ripgrep do wyszukiwania tekstu.

Błędy instalacji/buildów kończą utrzymanie niezerowym kodem. Nieudane buildy
pluginów zapisują się w `stdpath("state")/pending-plugin-builds.json` i są
ponawiane podczas kolejnego utrzymania. Sprawne pluginy nie są przebudowywane
przez kolejne `install`. Cały proces ma limit czasu.
Utrzymanie sprawdza obecność wymaganych parserów i ich reguł `highlights`.
Niekompletna instalacja (np. przerwana przy zapisie reguł) jest ponawiana tylko
dla dotkniętych języków; brak wymaganych plików po instalacji kończy się błędem.

Tree-sitter jest przypięty do rewizji `f873ec2955098fc4b7c3abfe891bdd49fa7947e2`,
która zachowuje API Neovima 0.11. Nowszy upstream wymaga Neovima 0.12;
Instalacja uzgadnia też istniejący checkout Tree-sittera z przypięciem, zanim
załaduje jego kod; pozostałe zdrowe pluginy zachowują swoje wersje. Późniejszą
zmianę przypięcia trzeba połączyć z decyzją o wersji Neovima i rzeczywistym
odbiorem instalacji parserów. Test `tests/nvim_parser_maintenance_test.py`
wykonuje instalację i aktualizację wszystkich wymaganych parserów, naprawę po
awarii zapisu reguł i brakującym parserze, automatyczną instalację przy starcie,
widoczny błąd kompilatora i ponowienie oraz zachowanie sprawnych zależności
Markdown. Sprawdza też ładowanie parserów i zapytania highlights w jednorazowym HOME. Wymaga jawnych ścieżek
do checkoutu upstream i gotowego CLI; pobiera źródła parserów, nie zmienia
środowiska użytkownika.

`:Lazy` pokazuje manager; `:Lazy restore` przywraca wersje z lokalnego lockfile'a
maszyny. To bieżący lockfile, nadpisywany przy aktualizacji; cofnięcie aktualizacji
wymaga zachowania jego wcześniejszej kopii. Lockfile nie obejmuje parserów.
`:Lazy sync` jest jawną aktualizacją, nie czynnością diagnostyczną.
`:checkhealth` pomaga sprawdzić stan środowiska. Parsery mają jedną listę w
`lua/plugins/treesitter.lua`; brakujące parsery desktopu są instalowane przy starcie
w tle. Sprawne parsery i ich zależności zachowują swoje wersje. Błąd instalacji jest
widoczny, a kolejny start ponawia instalację niekompletnych języków. Po instalacji
podświetlanie włącza się także w już otwartych buforach. Server nie pobiera ani nie
kompiluje parserów.

Nowy plugin powinien mieć mały spec w `lua/plugins/`, opis celu i aktualizację
tego README. Wspólne skróty należą do `lua/config/keymaps.lua`, opcje do
`lua/config/options.lua`, a ustawienia typu pliku do `after/ftplugin/`.
