# Notatki dla AI Agents (skrót)

Ten plik definiuje minimalne, jednoznaczne zasady pracy w repo dotfiles.
Komentarze w kodzie/configach: po angielsku. Ten plik: po polsku.

## Zasady ogólne (MUST)

- Zachowuj istniejące komentarze; nowe komentarze w kodzie pisz po angielsku.
- Skrypt `install` musi mieć czytelny output: przed każdym większym krokiem
  wywołuj `print_banner('Opis kroku')`.
- Stosuj minimalne, celowe zmiany i trzymaj styl istniejącego kodu.
- Jeśli używasz jakiegoś warunku (np. `[[ ! -t 0 ]]`) więcej niż raz, wydziel go do funkcji pomocniczej (np. `is_interactive`).
- Jeśli funkcja pomocnicza jest używana tylko przez jedną funkcję, preferuj zadeklarowanie jej wewnątrz tej funkcji; globalny scope zostaw dla helperów współdzielonych.
- **Domyślnie używaj stow** do linkowania plików/katalogów, chyba że znajdziesz breaking case (np. katalog do którego aplikacja pisze runtime data).
- **Fail-fast w shell scripting** — jeśli komenda jest krytyczna dla decyzji logiki, nie używaj `2>/dev/null || true` ani fallbacków do domyślnych wartości (np. `main`, `default`). Fallback jest dopuszczalny tylko tam, gdzie "brak danych" jest prawidłowym stanem (np. optional completion). Jeśli wykryjesz taki wzorzec podczas audytu — zaproponuj poprawkę.
- Po debugowaniu jakiegos bledu / poprawkach przygotuj **draft** do `docs/decision_log.md` (nie dopisuj automatycznie) i zapytaj użytkownika: "Shall I append this to the decision log?"
  - Wpis musi zawierać: 1) **The Problem**, 2) **Root Cause**, 3) **The Fix**, 4) **Key Insight**, 5) **The Lesson**, 6) **Verification / Testing** (co było przetestowane + co NIE).

## Subagenci do ograniczonej pracy równoległej (MUST)

- **Domyślnie używaj subagentów proaktywnie, gdy są dostępni i istnieje użyteczny, niezależny oraz jasno ograniczony zakres pracy.** Główny agent musi delegować co najmniej jeden taki zakres, gdy zadanie obejmuje:
  - co najmniej dwa niezależne sprawdzenia składni, lintowania, testów, dry-runów lub innych walidacji;
  - długie albo obszerne logi, diffy, wygenerowane konfiguracje lub output wymagający osobnej inspekcji;
  - powtarzalne, mechaniczne zmiany w rozłącznych plikach, np. formatowanie, proste poprawki lintowania, aktualizacje testów lub dokumentacji;
  - niezależny second-pass review wymagany przez poniższą bramkę ryzyka.
