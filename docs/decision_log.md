# Decision Log

## 2026-06-11 — Optimize shell startup time & fix KDE Plasma 6 Wayland application launch delay

1. **The Problem**
Starting a new terminal window (Foot/Alacritty) via global hotkeys or launchers in KDE Plasma 6 Wayland was delayed by ~2 seconds, showing a blank screen inside the window before the Zsh prompt rendered, even though `zinit times` showed very low plugin load times (~57ms).

2. **Root Cause**
- **Shell Startup (minor):** `.zsh/docker.zsh` executed `docker compose version` synchronously on startup (adding 50ms), and `.zshrc` executed an unused `DEFAULT_USER` variable via a slow `whoami` subshell call.
- **KDE Launcher Delay (major):** In KDE Plasma 6 Wayland, applications started via hotkeys or desktop files are wrapped in systemd transient user services (`systemd-run`). Due to D-Bus/systemd integration timeouts or environment sync delays, the launcher blocks for exactly 2 seconds before executing the application's command, leading to the blank startup state.

3. **The Fix**
- Replaced the synchronous `docker compose version` in `.zsh/docker.zsh` with a filesystem-based check for the compose binary/plugin path.
- Removed the unused `DEFAULT_USER` export entirely from `.zshrc`.
- Configured Zinit to defer all `wait` plugins to `wait"1"` instead of `wait"0"` to prevent blocking the first prompt render.
- Disabled KDE's systemd transient unit wrapping globally by setting `_KDE_APPLICATIONS_AS_FORKING=1` in `~/.config/environment.d/10-kde-no-systemd.conf` (stowed under `prv/.config/environment.d/10-kde-no-systemd.conf`).

4. **Key Insight**
- App launch latency in Wayland desktop environments is often caused by compositor/service integration wrappers (like `systemd-run`). If GUI apps open instantly when launched from an existing terminal but take 2 seconds via system shortcuts, the wrapper is the bottleneck.

5. **The Lesson**
- Always isolate shell startup issues from compositor launch delays by testing execution inside an existing terminal. Bypassing systemd transient wrappers in KDE (via `_KDE_APPLICATIONS_AS_FORKING=1` environment variable) can resolve app-launch freezes.

6. **Verification / Testing**
Tested:
- Confirmed that shell startup time is ~140ms and prompt drawing completes in 416ms using PTY execution traces.
- Verified that running `foot` or `alacritty` inside another terminal launches instantly.
- Verified that `~/.config/environment.d/10-kde-no-systemd.conf` has `_KDE_APPLICATIONS_AS_FORKING=1` configured correctly and is managed by GNU Stow.

Not tested:
- Performance after logging out/in (requires user action to reload KDE Plasma config).

## 2026-06-11 — Optimize Neovim startup time (LSP mise which & Telescope lazy loading)

1. **The Problem**
Neovim startup time was very slow (~2 seconds), particularly noticeable when opening Markdown files.

2. **Root Cause**
- The LSP configuration (`lua/plugins/lsp.lua`) defined a helper function `mise_bin(tool)` that used `vim.fn.system({ "mise", "which", tool })` to locate `ruby-lsp` and `rubocop` synchronously on startup, blocking the UI thread.
- `telescope.nvim` was loaded synchronously during startup despite only being used via keymaps.

3. **The Fix**
- Modified `mise_bin(tool)` in `lua/plugins/lsp.lua` to check if the tool is already executable in the environment's `PATH` (`vim.fn.executable(tool) == 1`) before executing `mise which` synchronously.
- Added `cmd = "Telescope"` to the plugin specification in `lua/plugins/telescope.lua` to defer its loading until first use.

4. **Key Insight**
Calling synchronous external shell commands and loading heavy UI plugins on startup are major performance hazards. Defer UI plugins using lazy triggers and check the path via `vim.fn.executable()` before calling external tools.

5. **The Lesson**
Avoid executing synchronous shell commands on startup. Ensure non-essential plugins (like fuzzy finders) are lazy loaded to keep startup time minimal.

6. **Verification / Testing**
Tested:
- Checked startup time with `--startuptime` when launching Neovim directly and opening `README.md`.
- Startup time dropped from ~2.0 seconds down to ~118-150 milliseconds.
- Verified that `ruby-lsp` and `rubocop` are still resolved correctly, and Telescope commands (`<leader>ff`, `<leader>fg`) load and run Telescope on demand.

