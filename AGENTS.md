# Instrukcje dla agentów

To jest projektowy delta dla repozytorium dotfiles. Nie powtarzaj tutaj
globalnych zasad agenta ani dokumentacji narzędzi. Komentarze w kodzie i
konfiguracji pisz po angielsku; ten plik pozostaje po polsku.

## Zakres, własność i źródła prawdy (MUST)

- Przed zmianą zapisz `git status --short` w repo głównym oraz, jeśli zadanie
  dotyczy `prv/`, osobno w `prv/`. Zachowaj wszystkie zastane staged,
  unstaged i untracked zmiany.
- `prv/` jest osobnym repozytorium Git i submodułem. Zmiana prywatnego repo,
  commit w nim i aktualizacja gitlinka w repo nadrzędnym są oddzielnymi
  krokami i wymagają osobnego, jawnego zakresu.
- Główny `git status` może ukrywać zmianę submodułu przez
  `diff.ignoreSubmodules=all`. Przed handoffem lub publikacją porównaj jawnie
  `git rev-parse HEAD:prv` z `git -C prv rev-parse HEAD`.
- Publiczne konfiguracje współdzielone przez desktop i serwery należą do
  głównego repo. Prywatne dane i konfiguracje tylko dla profilu `desktop`
  należą do `prv/`; instalator linkuje `prv/` wyłącznie dla tego profilu.
- GNU Stow służy do stabilnych, deklaratywnych plików należących do repo.
  Sekrety, cache, wygenerowany stan i pliki nadpisywane przez aplikacje nie
  powinny być przejmowane przez Stow. Wyjątki zapisuj deterministycznie w
  odpowiednim `.stow-local-ignore` albo w logice instalatora.
- Systemowe pliki `/etc`, mounty, credentials i sekretne wartości pozostają
  pod kontrolą operatora. Repo może dostarczać helper lub instrukcję, ale nie
  może zakładać prawa do ich odczytu, publikacji ani zastosowania.
- Bieżące wersje, backendy i listę narzędzi odczytuj z `Makefile`, `install`,
  `.config/mise/config.toml`, konfiguracji shella oraz live CLI. Nie kopiuj
  zmiennego stanu do zawsze ładowanych instrukcji.
- Zmieniaj minimalny, celowy zakres i zachowuj istniejący styl oraz komentarze.
  W `install` poprzedzaj każdy większy etap czytelnym `print_banner`.
- Skrypty mają działać fail-fast dla komend krytycznych dla logiki. Nie ukrywaj
  ich błędów przez `2>/dev/null || true` ani zgadywany fallback; toleruj brak
  danych tylko wtedy, gdy jest prawidłowym, opcjonalnym stanem.

## Delegowanie (MUST)

- Szeroki research internetowy wymagający wielu niezależnych zapytań,
  przejrzenia licznych źródeł lub równoległego zbadania kilku wątków domyślnie
  deleguj jednemu lub kilku read-only subagentom. Pojedynczego, szybkiego
  sprawdzenia nie deleguj. Główny agent odpowiada za ocenę źródeł, syntezę
  wyników i ponowną weryfikację kluczowych ustaleń.
- Subagenci nie zmieniają indeksu ani historii Git, nie publikują zmian, nie
  odczytują sekretów i nie mutują `$HOME` ani systemu. Nie uruchamiają
  `./install`, Stow bez dry-run, `mise use -g`, `:Lazy sync` ani instalacji lub
  aktualizacji narzędzi.
- Zmiany instalatora, topologii Stow, startu shella, managerów CLI, obsługi
  sekretów oraz konfiguracji obejmującej wiele profili wymagają niezależnego,
  read-only second-pass review przed commitem, publikacją lub zastosowaniem.

## Walidacja i granice zastosowania (MUST)

- W iteracji uruchamiaj tylko sfokusowane sprawdzenia powiązane ze zmienionymi
  plikami. Raportuj dokładną komendę, wynik, ostrzeżenia i pominięte kroki.
