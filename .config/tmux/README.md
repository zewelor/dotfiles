# Tmux Config Notes

Catppuccin theme setup and available status modules for quick reference.

## Current Setup (from `~/.tmux.conf`)

```tmux
set -g @catppuccin_flavor "latte"
set -g @catppuccin_window_status_style "rounded"
run ~/.config/tmux/plugins/catppuccin/tmux/catppuccin.tmux

set -g status-right ''
```

- **Flavor**: `latte` (light)
- **Window style**: `rounded` (segments with rounded corners)
- **Status-right**: empty (minimalist)
- **UI colors**: pane borders, messages, clock — all handled by catppuccin (no manual overrides)
- **status-interval**: `1` (fast automatic-rename response)

### Future: Window name with directory path

If you want to show the current directory instead of `#W` (command name) for zsh windows, these are the available tmux format modifiers:

| What | Format | Example | Note |
|---|---|---|---|
| Full path | `#{pane_current_path}` | `/home/omen/dotfiles` | Long, shows everything |
| Basename only | `#{b:pane_current_path}` | `dotfiles` | Shortest, no context |
| Dirname only | `#{d:pane_current_path}` | `/home/omen` | Parent dir only |
| Shortened path | `#{d:pane_current_path}` | `/h/o/p/dot2dot` | tmux built-in abbreviation |
| Home substitution | `#{s\|^/home/omen\|~\|:pane_current_path}` | `~/dotfiles` | Hardcoded home path |

Example conditional format (shows dir basename for zsh, command name otherwise):
```tmux
set -g @catppuccin_window_text ' #{?#{==:#W,zsh},#{b:pane_current_path},#W}'
set -g @catppuccin_window_current_text ' #{?#{==:#W,zsh},#{b:pane_current_path},#W}'
```

> ⚠️ Must be set **before** `run catppuccin.tmux` (catppuccin docs requirement).

## Available Status Modules

Each module can be added to `status-right` or `status-left`:

```tmux
set -g status-right "#{E:@catppuccin_status_date_time}"
set -ag status-right "#{E:@catppuccin_status_session}"
```

| Module | Icon | Shows | Variable |
|--------|------|-------|----------|
| `application` | `` | Current command | `@catppuccin_status_application` |
| `battery` | `🔋` | Battery percentage | `@catppuccin_status_battery` |
| `clima` | `` | Weather | `@catppuccin_status_clima` |
| `cpu` | `` | CPU usage | `@catppuccin_status_cpu` |
| `date_time` | `󰃰` | Date/time (`%Y-%m-%d %H:%M`) | `@catppuccin_status_date_time` |
| `directory` | `` | Current directory | `@catppuccin_status_directory` |
| `gitmux` | `󰊢` | Git status (via gitmux) | `@catppuccin_status_gitmux` |
| `host` | `󰒋` | Hostname | `@catppuccin_status_host` |
| `kube` | `󱃾` | Kubernetes context/namespace | `@catppuccin_status_kube` |
| `load` | `󰊚` | System load | `@catppuccin_status_load` |
| `pomodoro_plus` | `` | Pomodoro timer | `@catppuccin_status_pomodoro_plus` |
| `ram` | `` | RAM usage | `@catppuccin_status_ram` |
| `session` | `` | Session name | `@catppuccin_status_session` |
| `uptime` | `󰔟` | Uptime | `@catppuccin_status_uptime` |
| `user` | `` | Username | `@catppuccin_status_user` |
| `weather` | `` | Weather | `@catppuccin_status_weather` |

## Useful Format Strings

| What | Format | Example |
|------|--------|---------|
| Shortened path | `#{d:pane_current_path}` | `/h/o/p/dot2dot` |
| Basename only | `#{b:pane_current_path}` | `dot2dot` |
| Current command | `#{pane_current_command}` | `zsh`, `nvim` |
| Window name | `#{window_name}` / `#T` | `zsh`, `wm-feature` |

## Window Name Behavior

- Normal panes: shows `#{pane_current_command}` (from `automatic-rename`)
- Workmux windows: shows branch name (workmux calls `tmux rename-window`)
- Manual rename: `prefix + ,` to override

## Plugins (git submodules)

```
.config/tmux/plugins/
├── catppuccin/tmux     # Theme
└── tmux-sensible/      # Sensible defaults
```

Managed via `dotfiles_update` alias (runs `git submodule update --recursive --remote`).

## Docs

Upstream catppuccin tmux docs:
- [Configuration reference](https://github.com/catppuccin/tmux/blob/main/docs/reference/configuration.md)
- [Status line modules](https://github.com/catppuccin/tmux/blob/main/docs/reference/status-line.md)
- [Getting started](https://github.com/catppuccin/tmux/blob/main/docs/tutorials/01-getting-started.md)