- **Brama second-pass review:** zmiany, które mogą szeroko wpłynąć na maszynę lub kilka profili, wymagają niezależnego review po zakończeniu edycji, ale przed commitem, pushem albo autoryzowaną mutacją środowiska. Dotyczy to logiki `install`, topologii i targetów Stow, startu lub bootstrapa shella, instalowania i aktualizowania managerów CLI, obsługi sekretów/credentials oraz konfiguracji współdzielonej przez kilka profili. Rutynowa, odizolowana zmiana konfiguracji nie wymaga subagenta wyłącznie dlatego, że dotyczy jednego z tych narzędzi.
- Nie twórz subagenta wyłącznie do jednej krótkiej komendy ani do dzielenia ściśle powiązanej zmiany w jednym pliku bez użytecznego, niezależnego zakresu. Jeśli mimo dostępności subagentów nie ma sensownego zakresu do delegowania, krótko wyjaśnij dlaczego.
- Przed delegowaniem główny agent zapisuje baseline przez `git status --short`. Każdemu subagentowi podaje oczekiwany rezultat, dokładny zakres i ścieżki, dozwolone komendy, wymagane dowody oraz jednoznaczną zgodę albo zakaz edycji. Subagent raportuje wszystkie nowe lub zmienione pliki zauważone względem baseline'u i nie ingeruje w istniejące, niezwiązane zmiany.
- Uruchamiaj zakresy równolegle tylko wtedy, gdy nie mają zależności ani wspólnego mutowalnego stanu, np. indeksu Git, `$HOME`, cache'ów lub generowanych plików; w przeciwnym razie wykonuj je sekwencyjnie. Subagent może wykonywać tylko odizolowane, mechaniczne edycje w plikach, które nie nakładają się na pracę innych agentów. Zależne review i walidację uruchamiaj po zakończeniu edycji, a zmiany współdzielone, projektowe, security-sensitive i potencjalnie konfliktowe pozostaw głównemu agentowi.
- Subagenci nie wykonują operacji Git zmieniających indeks, historię lub stan wspólnego worktree: `git add`, `commit`, `push`, `merge`, `rebase`, `reset`, `checkout`, `restore`, `stash`, `clean` ani `pull`. Integracja, staging i publikacja zawsze należą do głównego agenta, także gdy użytkownik autoryzował finalny commit lub push.
- Delegowana walidacja jest read-only lub dry-run. Subagent nigdy nie stosuje konfiguracji do `$HOME` lub systemu, nie uruchamia `./install`, nie wykonuje Stow bez trybu `--no`, `mise use -g` ani `:Lazy sync`, nie instaluje i nie aktualizuje narzędzi oraz nie mutuje zarządzanego stanu poza repozytorium. Takie działania wykonuje wyłącznie główny agent, jeśli mieszczą się w autoryzowanym zakresie zadania i pozostałych zasadach repozytorium.
- Read-only nie oznacza zgody na dostęp do sekretów. Subagent nie odczytuje ani nie wypisuje wartości sekretów, tokenów, odpowiedzi Vault lub wygenerowanych credentials; pliki prywatne i stan poza repozytorium może sprawdzać tylko w dokładnie przydzielonym zakresie. Komendy i raportowane dowody muszą redagować dane wrażliwe.
- Delegowanie nie zmienia granic walidacji końcowej: `make test`, `make doctor` i `make verify` wolno uruchomić wyłącznie zgodnie z triggerem opisanym poniżej, a przekazanie ich subagentowi nie może tego triggera obchodzić. Gdy dozwolona walidacja jest długa lub obszerna i odpowiedni subagent jest dostępny, przekaż ją od początku zamiast uruchamiać w kontekście głównego agenta.
- Subagent raportuje dokładną komendę, exit status, zredagowane istotne fragmenty outputu lub diffu, ostrzeżenia i pominięte kroki. Samo podsumowanie `passed` nie jest wystarczającym dowodem.
- Główny agent pozostaje nadzorcą, integratorem i właścicielem końcowej decyzji: przegląda ustalenia oraz każdy wynikowy diff, analizuje błędy i ostrzeżenia, rozstrzyga sprzeczności i niezależnie sprawdza decydujące dowody przed raportem końcowym. Nie musi osobiście powtarzać każdej długiej komendy; jeśli potrzebny jest decydujący rerun, deleguje go innemu subagentowi, gdy taki jest dostępny.
- Delegowanie nigdy nie rozszerza zakresu ani uprawnień zadania. Subagenci podlegają tym samym zasadom bezpieczeństwa, testowania, Git i ochrony istniejących zmian co główny agent.
- Jeśli zakres, uprawnienia, dostęp do danych, ownership plików albo skutki uboczne delegowanego działania budzą wątpliwość, zatrzymaj się i zapytaj użytkownika przed delegowaniem lub kontynuowaniem. Nie interpretuj niejasnej zgody rozszerzająco.

## Granice testowania i walidacji końcowej (MUST)

