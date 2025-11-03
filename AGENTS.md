# Notatki dla AI Agents

Ten plik zawiera instrukcje i przypomnienia dla AI asystentów (GitHub Copilot, Cline, itp.) pracujących nad tym repozytorium dotfiles.

## 📝 Zasady aktualizacji dokumentacji

### Neovim (`.config/nvim/`)

**WAŻNE**: Przy każdej zmianie w konfiguracji Neovim, ZAWSZE aktualizuj `README.md`!

README.md ma być po angielsku i zawierać

#### Kiedy aktualizować README.md:

1. **Dodanie/usunięcie pluginu** (`lua/plugins/*.lua`)
   - Dodaj/usuń sekcję w "🔌 Pluginy i ich użycie"
   - Opisz cel pluginu, repo, podstawowe komendy

2. **Zmiana keybindingów** (`lua/config/keymaps.lua`)
   - Aktualizuj sekcję "⌨️ Własne skróty klawiszowe"
   - Uporządkuj według kategorii (Leader / bez Leadera)
   - Zachowaj podział na podsekcje

3. **Zmiana opcji edytora** (`lua/config/options.lua`)
   - Zaktualizuj tabelę w "⚙️ Core Options"
   - Dodaj wyjaśnienie jeśli opcja jest nietypowa

4. **Zmiana struktury plików** (dodanie nowych modułów)
   - Zaktualizuj diagram struktury w "### Struktura konfiguracji"
   - Dodaj komentarz co robi nowy plik

#### Format dokumentacji pluginów w README.md:

```markdown
### **nazwa-pluginu** — Krótki opis

- **Repo**: [autor/nazwa](https://github.com/autor/nazwa)
- **Cel**: Szczegółowy opis do czego służy
- **Keymaps** (jeśli są):
  - `<leader>x` — opis akcji
  - `:Komenda` — opis komendy
- **Dodatkowe info**: Requirements, setup, tips

---
```

#### Format keybindingów w README.md:

```markdown
#### Nazwa kategorii

- `<Space>x` — Opis akcji (`:vim-command`)
- `Ctrl+h` — Opis akcji
```

## 🔧 Struktura projektu

### Neovim config (`~/.config/nvim/`)

```
.config/nvim/
├── init.lua              # Entry point
├── lua/
│   ├── config/
│   │   ├── lazy.lua     # Plugin manager setup
│   │   ├── options.lua  # vim.opt ustawienia
│   │   └── keymaps.lua  # Wszystkie keybindings
│   └── plugins/         # Każdy plugin = osobny plik
│       ├── *.lua        # Auto-importowane przez lazy.nvim
```

### Zasady organizacji

1. **Jeden plugin = jeden plik** w `lua/plugins/`
2. **Wszystkie keymaps w jednym miejscu**: `lua/config/keymaps.lua`
3. **Opcje edytora oddzielnie**: `lua/config/options.lua`
4. **README.md zawsze aktualny** z listą pluginów i keymaps

## 🎨 Styl kodu Lua

```lua
-- Komentarze nad kodem, nie z boku
local variable = "value"

-- Używaj require("which-key") zamiast require "which-key"
local wk = require("which-key")

-- Keymaps z opisami:
vim.keymap.set("n", "<leader>x", ":Command<CR>", { desc = "Human readable description" })

-- Plugin specs zawsze z komentarzem na początku:
-- nazwa-pluginu - krótki opis do czego służy
return {
  "author/plugin-name",
  -- ...
}
```

## 🚀 Workflow dodawania nowego pluginu

1. **Stwórz plik** `lua/plugins/nazwa.lua`:
   ```lua
   -- nazwa - opis
   return {
     "author/plugin",
     opts = {},
     config = function() end,
   }
   ```

2. **Jeśli plugin ma keymaps**, dodaj je do `lua/config/keymaps.lua`

3. **Zaktualizuj README.md**:
   - Dodaj sekcję w "🔌 Pluginy"
   - Zaktualizuj "⌨️ Własne skróty klawiszowe" jeśli są nowe

4. **Testuj**: `:Lazy sync` i sprawdź czy działa

## 📋 Checklist przed commitem zmian w Neovim

- [ ] Kod działa (`:Lazy sync`, restart Neovim)
- [ ] README.md zaktualizowany (pluginy + keymaps)
- [ ] Komentarze w kodzie opisują "dlaczego", nie "co"
- [ ] Keymaps mają `desc` property dla which-key
- [ ] Struktura w README.md zgadza się z rzeczywistością

## 🤖 Dla AI Agents: Szybki checklist

Gdy użytkownik prosi o:

- **"dodaj plugin X"** → stwórz `lua/plugins/x.lua` + aktualizuj README.md (sekcja pluginy)
- **"dodaj keybinding Y"** → edytuj `keymaps.lua` + aktualizuj README.md (sekcja keymaps)
- **"zmień opcję Z"** → edytuj `options.lua` + aktualizuj README.md (sekcja options, jeśli istotne)
- **"jak używać X?"** → sprawdź README.md najpierw, potem kod

## 📚 Źródła

- Lazy.nvim docs: <https://lazy.folke.io/>
- Which-key.nvim: <https://github.com/folke/which-key.nvim>
- Neovim docs: `:help` w Neovim

---

**Pamiętaj**: README.md to źródło prawdy dla użytkownika. Kod może się zmienić, ale dokumentacja musi być aktualna!
