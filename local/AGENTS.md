# Local Scripts & Applications Agent Rules

Scoped rules for `local/` (`local/bin/`, `local/applications/`, `local/icons/`). Inherited root rules in `AGENTS.md` also apply.

> Note: This file lives in `local/` (not `local/bin/`) so `local/bin/` stays strictly executable on `PATH` and unaffected by `chmod +x local/bin/*` in `install.sh`.

## 1. Bash Scripts (`local/bin/*`)
- Use `#!/usr/bin/env bash` and enable strict mode (`set -euo pipefail`) on all new or refactored scripts.
- Double-quote all variable expansions (`"$var"`, `"${arr[@]}"`) and use `local` inside functions.
- Prefer Bash built-ins (`[[ ]]`, `${var//a/b}`, `${var##*/}`) over unnecessary subshells or `grep`/`sed`/`awk` pipelines.
- Never use `eval` or pass unquoted external input to `sh -c`.
- Create temporary files/directories with `mktemp` under restrictive permissions (`umask 077`) and remove them via `trap ... EXIT`.
- Keep all script comments, usage text, FZF prompts, and error messages in English.

## 2. Python Scripts (`local/bin/nirakase-nm-agent`, etc.)
- Follow PEP 8 with English identifiers, docstrings, and log messages.
- Use `subprocess.run([...], shell=False)` with explicit argument lists; never invoke shells with interpolated user/network strings.
- **Secrets**: Never print, log to stderr/stdout, or pass Wi-Fi/VPN/keyring secrets via CLI arguments. Use D-Bus, `libsecret`, or pipes (`stdin`) with zero persistence to temporary files.
- Handle `SIGINT` and `SIGTERM` cleanly so background agents shut down without leaking resources or dialogs.

## 3. Desktop Entries (`local/applications/*.desktop`)
- Use standard FreeDesktop keys; custom categories MUST be prefixed with `X-` (e.g., `X-NirakaseWebApp`).
- Avoid hardcoded usernames in `Exec=` or `Icon=` paths when avoidable, and keep icons aligned with `local/icons/`.

## 4. Verification
- Run `./scripts/verify.sh --changed` after every edit (`bash -n`, `shellcheck` if installed, Python bytecode compilation, `ruff` if installed, `desktop-file-validate`, and IPC contract checks).
- Exercise `--help` or `--dry-run` paths when available to verify CLI argument parsing without side effects.