- **Iteracja i bieżąca praca:** Podczas iteracyjnej implementacji, code review, raportowania statusu, wyjaśnień czy wprowadzania poprawek nie uruchamiaj pełnego zestawu testów przy każdej turze. Wykonuj wyłącznie sfokusowane sprawdzenia bezpośrednio powiązane ze zmienionymi plikami.
- **Wyzwalacz pełnej walidacji (trigger):** Standardowa prośba o review, status, wyjaśnienie czy poprawkę **nie jest** autoryzacją do uruchamiania pełnego, kosztownego suite'u. Pełną walidację końcową uruchamiaj wyłącznie po wyraźnym potwierdzeniu przez użytkownika, że przygotowujemy finalny commit, lub na jego bezpośrednie polecenie uruchomienia pełnej/końcowej walidacji.
- **Polecenia walidacji końcowej (zgodnie z README):**
  - `make test` — bezpośrednie uruchomienie offline'owego zestawu testów regresyjnych helperów Vault (`zsh tests/vault_test.zsh`).
  - `make doctor` — szybkie lokalne sprawdzenia repozytorium (składnia, dry-run GNU Stow, obecność wymaganych narzędzi) oraz testy `make test`.
  - `make verify` — rozszerzone sprawdzenia obejmujące cały zestaw `make doctor` wraz z weryfikacją dryfu środowiska (environment drift) i startu interaktywnej powłoki.

## Neovim: kiedy aktualizować README (MUST)

Zawsze aktualizuj `~/.config/nvim/README.md`, gdy:

- Dodajesz/usuwasz plugin (`lua/plugins/*.lua`) — dopisz/usuń sekcję w
  “🔌 Pluginy i ich użycie”.
- Zmieniasz keymapy (`lua/config/keymaps.lua`) — zaktualizuj “⌨️ Własne
  skróty klawiszowe”.
- Zmieniasz opcje (`lua/config/options.lua`) — zaktualizuj “⚙️ Core Options”
  (dodaj wyjaśnienie, jeśli nietypowe).
- Zmieniasz strukturę — zaktualizuj diagram i opisz nowe pliki.

### Struktura i organizacja nvim (MUST)

```text
.config/nvim/
├── init.lua
└── lua/
    ├── config/
    │   ├── lazy.lua
    │   ├── options.lua
    │   └── keymaps.lua
    └── plugins/
        └── *.lua   # jeden plugin = jeden plik
```

- Wszystkie keymaps trzymaj w `lua/config/keymaps.lua`.
- Opcje edytora trzymaj w `lua/config/options.lua`.

### Styl Lua (SHOULD)

- Komentarze nad kodem, zwięzłe i „dlaczego”, nie „co”.
- Używaj `require('which-key')` (spójnie z resztą).
- Zawsze dodawaj `desc` przy keymapach (for which-key).
- Plugin specs poprzedzaj krótkim komentarzem: `-- nazwa-pluginu — krótki opis`.

## Neovim: nadpisy per filetype (MUST)

- Preferuj `after/ftplugin/<filetype>.lua` dla per‑filetype opcji (np. zmiana `shiftwidth` w Markdown), zamiast autocmd w `options.lua`, chyba że istnieją powody techniczne, by tego nie robić (np. konflikt z pluginem wymagającym innego miejsca).
- Jeśli nadpisujesz zachowanie ftpluginów wbudowanych (np. Markdown: 2 spacje, `wrap/linebreak/breakindent`), dokumentuj to w `~/.config/nvim/README.md` i trzymaj logikę w `after/ftplugin/<filetype>.lua`.

### Workflow nowego pluginu (MUST)

1. Utwórz `lua/plugins/nazwa.lua`:

   ```lua
   -- nazwa - krótki opis
   return {
     'author/plugin',
     opts = {},
     config = function() end,
   }

   ```