Not tested:
- Startup in environments where `mise` is not active in the shell PATH (which will still trigger the fallback `system` call, but only if needed).

## 2026-02-20 — Migrate selected CLI tools to mise (github backend)

1. **The Problem**
`codex` and `yt-dlp` installed via `mise github` were not consistently exposed under expected command names (`codex`, `yt-dlp`) because upstream releases publish multiple assets and filename variants.

2. **Root Cause**
Asset autodetection selected valid but undesired binaries (`codex-responses-api-proxy*`, `yt-dlp_linux`). Existing config also mixed prior backend mappings, which caused shim resolution confusion.

3. **The Fix**
- Migrated selected tools from `zinit` to `mise` in `install`.
- Configured deterministic GitHub backend selectors:
  - `github:openai/codex[asset_pattern=codex-x86_64-unknown-linux-musl.tar.gz,rename_exe=codex]@latest`
  - `github:yt-dlp/yt-dlp[asset_pattern=yt-dlp_linux.zip,rename_exe=yt-dlp]@latest`
- Kept `just`, `atuin`, and `starship` in `zinit` by policy.
- Removed unused shell helper functions for yt-dlp from `.zshrc`.

4. **Key Insight**
For multi-asset GitHub releases, relying on backend autodetection is fragile. `asset_pattern` + `rename_exe` makes tool resolution deterministic and shell-friendly.

5. **The Lesson**
When managing CLI tools via `mise github`, explicitly encode asset selection for tools with multiple release artifacts. This avoids command-name drift and backend alias ambiguity.

6. **Verification / Testing**
Tested:
- `./install` (desktop profile) completed successfully.
- Fresh login shell (`zsh -l`) resolves commands correctly.
- Version checks passed for `codex`, `gh`, `yt-dlp`.
- `pipx` no longer contains `yt-dlp`.
- `mise ls` shows only the intended backends for migrated tools.

Not tested:
- Full media workflow for yt-dlp with conversion paths requiring `ffmpeg`.
- Extended `codex` authenticated runtime scenario beyond version/help checks.

## 2026-03-01 — Consolidate Dockerfile indentation to one ftplugin

1. **The Problem**
Dockerfile indentation logic for `RUN` blocks needed to support nested shell bodies (`if/for/while/case`) with `+2` spaces, and the first compatibility approach duplicated behavior across two ftplugin files.

2. **Root Cause**
Compatibility for alternate Dockerfile filename variants was handled by adding a second wrapper ftplugin that sourced `dockerfile.lua`, which increased maintenance overhead and config surface.

3. **The Fix**
- Kept a single authoritative ftplugin: `after/ftplugin/dockerfile.lua`.
- Removed the compatibility wrapper ftplugin.
- Added filetype aliasing in `lua/config/options.lua` for Dockerfile filename variants.
- Updated `.config/nvim/README.md` to document the single-file setup and behavior.

4. **Key Insight**
For this case, filetype aliasing is cleaner than ftplugin forwarding: one filetype (`dockerfile`) means one indentation implementation and fewer moving parts.

5. **The Lesson**
Prefer central filetype mapping over duplicate per-filetype ftplugin wrappers when behavior is identical.

6. **Verification / Testing**
Tested:
- `make doctor` (syntax checks, stow dry-run, tool versions).
- Headless Neovim on `/home/omen/personal/pingodoce/Dockerfile` confirmed:
  - `filetype=dockerfile`
  - `indentexpr=v:lua.DockerfileRunIndent()`
  - `if` lines at 4 spaces and nested body lines at 6 spaces.
- Headless Neovim on Dockerfile filename variants confirmed filetype aliasing to `dockerfile` and identical indentation behavior.

Not tested:
- Manual interactive typing flow in a live Neovim UI session (Enter/o-based editing ergonomics).

## 2026-03-01 — Preserve Dockerfile RUN indentation on save

1. **The Problem**
Custom Dockerfile indentation worked while typing (`<CR>`/`o`) and manual reindent (`==`, `gg=G`), but saving the file could revert nested `RUN` shell block indentation back to 4 spaces.

2. **Root Cause**
`conform.nvim` was configured with `format_on_save` + `lsp_format = "fallback"` for most filetypes, and `dockerls` exposes document formatting. On `:w`, LSP formatting flattened nested shell body indentation inside `RUN`.

