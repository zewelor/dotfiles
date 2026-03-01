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
- Version checks passed for `codex`, `gh`, `gog`, `yt-dlp`.
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
