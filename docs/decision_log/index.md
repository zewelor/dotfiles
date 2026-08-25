# Decision log archive index

Ten indeks klasyfikuje 21 wpisów z pierwszego, niezmiennego archiwum. Archiwum
jest materiałem dowodowym, nie aktywną instrukcją. Przed użyciem historycznej
decyzji sprawdź wskazane aktualne źródło prawdy.

## Batch `through-2026-08-22`

- Źródło: [`archive/through-2026-08-22.md`](archive/through-2026-08-22.md)
- Zakres nagłówków: 2026-02-20–2026-08-22 (kolejność w źródle nie jest
  chronologiczna)
- Integralność: SHA-256
  `e9729d6e6fbb5ae4265481dbbcb60b91833e51a86ef5bc50f77bb07507fa7796`
- Liczba wpisów: 21

Klasyfikacje: `root` — trwała reguła przekrojowa; `docs` — wyjaśnienie lub
runbook; `enforcement` — zachowanie lepiej utrzymywane kodem/testem;
`history` — kontekst bez aktywnej mocy; `stale` — rozwiązanie zastąpione.

| Data i wpis (źródło) | Klasyfikacja | Miejsce docelowe / źródło prawdy | Najkrótszy dowód | Pewność i aktualność |
| --- | --- | --- | --- | --- |
| [2026-06-20 — Zsh completion uses plugin `sbin`](archive/through-2026-08-22.md?plain=1#L3) | root, enforcement | `AGENTS.md`, `.zshrc` | `sbin` udostępnia CLI bez ręcznego rozszerzania `PATH` | wysoka, aktualne |
| [2026-06-11 — Shell startup must stay lightweight](archive/through-2026-08-22.md?plain=1#L33) | root, enforcement | `AGENTS.md`, `.zshrc`, pomiar startu | synchroniczne probe'y blokowały start shella | wysoka, aktualne |
| [2026-06-11 — Neovim startup must stay lightweight](archive/through-2026-08-22.md?plain=1#L62) | docs, enforcement | `.config/nvim/README.md`, konfiguracja Neovim | kosztowne działania przy starcie pogarszają UX | wysoka, aktualne |
| [2026-02-20 — Selected CLI tools managed by mise](archive/through-2026-08-22.md?plain=1#L90) | stale, history | `.config/mise/config.toml` | statyczna lista narzędzi przestała być wiarygodna | wysoka, zastąpione |
| [2026-03-01 — Dockerfile filetype configuration](archive/through-2026-08-22.md?plain=1#L124) | docs, enforcement | `.config/nvim/after/ftplugin/`, `.config/nvim/README.md` | zachowanie jest per-filetype | wysoka, aktualne |
| [2026-03-01 — Dockerfile save behavior](archive/through-2026-08-22.md?plain=1#L156) | docs, enforcement | konfiguracja Neovim i jej test/README | źródłem prawdy jest działająca konfiguracja | wysoka, aktualne |
| [2026-03-04 — Zellij rollout rolled back](archive/through-2026-08-22.md?plain=1#L185) | history | archiwum; obecny terminal workflow w kodzie/README | rollout został jawnie cofnięty | wysoka, historyczne |
| [2026-03-05 — `gws` and tmux color handling](archive/through-2026-08-22.md?plain=1#L216) | history, stale | aktualne pliki terminala/tmux | część konfiguracji terminala zmieniła się później | średnia, częściowo nieaktualne |
| [2026-03-07 — `tat` tmux helper](archive/through-2026-08-22.md?plain=1#L250) | docs, enforcement | `.zshrc`, dokumentacja shella | helper jest implementowany w konfiguracji | wysoka, aktualne |
| [2026-03-08 — Codex installed from npm](archive/through-2026-08-22.md?plain=1#L283) | stale, history | `.config/mise/config.toml` i bieżący `mise` | backend instalacji został później zmieniony | wysoka, zastąpione |
| [2026-04-01 — Remove generated `.zwc` files](archive/through-2026-08-22.md?plain=1#L310) | root, enforcement | `AGENTS.md`, `.zshrc` / ignore rules | generowane cache nie powinny należeć do repo | wysoka, aktualne |
| [2026-04-10 — blink.cmp fallback behavior](archive/through-2026-08-22.md?plain=1#L338) | docs, enforcement | konfiguracja Neovim, `.config/nvim/README.md` | zachowanie zależy od aktualnej konfiguracji pluginu | wysoka, aktualne |
| [2026-04-16 — beautysh formatting](archive/through-2026-08-22.md?plain=1#L365) | docs, enforcement | konfiguracja Neovim i formattera | reguła jest domenowa i mechaniczna | wysoka, aktualne |
| [2026-04-24 — Fail fast on install errors](archive/through-2026-08-22.md?plain=1#L393) | root, enforcement | `AGENTS.md`, `install`, testy | kontynuacja po błędzie tworzy częściowy stan | wysoka, aktualne |
| [2026-05-03 — `nvim_pod` Kubernetes helper](archive/through-2026-08-22.md?plain=1#L424) | docs, enforcement | `.zsh/kubernetes.zsh` | implementacja helpera jest źródłem prawdy | wysoka, aktualne |
| [2026-05-22 — Do not export `GIT_PAGER` globally](archive/through-2026-08-22.md?plain=1#L456) | stale, root | globalne instrukcje agenta, `.zshenv` | globalny eksport kolidował z interaktywnym `delta` | wysoka, zastąpione regułą globalną |
| [2026-06-04 — Treesitter runtimepath handling](archive/through-2026-08-22.md?plain=1#L485) | docs, enforcement | konfiguracja Neovim, `.config/nvim/README.md` | zachowanie jest szczegółem ładowania pluginu | wysoka, aktualne |
| [2026-06-23 — bird release-age handling](archive/through-2026-08-22.md?plain=1#L515) | enforcement, history | `.config/mise/config.toml` | ustawienie jest jawne w konfiguracji narzędzia | wysoka, aktualne |
| [2026-07-02 — `MISE_CONFIG_DIR` points to repo](archive/through-2026-08-22.md?plain=1#L544) | root, enforcement | `AGENTS.md`, `.zshenv`, `install`, mise config | jeden bezpośredni katalog usuwa duplikację stanu | wysoka, aktualne |
| [2026-07-10 — Codex uses Aqua backend](archive/through-2026-08-22.md?plain=1#L573) | enforcement, history | `.config/mise/config.toml`, bieżący `mise` | identyfikator backendu jest zapisany w configu | wysoka, aktualne, wersja zmienna |
| [2026-08-22 — Storage Box provisioning boundary](archive/through-2026-08-22.md?plain=1#L603) | root, docs, enforcement | `AGENTS.md`, README/helper/testy | wpisy `/etc`, mount i sekrety wymagają granicy operatora | wysoka, aktualne |

## Zasady utrzymania indeksu

- Każdy przyszły batch dostaje osobny, niezmienny plik w `archive/`, checksumę
  i liczbę wpisów.
- Indeks wskazuje aktualne miejsce docelowe; nie kopiuje pełnej treści decyzji.
- Zmiana klasyfikacji lub aktualności nie modyfikuje surowego archiwum.
- `history` i `stale` nie są kandydatami do `AGENTS.md` bez nowych dowodów.