3. **The Fix**
- Updated `.config/nvim/lua/plugins/conform.lua` to skip autoformat on save for `dockerfile` (and existing `markdown` skip remains).
- Kept the Dockerfile-specific `indentexpr` as the source of indentation behavior.
- Updated `.config/nvim/README.md` to document that Dockerfile is intentionally excluded from format-on-save.

4. **Key Insight**
An LSP formatter can silently override custom indentation logic on save, even when editing behavior appears correct during insert/reindent operations.

5. **The Lesson**
When using custom filetype indentation rules, verify save-time formatter hooks (`BufWritePre`/format-on-save) and explicitly exclude conflicting filetypes.

6. **Verification / Testing**
Tested:
- `make doctor`.
- Reproduced root cause with active `dockerls`: `conform.format({ lsp_format = "fallback" })` flattened nested RUN shell indentation from 6 to 4 spaces.
- After fix, with active `dockerls`, `:w` no longer changed nested RUN indentation.
- Verified on `/home/omen/personal/pingodoce/Dockerfile` behavior path via headless Neovim flow.

Not tested:
- Manual long interactive session with mixed formatting commands across multiple Dockerfiles.

## 2026-03-04 — Roll back Zellij integration and return to tmuxinator-first workflow

1. **The Problem**
Zellij required multiple behavioral workarounds to match existing tmuxinator project workflows (eg. pre-window shell setup, IDE pane lifecycle, and predictable project startup), which increased friction and maintenance cost.

2. **Root Cause**
The previous migration attempted to replicate tmuxinator-specific orchestration semantics in Zellij. This led to custom bootstrap scripts, layout coupling, and shell glue that still diverged from expected day-to-day behavior.

3. **The Fix**
- Removed Zellij from desktop tool installation in `install`.
- Removed Zellij helper flow from `.zshrc` (`zux` and related logic).
- Deleted all tracked Zellij configs/layouts/themes under `.config/zellij/`.
- Deleted Zellij bootstrap helper scripts under `.local/bin/`.
- Updated `README.md` to document `tmuxinator` (`mux`) as the project-session path.
- Removed Zellij version check from `Makefile` doctor output.

4. **Key Insight**
When the operational model depends on tmuxinator conventions, forcing parity through another multiplexer can produce disproportionate complexity compared to the practical benefit.

5. **The Lesson**
Prefer the stable, lower-maintenance workflow already aligned with daily usage. Revisit Zellij only when native capabilities cover required project lifecycle behavior without shell-level workarounds.

6. **Verification / Testing**
Tested:
- `zsh -n .zshrc install` passed after cleanup.
- `README.md` and `install` references were updated to remove Zellij guidance/install.
- Repo search confirmed no active `zellij` / `zux` operational references in shell workflow files.

Not tested:
- Full interactive end-to-end tmuxinator project startup for every project profile in `prv/.tmuxinator/*.yml`.

## 2026-03-05 — Restore gws scope readability and stabilize tmux statusline colors

1. **The Problem**
`gws auth login` scope names were barely readable in Solarized Light, and after improving terminal palette contrast, the tmux bottom statusline looked wrong.

2. **Root Cause**
`gws` uses ANSI color roles (including white/dim variants) for scope rows. In Solarized Light, the previous ANSI white values were too close to background (`#eee8d5` and `#fdf6e3` on `#fdf6e3`). tmux statusline used palette-based colors (`colour7`), so terminal ANSI palette adjustments propagated into tmux UI.

3. **The Fix**
- Updated Alacritty Solarized Light palette to increase readability for `dim`, `normal white`, and `bright white`.
- Added Ghostty readability safeguards: `faint-opacity = 1.0`, `minimum-contrast = 3`, and explicit palette overrides for ANSI white slots (7, 15).
- Updated tmux statusline/window styles to explicit Solarized hex colors, decoupling statusbar appearance from terminal ANSI palette shifts.

4. **Key Insight**
On light themes, ANSI white can be effectively invisible even when default foreground is fine. Palette changes that fix one TUI can unintentionally alter other tools that depend on palette indices.

5. **The Lesson**
When tuning terminal palette for readability, audit downstream consumers (tmux, TUIs) and pin critical UI surfaces (like tmux statusline) to explicit colors.

