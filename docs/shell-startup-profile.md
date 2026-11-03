# Shell startup profile — 2026-11-03

Measured locally with Zsh 5.9 on the desktop profile. Bash uses an unmanaged
`~/.bashrc`; Fish is not installed. No tools or plugins were removed or updated.

## Measurements

The interactive measurement starts `zsh -i` under `pty.fork()`, disables terminal
echo, queues a leading-space command that unsets HISTFILE and prints a unique
marker, and stops timing when that marker is received. It therefore includes
the first prompt and preexec hooks, rather than treating `zsh -ic exit` as
interactive readiness. Before/after configurations use temporary ZDOTDIR
wrappers with identical real HOME and private includes. Each comparison discards
two warm-up pairs and alternates execution order over 20 measured pairs.

| Measurement | Before | After |
| --- | ---: | ---: |
| First interactive command, initial comparison (median) | 316.16 ms | 287.85 ms |
| First interactive command, final comparison (median) | 244.77 ms | 244.04 ms |
| Final comparison range | 230.67–305.65 ms | 216.68–415.81 ms |
| Terminal title update, isolated (median per call) | 1.5711 ms | 0.0409 ms |

Title measurements use seven batches of 80 calls with stdout attached to a PTY,
timed inside Zsh with EPOCHREALTIME. This confirms a reduction in title overhead;
the noisy full-startup results do **not** establish a repeatable percentage gain.
Starship rendering, Git state and machine load remain part of interactive latency.

An earlier unmodified-shell sweep (nine repetitions after warm-up) measured Bash
at 34.8 ms for `bash -ic exit`, 156.6 ms for `bash -lic exit`, and 65.7 ms to the
first interactive command. These timings measure different paths. Login Bash
also loads system profile scripts. Its duplicate legacy Conda hooks refer to a
missing installation, so they do not initialize Conda here. Bash was left intact.

## Findings and changes

- The synchronous vi-mode plugin is the largest profiled initialization cost:
  approximately 34 ms inclusive, including 25 ms in widget definitions in one
  uninstrumented `zprof` sample. Its initialization order is retained for keymap
  compatibility with Atuin and Starship.
- Terminal titles previously spawned two subshells per update, plus `hostname`
  when a remote session lacked HOSTNAME. Prompt expansion and host lookup now
  use Zsh parameters. Existing title hooks and tmux behavior are retained.
- The desktop libc check no longer runs `rev | cut | rev`. Old or unsupported
  libc lookups still select the existing fzf history plugin; servers skip the
  lookup.
- Existing completion-cache directories and matching agent symlinks no longer
  trigger redundant `mkdir` processes. Required directory creation now reports
  failure explicitly.

No cache generation, network probes, prompt hooks or deferred loading were added.

## Validation

- Red/Green: the original helper tests exposed missing remote hostname fallback
  without the external command and ignored symlink-parent creation failure.
  The final 11 regression tests cover these paths, title expansion, truncation,
  percent literals, tmux/non-terminal handling, libc compatibility and cache errors.
- Actual PTYs after 3.5 seconds of deferred plugin loading produced identical
  before/after signatures for functions, tools, Ctrl-R, vi insert, TAB, zoxide
  completion, OpenCode completion and precmd hooks. This checks registrations;
  it is not an exhaustive interaction test for every plugin or external service.
- `make test`, `make doctor`, `make verify`, and `git --no-pager diff --check`
  passed. No installer, Stow application or package updates were run.

For interactive latency methodology, see
[zsh-bench](https://github.com/romkatv/zsh-bench#what-it-measures).