2. Jeśli plugin ma keymaps — dodaj je w `lua/config/keymaps.lua` (z `desc`).
3. Zaktualizuj README: sekcja pluginu (+ keymaps, jeśli nowe).
4. Przetestuj: `:Lazy sync`, restart Neovim.

### Szablony do README (SHOULD)

Minimalne, spójne formaty:

- Plugin:

  ```markdown
  ### nazwa-pluginu — Krótki opis
  - Repo: https://github.com/autor/nazwa
  - Cel: do czego służy
  - Keymaps (jeśli są):
    - <leader>x — opis
    - :Komenda — opis
  - Dodatkowe: wymagania/tips
  ---
  ```

- Keybindings:

  ```markdown
  #### Nazwa kategorii
  - <Space>x — Opis akcji (:vim-command)
  - Ctrl+h — Opis akcji
  ```

### Checklist przed commitem zmian w Neovim

- [ ] Działa: `:Lazy sync`, restart Neovim.
- [ ] README zaktualizowany (pluginy + keymaps + options/struktura).
- [ ] Komentarze wyjaśniają „dlaczego”.
- [ ] Keymaps mają `desc`.
- [ ] Struktura repo = zgodna z README.

### Szybki mapping zadań (dla AI)

- „dodaj plugin X” → `lua/plugins/x.lua` + README (pluginy)
- „dodaj keybinding Y” → `keymaps.lua` + README (keymaps)
- „zmień opcję Z” → `options.lua` + README (options, jeśli istotne)
- „jak używać X?” → najpierw README, potem kod

### Źródła