6. **Verification / Testing**
Tested:
- Reproduced the full `gws auth login` scope picker (`Select OAuth scopes`, `108/170 selected`) in TTY.
- Calculated objective contrast improvement on Solarized Light background:
  - `normal white`: `1.14 -> 4.13`
  - `bright white`: `1.00 -> 2.93`
  - `dim white`: `4.13`
- Reloaded tmux config and verified active styles:
  - `status-style "fg=#b58900,bg=#eee8d5"`
  - `window-status-style "fg=#b58900,bg=#eee8d5"`
  - `window-status-current-style "fg=#dc322f,bg=#eee8d5"`

Not tested:
- Manual visual comparison on every terminal profile/font combination beyond the current desktop setup.

## 2026-03-07 — Restore `tat` and narrow tmux session helper exposure

1. **The Problem**
The current-directory tmux helper `tat` disappeared during the short Zellij migration/rollback window, and the follow-up cleanup risked leaving `mux` and related helper functions visible even when their backing binary was unavailable.

2. **Root Cause**
`tat` was removed while simplifying multiplexer helpers for Zellij, and the later rollback restored the tmuxinator workflow without restoring the current-directory helper. After that, shell glue still needed a clear boundary between tmux-backed helpers and tmuxinator-backed helpers.

3. **The Fix**
- Restored `tat` in `.zshrc` as the current-directory tmux attach/create helper.
- Kept `tat` defined only when `tmux` is installed.
- Kept `mux` and `setup_tmuxinator_completion()` defined only when `tmuxinator` is installed, to avoid unnecessary global shell namespace entries.
- Left `tmuxinator` installation ownership in `install` via `mise` (`gem:tmuxinator`).
- Updated `README.md` so the documented session helpers match the shell behavior again.
- Added a short comment above the guarded completion hook call to explain why the function existence check is intentional.

4. **Key Insight**
There are two separate concerns here: tmux session behavior (`tat`) and tmuxinator project orchestration (`mux`). They should not share the same shell exposure rules just because tmuxinator ultimately runs on top of tmux.

5. **The Lesson**
Keep shell helpers narrowly scoped both in behavior and in visibility. If a helper depends on a binary, only define it when that binary exists; if installation is already owned by bootstrap tooling, avoid duplicating that ownership elsewhere in the shell config.

6. **Verification / Testing**
Tested:
- Investigated git history and confirmed `tat` disappeared in the Zellij-era helper rewrite on 2026-03-04.
- Ran `zsh -n .zshrc` after each `.zshrc` edit to confirm the shell config remained syntactically valid.
- Verified the final helper layout in `.zshrc`: `tat` is gated by `tmux`, while `mux` and `setup_tmuxinator_completion()` are gated by `tmuxinator`.
- Verified `README.md` reflects both `tat` and `mux`.

Not tested:
- Live interactive `tat` attach/switch behavior inside and outside an existing tmux session.
- Interactive `mux` completion behavior in a freshly started shell.

## 2026-03-08 — Stabilize Codex installation under mise

1. **The Problem**
`codex` stopped working through the mise shim because `github:openai/codex@latest` could not be resolved during auto-install.

2. **Root Cause**
The Codex repository publishes GitHub releases under `rust-v*` tags, but the current mise GitHub backend attempted to resolve `latest` as a literal release tag (`latest`, then `rust-vlatest` after testing `version_prefix`). That made `latest` unusable for this repository through the current `github:` backend setup.

3. **The Fix**
- Unblocked the current machine by pinning the already-installed Codex build in `~/.config/mise/config.toml` to `rust-v0.112.0`.
- Changed `install` to use `npm:@openai/codex@latest`, which is the upstream-recommended Codex installation path.

4. **Key Insight**
For repositories with nonstandard release tags, `mise github:*@latest` can fail even when asset selection is correct.

5. **The Lesson**
Prefer the upstream-supported distribution channel when it exists; use the `github` backend only when the repository's release/tag semantics match what mise can resolve reliably.

6. **Verification / Testing**
Tested:
- `codex --version` via the mise shim returns `codex-cli 0.112.0`.
- `mise ls` now resolves `github:openai/codex` to `rust-v0.112.0` instead of `latest (missing)`.
- `make doctor` passes.

Not tested:
- A fresh `mise` install of `npm:@openai/codex@latest`, because the bash execution environment here cannot perform network package downloads.

## 2026-04-01 — Remove `.zshrc.zwc` from the shell startup flow

