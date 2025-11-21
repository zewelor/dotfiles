# Notatki dla AI Agents (skrót)

Ten plik definiuje minimalne, jednoznaczne zasady pracy w repo dotfiles.
Komentarze w kodzie/configach: po angielsku. Ten plik: po polsku.

## Zasady ogólne (MUST)

- Zachowuj istniejące komentarze; nowe komentarze w kodzie pisz po angielsku.
- Skrypt `install` musi mieć czytelny output: przed każdym większym krokiem
  wywołuj `print_banner('Opis kroku')`.
- Stosuj minimalne, celowe zmiany i trzymaj styl istniejącego kodu.
- Jeśli używasz jakiegoś warunku (np. `[[ ! -t 0 ]]`) więcej niż raz, wydziel go do funkcji pomocniczej (np. `is_interactive`).

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