- Dla zmian helperów Vault uruchom `make test`.
- Dla szerokich zmian shella, Stow, Vault albo finalnego handoffu uruchom
  `make doctor`. To szybki, lokalny zestaw składni, dry-runów Stow, kontroli
  wymaganych narzędzi i offline'owych testów Vault.
- `make verify` uruchom dla zmian zależnych od realnego środowiska albo na
  wyraźną prośbę. Obejmuje także kontrolę driftu i start interaktywnego shella.
- Walidacja nie upoważnia do zastosowania konfiguracji. `./install`,
  `make install`, `make setup`, Stow bez dry-run, `mise use -g`, `:Lazy sync`
  i inne mutacje środowiska wymagają osobnej, jawnej autoryzacji.

## Neovim (MUST)

- Najpierw przeczytaj `.config/nvim/README.md`; to mapa konfiguracji i
  użytkowania. Kod pozostaje źródłem prawdy dla aktualnego zachowania.
- Współdzielone i przekrojowe keymapy trzymaj w `lua/config/keymaps.lua`.
  Plugin-local lazy-load triggers oraz mapowania ściśle związane z UI pluginu
  mogą pozostać w jego specu. Opcje trzymaj w `lua/config/options.lua`, a
  ustawienia per-filetype w `after/ftplugin/<filetype>.lua`, chyba że
  udokumentowany konflikt wymaga innego miejsca.
- Przy zmianie pluginu, keymapy, opcji, zachowania per-filetype lub struktury
  zaktualizuj odpowiadającą sekcję `.config/nvim/README.md`.
- Keymapy muszą mieć `desc`. Komentarze opisują krótko „dlaczego”, a spec
  pluginu ma zwięzły komentarz identyfikujący jego cel.
- `:Lazy sync` zmienia stan środowiska; nie uruchamiaj go bez osobnej zgody.

## Shell, Kubernetes i managery CLI (MUST)

- Utrzymuj szybki i deterministyczny start shella. Nie dodawaj synchronicznych
  probe'ów sieciowych, generowania cache, `direnv` ani nowych hooków
  prompt/`chpwd`; koszt startupu potwierdzaj pomiarem.
- Narzędzia, aliasy i completions Kubernetes pozostają lazy-loadowane wewnątrz
  `start-k8s-work()` w `.zsh/kubernetes.zsh`, nie w głównym `.zshrc`.
- `mise` jest wymagane tylko dla profilu `desktop`; na `server` pozostaje
  opcjonalne, dopóki konkretny use case nie uzasadni zmiany polityki.
- Nowe standalone CLI dodawaj domyślnie przez `mise`. Zinit służy pluginom
  shellowym i świadomym wyjątkom wymagającym integracji z shellem.
- CLI instalowane wyjątkowo przez Zinit wystawiaj przez `sbin`, nie przez
  `as"program"` i `pick`. Annexy Zinit ładuj synchronicznie, aby parser znał
  `sbin` od początku.
- `MISE_CONFIG_DIR` wskazuje bezpośrednio repozytorium
  `${HOME}/dotfiles/.config/mise`. `.zshenv` dodaje binarkę i shims do
  statycznego `PATH`; nie dodawaj `mise activate` ani hooków odświeżających env.
- Ustawienia maszynowe należą do ignorowanego
  `.config/mise/config.local.toml`. Przed zmianą składni lub backendu sprawdź
  aktualną dokumentację mise oraz bieżący config i live CLI.

## Wygląd

- Dla aplikacji z obsługą motywów preferuj Catppuccin Latte i przezroczyste
  tło, o ile aplikacja nie ma technicznego ograniczenia lub czytelność nie
  wymaga wyjątku.

## Decision log

- `docs/decision_log.md` jest krótkim inboxem trwałych decyzji, nie kroniką
  każdej naprawy. Po istotnym debugowaniu przygotuj propozycję opartą na
  dowodzie i poproś użytkownika o jawne zatwierdzenie przed dopisaniem.
- Powtarzalne zachowanie kieruj do jednego miejsca: tego pliku, zagnieżdżonego
  `AGENTS.md`, skilla, dokumentacji albo kodu/testu. Surowe batch'e zachowuj w
  `docs/decision_log/archive/`, a ich klasyfikację w indeksie obok archiwum.