1. **The Problem**
`~/.zshrc.zwc` added extra startup state and previously caused refresh issues during interactive shell startup.

2. **Root Cause**
`zcompile` created a separate bytecode artifact for `.zshrc`, but in this setup it did not provide a noticeable benefit relative to the maintenance and debugging cost of keeping the cache healthy.

3. **The Fix**
- Removed `zcompile` from `.zshrc`.
- Stopped using `~/.zshrc.zwc` in the normal shell startup flow.

4. **Key Insight**
For the current shell startup path, the meaningful performance wins come from lazy-loading and reducing work in init, not from bytecode caching `.zshrc`.

5. **The Lesson**
If a performance mechanism does not deliver a measurable win and introduces extra state and drift, prefer removing it over repeatedly repairing the cache lifecycle around it.

6. **Verification / Testing**
Tested:
- `zsh -i -c exit`
- interactive startup timing remained about `0.16s`
- `make doctor`
- `make verify`

Not tested:
- long-term startup comparison across multiple hosts and profiles

## 2026-04-10 — Clarify blink.cmp buffer source as fallback to LSP

1. **The Problem**
Ruby completion in Neovim was unclear about whether buffer words (strings, keyword argument names) should appear alongside LSP suggestions or only when LSP returns no results.

2. **Root Cause**
The blink.cmp config listed `buffer` in `sources.default` but did not explicitly declare it as a fallback to `lsp`. Without explicit `fallbacks`, the recommended behavior (buffer words only when LSP has nothing) was implicit and undocumented in the local config.

3. **The Fix**
- Added explicit `sources.providers.lsp.fallbacks = { 'buffer' }` in `blink.lua`, matching the blink.cmp recommended setup and LazyVim defaults.
- Updated `.config/nvim/README.md` to document that `buffer` is a fallback source, not a parallel one.

4. **Key Insight**
blink.cmp's default provider config has `lsp.fallbacks = { 'buffer' }`, meaning buffer words only surface when LSP returns zero items. This is the same model LazyVim and Omarchy use. Explicitly declaring it avoids ambiguity and follows best practices for semantic-first completion.

5. **The Lesson**
In completion engines, prefer semantic sources (`lsp`) over textual ones (`buffer`). When following established distro conventions (LazyVim, Omarchy), make the choice explicit in local config rather than relying on implicit defaults.

6. **Verification / Testing**
Tested:
- Verified blink.lua config syntax and README documentation correctness.
- Compared with LazyVim blink.cmp extra default sources and blink.cmp reference docs.

Not tested:
- Full interactive Neovim runtime (local nvim is v0.10.4; telescope.nvim requires 0.11+).
- Interactive Ruby file completion behavior with ruby_lsp active.

## 2026-04-16 — Use a zsh-aware formatter instead of shfmt for .zshrc

1. **The Problem**
`shfmt` failed on `.zshrc` with `parameter expansion requires a literal` while formatting the zinit completion bootstrap line.

2. **Root Cause**
`conform.nvim` mapped `zsh` to `shfmt`, but the file contains zsh-specific syntax that `shfmt` does not parse reliably.

3. **The Fix**
- Changed `conform.nvim` so `zsh` uses `beautysh` instead of `shfmt`.
- Added `beautysh` to `mason-tool-installer.nvim` so it is installed with the rest of the Neovim tooling.
- Updated the Neovim README to document the formatter split between `sh`/`bash` and `zsh`.

4. **Key Insight**
Shell formatting needs to match the shell dialect. A formatter that is fine for POSIX shell can still reject valid zsh syntax.

5. **The Lesson**
Do not route zsh files through generic shell formatters unless you have verified dialect support. Prefer a formatter that matches the filetype explicitly.

6. **Verification / Testing**
Tested:
- `zsh -n .zshrc`
- `luac -p .config/nvim/lua/plugins/conform.lua`
- `luac -p .config/nvim/lua/plugins/mason-tool-installer.lua`

Not tested:
- Full Neovim startup in this environment, because the local `nvim` build is older than the installed `telescope.nvim` requirement.

## 2026-04-24 — Fail-fast w `.zshrc`: `gwtclone`, `update-all`, `code_pod`

