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
