# Nirakase Agent Rules

These rules apply to the entire Nirakase repository. Scoped rules in subdirectories (`config/quickshell/AGENTS.md`, `config/niri/AGENTS.md`, `local/AGENTS.md`) add domain-specific constraints.

## 1. Language & Naming (English Only)
- Write all code identifiers (functions, variables, properties, QML IDs/signals, constants, file names), inline comments, docstrings, CLI help/usage text, UI strings, and log/error messages strictly in **English**, regardless of the conversation language.
- Use ASCII-only characters in identifiers, file names, and paths.
- Follow idiomatic naming per language:
  - **QML / JS**: `PascalCase` for components and singletons; `camelCase` for properties, functions, and signals; `_prefix` for private/internal state.
  - **Python**: PEP 8 (`snake_case` functions/variables, `PascalCase` classes, `UPPER_SNAKE_CASE` constants).
  - **Bash**: `snake_case` for functions and `local` variables; `UPPER_SNAKE_CASE` for constants and exported variables.
  - **Lua**: `snake_case` for locals, functions, and module keys.

## 2. Efficiency & Performance
- Prefer event-driven designs (Niri `event-stream`, D-Bus signals, QML `Connections`, `select`/`GLib.MainLoop`) over polling timers or `sleep` loops.
- Avoid spawning unnecessary subprocesses or chained external commands (`grep`/`sed`/`awk`) when language built-ins suffice.
- Clean up timers, child processes, temporary files, and file descriptors when no longer needed to prevent memory leaks or orphan processes.
- Keep startup and runtime overhead minimal; Nirakase targets a fast, lightweight Wayland session.

## 3. Privacy & Security
- **Never expose secrets**: Do not log, print, persist to disk/tmp, or pass passwords, API tokens, SSH keys, Polkit responses, or Wi-Fi/VPN credentials via CLI arguments (visible in `/proc/<pid>/cmdline`). Use `stdin`, D-Bus/libsecret, or volatile memory only.
- **No command injection**: Never use `eval` or unquoted string interpolation with untrusted/external data (window titles, SSIDs, notifications, clipboard content, `.desktop` fields). Always pass argument arrays (`Process { command: [...] }` in QML, `subprocess.run([...], shell=False)` in Python) and quote all Bash variable expansions (`"$var"`).
- **Safe system changes**: Use `set -euo pipefail` in Bash scripts, `mktemp` with restrictive permissions (`umask 077`) for temporary files, create backups before replacing user files or symlinks, minimize `sudo` scope, and never add telemetry or unrequested network calls.
- **No hardcoded personal paths or secrets**: Keep configs portable (`$HOME`, XDG variables) and never commit credentials or private keys.

## 4. Mandatory Verification & Regression Prevention
- Every code or configuration change MUST be tested before finishing the task.
- Always run the repository verification script after making edits:
  - For targeted changes: `./scripts/verify.sh --changed`
  - For broad refactors or releases: `./scripts/verify.sh --all`
- Verify cross-module contracts when touching shared interfaces:
  - `config/niri/config.d/keybinds.kdl` and `local/bin/*` <-> `IpcHandler` in `config/quickshell/shell.qml`
  - New or renamed QML files <-> `config/quickshell/qmldir`
  - Added, moved, or removed files/directories <-> `install.sh` and `structure`
- Review `git diff` to ensure changes stay scoped and introduce no unintended regressions.
- Never claim a check passed if it was not executed; explicitly report any check skipped due to missing tools or headless/sandbox limits.

## 5. Repository Invariants
- Preserve `install.sh` idempotency and self-relocation to `~/.local/share/nirakase`.
- Do not place non-executable documentation files (such as `AGENTS.md`) inside `local/bin/`, as `local/bin/` is added to `PATH` and `install.sh` marks its contents executable.
- Keep `VERSION` and `CHANGELOG.md` consistent with `release.sh` (do not manually bump versions unless requested).