1. **The Problem**
`gwtclone` źle wykrywał default branch przez błędną składnię `git ls-remote --symref -- HEAD "$repo_url"` (traktował `HEAD` jako URL repozytorium). W wielu miejscach `.zshrc` stosowano fallbacki zamiast fail-fast, co maskowało błędy (pusty default branch → fallback do `main`, brak kubeconfig → fallback do `"default"`).

2. **Root Cause**
- `git ls-remote` ma składnię `<repo> [<refs>...]`; `--` powodował traktowanie `HEAD` jako repozytorium.
- `2>/dev/null || true` w `update-all` i `code_pod` ukrywało błędy krytyczne (RBAC, brak sieci, brak kubeconfig).
- Fallbacki były wygodne w pisaniu, ale powodowały niepoprawne zachowanie w runtime.

3. **The Fix**
- `gwtclone`: usunięto `--`, zamieniono kolejność na `git ls-remote --symref "$repo_url" HEAD`. Zastąpiono fallback do `main` fail-fast z czytelnym błędem.
- `update-all`: zastąpiono fallback do `$USER`/`$HOME` fail-fast przy braku rozwiązania target usera.
- `code_pod`: usunięto `2>/dev/null || true` z 3 miejsc kubectl — błędy są teraz widoczne i natychmiastowe.

4. **Key Insight**
`2>/dev/null || true` jest antywzorcem w skryptach, które mają robić coś konkretnego z wynikiem komendy. Jeśli wynik jest pusty z powodu błędu, kod downstream często interpretuje to jako "brak danych" i podejmuje niewłaściwe decyzje (np. zakłada `terminated` zamiast zawieść).

5. **The Lesson**
W shell scripting: fail-fast > silent fallback. Jeśli komenda jest krytyczna dla decyzji logiki, nie tłum jej błędów. Fallbacki tylko tam, gdzie "brak danych" jest prawidłowym stanem (np. optional completion).

6. **Verification / Testing**
Tested:
- `git ls-remote --symref "git@github.com:zewelor/dot2dot.git" HEAD` → zwraca `dev`
- Nieistniejące repo → błąd i `exit 1`
- `zsh -n .zshrc` po wszystkich zmianach przechodzi

Not tested:
- Pełny `update-all` jako root na systemie bez UID 1000
- `code_pod` z faktycznym kubectl i błędami RBAC

## 2026-05-03 — Fix nvim_pod path normalization and extend editing image

1. **The Problem**
`nvim_pod homeassistant-nugat/config/configuration.yaml` opened a blank file instead of the real Home Assistant config.

2. **Root Cause**
The helper passed `config/configuration.yaml` to Neovim as a relative path. Inside the ephemeral debug container, the mounted config lives at `/config/configuration.yaml`, so Neovim created/opened a different relative path from the working directory.

3. **The Fix**
- Normalize user-provided pod paths to absolute paths before launching Neovim: `config/...` now becomes `/config/...`.
- Extended the Neovim image with practical editing tools: `mini.pairs`, `gitsigns`, `telescope`, `git`, `ripgrep`, `fd-find`.
- Pinned `telescope.nvim` to `0.1.8` because the image uses Neovim `0.10.4` and Telescope `master` requires `0.11+`.
- Included runtime `git` and `fd` binaries in the final stage, not only in the build stage.

4. **Key Insight**
The mount was correct; only the path passed to Neovim was wrong. The image issues were separate runtime packaging problems, not the cause of the blank file.

5. **The Lesson**
When editing files inside containers, always align helper input semantics with real mount paths. For minimal runtime images, verify that plugin runtime dependencies are actually present in the final stage, not only in the build stage.

6. **Verification / Testing**
Tested:
- Confirmed `/config/configuration.yaml` exists in the app container (`10463` bytes).
- Verified `nvim_pod` opens `/config/configuration.yaml` and shows real content.
- Rebuilt the Neovim image locally and verified all new plugins are installed.
- Verified `git`, `rg`, and `fdfind` exist and are executable in the runtime image.
- Verified `require("telescope.builtin")` and `require("gitsigns")` succeed at runtime.

Not tested:
- GitHub Actions publish for the updated image.
- Pulling the refreshed GHCR image from a cluster node after publish.

## 2026-05-22 — Bypass delta pager in non-interactive shells

1. **The Problem**
When running git diff or git show in non-interactive environments (such as when LLMs, agents, or tools execute commands via a runner), the output used `delta` as the git pager. `delta` produced complex grid structures, unicode borders, line numbering, and side-by-side output that consumed an excessive number of tokens and made automated diff parsing extremely difficult.

