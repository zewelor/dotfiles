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
- Po debugowaniu jakiegos bledu / poprawkach przygotuj **draft** do `docs/decision_log.md` (nie dopisuj automatycznie) i zapytaj użytkownika: "Shall I append this to the decision log?"
  - Wpis musi zawierać: 1) **The Problem**, 2) **Root Cause**, 3) **The Fix**, 4) **Key Insight**, 5) **The Lesson**, 6) **Verification / Testing** (co było przetestowane + co NIE).

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

## Claude Code (`.claude/`)

Katalog `.claude/` jest **ignorowany przez główny stow** (w `.stow-local-ignore`), ale `setup_claude()` używa **osobnego wywołania stow** do linkowania jego zawartości.

**Dlaczego osobne wywołanie?** Claude Code zapisuje w `~/.claude/` swoje dane runtime (history, plans, todos, projects, credentials). Główny stow linkowałby cały `~/.claude` jako symlink — wtedy Claude pisałby do repo git. Osobne wywołanie `stow -t ~/.claude .claude` tworzy `~/.claude/` jako prawdziwy katalog i linkuje tylko wybrane elementy.

**Co linkujemy do `~/.claude/`:**
- `settings.json` — globalne ustawienia
- `status-line.sh`, `claude-code-notifier.sh` — skrypty pomocnicze

**Co NIE linkujemy:**
- `settings.local.json` — to jest plik **per-project** dla tego repo dotfiles! Zawiera permissions które Claude Code używa gdy pracuje w tym katalogu. NIE kopiować do `~/.claude/`.
- `skills/` — skille trzymamy globalnie w `prv/.agents/skills` i linkujemy przez zwykły stow z `prv/`

**Dodając nowy skill:**
1. Utwórz katalog w `prv/.agents/skills/<nazwa>/`
2. Dodaj `SKILL.md` (wymagany przez Claude Code)
3. Uruchom `./install` (lub `make skills`) — stow z `prv/` automatycznie odświeży linki

## Nowa konwencja wspolnego katalogu (`.agents/`)

**Konwencja:**
- Globalne skille: `~/.agents/skills/`

**Jak to działa w dotfiles:**
- Źródło w repo: `prv/.agents/`
- Główny stow z `prv/` linkuje to 1:1 do `~/.agents/`.

## Preferencje środowiskowe

- **NIE używaj direnv** - nie lubię hooków na zmianę katalogu. Per-project env rozwiązuję przez:
  - tmuxinator (sesje per projekt)
  - Docker/compose (izolacja środowiska)
- Unikaj dodawania nowych hooków do shell prompt/cd.

## Zsh / CLI managers (`zinit` vs `mise`)

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

### Reguły decyzyjne (MUST)

- **Nowe standalone CLI** dodawaj domyślnie przez `mise`.
- `zinit` zostaw dla:
  - pluginów shellowych (autosuggestions, syntax-highlighting, snippets),
  - przypadków gdzie kluczowa jest integracja z frameworkiem `zinit` (np. specyficzne hooki `atclone/atpull/src`).
- Wyjątki zaakceptowane: `atuin`, `starship`, `just`, `git-fixup` i `dust` zostają w `zinit` (shell init/completions, brak kompatybilnego backendu lub świadoma decyzja maintainerska).
- Przy każdej nowej binarce dopisz krótko w opisie zmiany: dlaczego `mise` albo dlaczego wyjątek i zostaje `zinit`.
- Aktualizacje:
  - `update-all` ma aktualizować zarówno `zinit`, jak i `mise` (okres przejściowy),
  - docelowo ograniczamy binarki w `zinit` na rzecz `mise`.

### Inwentaryzacja (stan obecny) i kierunek migracji

- `@keis/git-fixup` (`git-fixup`) — zostaje w `zinit` (brak działającego źródła `mise github:*`; repo nie publikuje Releases pod `latest`).
- `@casey/just` (`just`) — zostaje w `zinit` (intentional exception).
- `@cli/cli` (`gh`) — fala 1 migracji do `mise` (standalone CLI).
- `@jdx/mise` (`mise`) — może zostać w `zinit` jako bootstrap, ale rozważyć system package lub self-hosted install dla uproszczenia łańcucha zależności.
- `@jdx/usage` (`usage`) — zależność completion dla `mise`; migrować razem z decyzją jak instalowany jest `mise`.
- `@openai/codex` (`codex`) — fala 1 migracji do `mise` (standalone CLI).
- `npm:@steipete/summarize` (`summarize`) — zarządzane przez `mise` (backend `npm`, brak binarek Linux na GitHub).
- `@anomalyco/opencode` (`opencode`) — kandydat do `mise` (standalone CLI).
- `@atuinsh/atuin` (`atuin`) — zostaje w `zinit` (intentional exception: shell init/completions).
- `starship/starship` (`starship`) — zostaje w `zinit` (intentional exception: shell init/completions).

### Checklist migracji pojedynczego narzędzia

- Potwierdź w docs `mise` aktualny backend/format wpisu.
- Dodaj narzędzie przez `mise` (preferuj `github:owner/repo` dla GitHub Releases).
- Usuń/ogranicz odpowiedni wpis `zinit` dopiero po weryfikacji działania completions/init.
- Sprawdź `update-all` i potwierdź, że aktualizacja działa przez sekcję `[mise]`.
