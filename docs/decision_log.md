# Decision Log

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