2. **Root Cause**
The default git configuration set `core.pager = delta` globally. Under LLM/agent run-command environments, a pseudo-terminal (PTY) is typically allocated to handle commands. Because a PTY is present, Git detected it as a TTY and fell back to utilizing the configured pager (`delta`), unaware that the wrapper shell execution itself is completely non-interactive.

3. **The Fix**
- Modified `.zshenv` to check for non-interactive shell sessions (`[[ ! -o interactive ]]`).
- Conditionally set `export GIT_PAGER=cat` in those sessions.
- This forces Git to bypass the global `delta` pager config in any non-interactive script or agent execution shell, reverting to clean, raw, standard git diff output.

4. **Key Insight**
PTY allocation by command runners tricks git/pagers into believing a real human user is present. To prevent pagers from corrupting programmatic terminal inputs/outputs with rich terminal formatting, the shell itself should inspect its interactive status and configure the environment accordingly.

5. **The Lesson**
When building developer dotfiles, consider the operational environments of modern tooling (like CI/CD pipelines, programmatic CLI wrappers, and LLMs). Environment variables like `GIT_PAGER` provide a clean mechanism to dynamically downgrade interactive decorations to standard raw outputs without altering core tool configs.

6. **Verification / Testing**
Tested:
- Standard interactive shells still correctly use `delta` pager with all side-by-side formatting.
- Non-interactive zsh sessions (`zsh -c`) successfully export `GIT_PAGER=cat` and bypass `delta` entirely.
- Verified plain raw git diff outputs in LLM runner environments.
- Ran `./install` successfully to stow the updated `.zshenv` symlink.

Not tested:
- Behavioral changes on systems using shells other than Zsh (like standard Bash environments), as Zsh is the primary and only interactive shell setup defined in these dotfiles.

## 2026-06-04 — Resolve Neovim 0.11+ Tree-sitter parser load crash due to lazy.nvim runtimepath reset

1. **The Problem**
Starting Neovim or reading any file with the `lua` filetype (including config files during startup) triggered a crash with the error:
`Parser could not be created for buffer 1 and language "lua"`.

2. **Root Cause**
Neovim 0.11+ triggers `vim.treesitter.start()` by default inside its built-in runtime `ftplugin/lua.lua` file. To do so, it expects to find the built-in Tree-sitter parsers (`lua.so`, `vim.so`, etc.) under the paths in the runtimepath (`rtp`).
On Debian/Ubuntu, Neovim packages install these core parsers to `/usr/lib/nvim/parser/`. By default, `/usr/lib/nvim` is present in Neovim's default runtimepath.
However, `lazy.nvim` manages and resets the runtimepath (`rtp`) on startup. It strips custom/system-specific paths like `/usr/lib/nvim` from `rtp`, causing Neovim to lose access to the system-installed Tree-sitter parsers. As a result, when Neovim attempts to start treesitter highlighting for a buffer (e.g. `init.lua`), it fails to create the parser and throws a fatal Lua error.

3. **The Fix**
Modified `.config/nvim/lua/config/lazy.lua` to add `/usr/lib/nvim` to lazy.nvim's `performance.rtp.paths` setup list. This ensures `lazy.nvim` preserves this system directory in the runtimepath.

4. **Key Insight**
Custom package manager layouts (like Debian/Ubuntu placing native parsers in `/usr/lib/nvim`) require explicit inclusion in Neovim plugin managers (like `lazy.nvim`) that rebuild or filter the runtimepath.

5. **The Lesson**
When configuring plugin managers that override or sanitize `rtp` (e.g. `lazy.nvim`), ensure that system-specific runtime paths required for core features (like built-in Treesitter parsers on Linux distributions) are explicitly preserved.

6. **Verification / Testing**
Tested:
- Started headless Neovim loading `init.lua`: `nvim --headless init.lua -c "q"`, which succeeded without any autocommand or Treesitter parser errors.
- Verified that `vim.treesitter.get_parser()` successfully returns a parser object for a Lua buffer.
- Verified `/usr/lib/nvim/parser/lua.so` exists and matches the loader requirements.

Not tested:
- Performance changes during startup with the added rtp directory.
- Tree-sitter parser loading behavior on other operating systems (macOS, Fedora, Windows) since they use different packaging structures.