- [Lazy.nvim](https://lazy.folke.io/)
- [which-key.nvim](https://github.com/folke/which-key.nvim)
- Neovim docs: `:help`

## Narzędzia CLI (tipy)

- Ripgrep wieloma wzorcami: `rg -n -e 'foo' -e 'bar'` lub `rg -n 'foo|bar'`.
- Ukryte pliki bez `.git`: `rg --hidden --glob '!.git/**' ...`.

## Zsh / Kubernetes

- Narzędzia k8s są lazy-loadowane przez funkcję `start-k8s-work()` w `.zsh/kubernetes.zsh`.
- Wywołanie `start-k8s-work` ładuje: aliasy (`k`, `kmurder`), funkcje (`kexec`, `kcRsh`, `kcEsh`), k9s, krew, completions (w tym `kubectl cnpg`).
- Dodając nowe narzędzia/completions k8s, umieszczaj je wewnątrz `start-k8s-work()`, nie w głównym `.zshrc`.

## Zsh / AI aliasy

- Aliasy dla tej samej aplikacji trzymaj obok siebie w jednej sekcji (np. `aa` i `aac` przy `app-cli` w `.zshrc`).
- Skróty nazw:
  - `aa` = `app-cli`
  - `aac` = `app-cli -c`
- Przy dodawaniu kolejnych aliasów do tej samej apki dopisz je w tym samym bloku, zamiast rozrzucać po plikach.


## Nowa konwencja wspolnego katalogu (`.agents/`)

**Konwencja:**
- Globalne skille: `~/.agents/skills/`

**Jak to działa w dotfiles:**
- Źródło w repo: `prv/.agents/`
- Główny stow z `prv/` linkuje to 1:1 do `~/.agents/`.

## Organizacja dotfiles (publiczne vs. desktop/private)

Wszystkie pliki konfiguracyjne są zarządzane za pomocą GNU Stow:
- **Konfiguracje publiczne i wspólne** (używane zarówno na desktopie, jak i serwerach, np. Neovim, tmux, Foot): powinny znajdować się w głównym katalogu repozytorium (np. `.config/foot/`, `.config/nvim/`).
- **Konfiguracje specyficzne dla profilu desktopowego / prywatne** (np. specyficzne dla środowiska KDE Plasma jak `klaunchrc`, ustawienia prywatne SSH, tmuxinator): muszą znajdować się w katalogu `prv/` (np. `prv/.config/klaunchrc`).
- Skrypt `install` automatycznie linkuje zawartość katalogu `prv/` do katalogu domowego użytkownika **tylko** wtedy, gdy profil to `desktop` (`is_desktop`).

## Themes i kolorystyka

- Wszystkie aplikacje TUI/GUI używają **Catppuccin** (domyślnie flavor `latte`).
- **Transparency jest preferowane** — terminal background powinien być widoczny przez aplikacje:
  - Neovim: `transparent_background = true` w `catppuccin.lua`
  - btop: `theme_background = false` w `btop.conf`
  - Przy dodawaniu nowych tooli z theme support — zawsze preferuj transparent background.

## Preferencje środowiskowe

- **NIE używaj direnv** - nie lubię hooków na zmianę katalogu. Per-project env rozwiązuję przez:
  - tmuxinator (sesje per projekt)
  - Docker/compose (izolacja środowiska)
- Unikaj dodawania nowych hooków do shell prompt/cd.

## Zsh / CLI managers (`zinit` vs `mise`)

- **Aktualna polityka profili:** `mise` jest instalowane i wymagane tylko dla
  profilu `desktop`. Na profilu `server` pozostaje opcjonalne: `update-all`
  aktualizuje je, jeśli jest dostępne, ale jego brak nie jest błędem. Zmień tę
  politykę dopiero, gdy pojawi się konkretny serwerowy use case, wartość albo
  blocker uzasadniający instalację. Poniższe reguły migracji i wyjątków nadal
  obowiązują przy wyborze standalone CLI, ale nie czynią `mise` wymaganiem
  serwerowym.
- `mise` backend `ubi:*` jest **deprecated**. Dla GitHub Releases używaj `github:owner/repo` zamiast `ubi:owner/repo`.
- Źródła prawdy (sprawdzaj przed zmianą):
  - https://mise.jdx.dev/
  - https://mise.jdx.dev/dev-tools/backends/github.html
  - https://mise.jdx.dev/dev-tools/backend_architecture.html
  - https://mise.jdx.dev/dev-tools/backends/ubi.html
  - `ubi` jest utrzymywane głównie dla kompatybilności; preferowany backend dla apek z GitHub Releases to `github`.
- Jeśli dokumentacja `mise` zmieni rekomendacje/semantykę i ten plik jest nieaktualny:
  - najpierw zaktualizuj instrukcje w `AGENTS.md`,
  - dopiero potem wdrażaj zmianę w `.zshrc` / `install`,
  - w opisie zmian dopisz co było outdated i jaka reguła została zaktualizowana.
- **Lokalizacja konfiguracji `mise`:**
  - Konfiguracja `mise` (zarówno `config.toml` jak i `config.local.toml`) jest zlokalizowana w repozytorium dotfiles w `.config/mise/`.
  - Aby zapobiec nadpisywaniu symlinków przez automatyczne zapisy `mise` (które zastępują symlinki zwykłymi plikami) oraz aby wyeliminować błąd `github.credential_command` ignorowanego w nieglobalnych konfiguracjach (CVE-2026-55448), cała globalna konfiguracja `mise` jest kierowana bezpośrednio do repozytorium za pomocą zmiennej środowiskowej `export MISE_CONFIG_DIR="${HOME}/dotfiles/.config/mise"` w `.zshenv`.
  - `.zshenv` dodaje standalone `mise` i jego shims do `PATH` bez `mise activate`; celowo nie instalujemy hooków aktywacyjnych `precmd`/`chpwd` ani automatycznego odświeżania env przy zmianie katalogu.
  - Dzięki temu polecenia `mise use -g` zapisują konfigurację bezpośrednio do repozytorium dotfiles.
  - Maszynowo-specyficzne (lokalne) konfiguracje powinny być dopisywane do `config.local.toml` w tym samym katalogu (jest on zignorowany w `.gitignore`, więc nie trafi do gita).


### Reguły decyzyjne (MUST)

- **Nowe standalone CLI** dodawaj domyślnie przez `mise`.
- `zinit` zostaw dla:
  - pluginów shellowych (autosuggestions, syntax-highlighting, snippets),
  - przypadków gdzie kluczowa jest integracja z frameworkiem `zinit` (np. specyficzne hooki `atclone/atpull/src`).
- **Instalacja CLI przez Zinit:** Dla narzędzi CLI instalowanych przez `zinit` (np. jako wyjątki) **zawsze używaj modyfikatora `sbin`** (z `zinit-annex-bin-gem-node`) zamiast `as"program"` i `pick`. Unika to zanieczyszczania `$PATH` katalogami wtyczek, co powodowało, że pliki pomocnicze (np. manpage `just.1`, foldery wersji, pliki markdown) były traktowane przez Zsh jako polecenia i pokazywały się w autouzupełnianiu.
  - **Ważne:** Dodatki Zinit (annexy) muszą być ładowane synchronicznie (bez `wait`), aby parser Zinit od startu powłoki rozpoznawał słowa kluczowe takie jak `sbin` (w przeciwnym razie wyrzuci błąd `Unknown subcommand sbin...`).
- Wyjątki zaakceptowane: `atuin`, `starship`, `just` i `dust` zostają w `zinit` (shell init/completions lub świadoma decyzja maintainerska).
- Przy każdej nowej binarce dopisz krótko w opisie zmiany: dlaczego `mise` albo dlaczego wyjątek i zostaje `zinit`.
- Aktualizacje:
  - `update-all` ma aktualizować pluginy `zinit`, samo `mise` i narzędzia zarządzane przez `mise`,
  - docelowo ograniczamy binarki w `zinit` na rzecz `mise`.

### Inwentaryzacja (stan obecny) i kierunek migracji

- `git-fixup` — natywna funkcja Zsh w `.zshrc`; brak zewnętrznej binarki.
- `@casey/just` (`just`) — zostaje w `zinit` (intentional exception).
- `@cli/cli` (`gh`) — uses mise registry shorthand `github-cli`.
- `@jdx/mise` (`mise`) — bootstrapowane tylko dla profilu `desktop` z wersjonowanego oficjalnego release installera do `~/.local/bin/mise`; wersja i SHA-256 installera są przypięte w `Makefile`; nie jest zarządzane przez `zinit`.
- `@jdx/usage` (`usage`) — installed via `mise use -g usage` (no longer in zinit).
- `@openai/codex` (`codex`) — uses explicit `aqua:openai/codex` backend to avoid registry shorthand drift.
- `@yt-dlp/yt-dlp` (`yt-dlp`) — uses mise registry shorthand `yt-dlp`.
- `@steipete/summarize` (`summarize`) — managed via `mise` (`npm` backend; not in registry).
- `@zewelor/sourcetap` (`sourcetap`) — uses `mise` GitHub backend as a standalone user-owned CLI with GitHub Releases.
- `@anomalyco/opencode` (`opencode`) — uses the `mise` GitHub backend; `install` persists the upstream `-baseline` asset override in `config.local.toml` on Linux x86_64 CPUs without AVX2.
- `@atuinsh/atuin` (`atuin`) — zostaje w `zinit` (intentional exception: shell init/completions).
- `starship/starship` (`starship`) — zostaje w `zinit` (intentional exception: shell init/completions).

### Checklist migracji pojedynczego narzędzia

- Potwierdź w docs `mise` aktualny backend/format wpisu.
- Dodaj narzędzie przez `mise` (preferuj `github:owner/repo` dla GitHub Releases).
- Usuń/ogranicz odpowiedni wpis `zinit` dopiero po weryfikacji działania completions/init.
- Sprawdź `update-all` i potwierdź, że aktualizacja działa przez sekcję `[mise]`.
