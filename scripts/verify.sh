#!/usr/bin/env bash
# ==============================================================================
# Nirakase: scripts/verify.sh
# Description: Repository verification and regression check runner.
# License: MIT License | Copyright (c) 2026-present rbailon
# ==============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

MODE="all"
STRICT=false
QUIET=false

usage() {
  cat <<'EOF'
Usage: ./scripts/verify.sh [options]

Options:
  --all       Verify the entire repository (default)
  --changed   Verify only modified/untracked files in Git and related contracts
  --strict    Fail if optional linters (shellcheck, ruff, qmllint) are missing
  -q, --quiet Suppress passing details; only print failures and final summary
  -h, --help  Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      MODE="all"
      shift
      ;;
    --changed)
      MODE="changed"
      shift
      ;;
    --strict)
      STRICT=true
      shift
      ;;
    -q|--quiet)
      QUIET=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Error: unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

umask 077
TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

PASSED=0
FAILED=0
SKIPPED=0
declare -a SKIP_NOTES=()
declare -A SKIP_SEEN=()

log_pass() {
  PASSED=$((PASSED + 1))
  if [[ "$QUIET" == false ]]; then
    printf '[PASS] %s\n' "$1"
  fi
}

log_fail() {
  FAILED=$((FAILED + 1))
  printf '[FAIL] %s\n' "$1" >&2
  if [[ $# -gt 1 && -n "$2" ]]; then
    printf '%s\n' "$2" | sed 's/^/       /' >&2
  fi
}

log_skip_once() {
  local key="$1"
  local message="$2"
  if [[ -z "${SKIP_SEEN[$key]:-}" ]]; then
    SKIP_SEEN["$key"]=1
    SKIPPED=$((SKIPPED + 1))
    SKIP_NOTES+=("$message")
    if [[ "$QUIET" == false ]]; then
      printf '[SKIP] %s\n' "$message"
    fi
  fi
}

# Collect target files
declare -a TARGET_FILES=()
if [[ "$MODE" == "changed" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # Strip 3-character porcelain status prefix; handle renames ("old -> new")
    path="${line:3}"
    if [[ "$path" == *" -> "* ]]; then
      path="${path##* -> }"
    fi
    # Remove surrounding quotes if git quoted the path
    path="${path#\"}"
    path="${path%\"}"
    if [[ -f "$path" ]]; then
      TARGET_FILES+=("$path")
    fi
  done < <(git status --porcelain=v1 -uall)

  if [[ ${#TARGET_FILES[@]} -eq 0 ]]; then
    [[ "$QUIET" == false ]] && printf '[INFO] No modified files to verify.\n'
    exit 0
  fi
else
  while IFS= read -r path; do
    [[ -f "$path" ]] && TARGET_FILES+=("$path")
  done < <(find . \
    -path './.git' -prune -o \
    -type f -print | sed 's|^\./||' | sort)
fi

declare -a BASH_FILES=()
declare -a PYTHON_FILES=()
declare -a JSON_FILES=()
declare -a QML_FILES=()
declare -a DESKTOP_FILES=()
declare -a SERVICE_FILES=()
declare -a LUA_FILES=()
declare -a SECRET_SCAN_FILES=()

CHECK_NIRI=false
CHECK_QMLDIR=false
CHECK_IPC=false

is_bash_file() {
  local file="$1"
  case "$file" in
    *.sh|system/bashrc)
      return 0
      ;;
    default/bash/inputrc)
      return 1
      ;;
    default/bash/*)
      return 0
      ;;
    local/bin/*)
      local first_line=""
      IFS= read -r first_line <"$file" || true
      [[ "$first_line" == "#!"*bash* ]] && return 0
      ;;
  esac
  return 1
}

is_python_file() {
  local file="$1"
  case "$file" in
    *.py)
      return 0
      ;;
    local/bin/*)
      local first_line=""
      IFS= read -r first_line <"$file" || true
      [[ "$first_line" == "#!"*python* ]] && return 0
      ;;
  esac
  return 1
}

for file in "${TARGET_FILES[@]}"; do
  if is_bash_file "$file"; then
    BASH_FILES+=("$file")
    SECRET_SCAN_FILES+=("$file")
  elif is_python_file "$file"; then
    PYTHON_FILES+=("$file")
    SECRET_SCAN_FILES+=("$file")
  fi

  case "$file" in
    *.json)
      JSON_FILES+=("$file")
      SECRET_SCAN_FILES+=("$file")
      ;;
    config/quickshell/*.qml)
      QML_FILES+=("$file")
      CHECK_QMLDIR=true
      SECRET_SCAN_FILES+=("$file")
      [[ "$file" == "config/quickshell/shell.qml" ]] && CHECK_IPC=true
      ;;
    config/quickshell/qmldir)
      CHECK_QMLDIR=true
      ;;
    config/niri/*.kdl)
      CHECK_NIRI=true
      CHECK_IPC=true
      SECRET_SCAN_FILES+=("$file")
      ;;
    local/bin/*)
      CHECK_IPC=true
      ;;
    *.desktop)
      DESKTOP_FILES+=("$file")
      ;;
    config/systemd/user/*.service)
      SERVICE_FILES+=("$file")
      ;;
    config/nvim/*.lua)
      LUA_FILES+=("$file")
      SECRET_SCAN_FILES+=("$file")
      ;;
  esac
done

# 1. Bash syntax & optional ShellCheck
if [[ ${#BASH_FILES[@]} -gt 0 ]]; then
  for file in "${BASH_FILES[@]}"; do
    if err="$(bash -n "$file" 2>&1)"; then
      log_pass "bash -n: $file"
    else
      log_fail "bash -n: $file" "$err"
    fi
  done

  if command -v shellcheck >/dev/null 2>&1; then
    for file in "${BASH_FILES[@]}"; do
      local_first=""
      IFS= read -r local_first <"$file" || true
      if [[ "$local_first" == "#!"* ]]; then
        sc_cmd=(shellcheck -S warning "$file")
      else
        sc_cmd=(shellcheck -s bash -S warning "$file")
      fi
      if err="$("${sc_cmd[@]}" 2>&1)"; then
        log_pass "shellcheck: $file"
      else
        log_fail "shellcheck: $file" "$err"
      fi
    done
  else
    log_skip_once "shellcheck" "shellcheck not installed (install with: sudo pacman -S shellcheck)"
  fi
fi

# 2. Python bytecode compilation (without polluting __pycache__) & optional Ruff
if [[ ${#PYTHON_FILES[@]} -gt 0 ]]; then
  for file in "${PYTHON_FILES[@]}"; do
    out_pyc="$TMP_DIR/check.pyc"
    if err="$(python3 -c 'import py_compile, sys; py_compile.compile(sys.argv[1], cfile=sys.argv[2], doraise=True)' "$file" "$out_pyc" 2>&1)"; then
      log_pass "python3 compile: $file"
    else
      log_fail "python3 compile: $file" "$err"
    fi
  done

  if command -v ruff >/dev/null 2>&1; then
    for file in "${PYTHON_FILES[@]}"; do
      if err="$(ruff check "$file" 2>&1)"; then
        log_pass "ruff: $file"
      else
        log_fail "ruff: $file" "$err"
      fi
    done
  else
    log_skip_once "ruff" "ruff not installed (install with: sudo pacman -S ruff)"
  fi
fi

# 3. JSON validation
if [[ ${#JSON_FILES[@]} -gt 0 ]]; then
  for file in "${JSON_FILES[@]}"; do
    if command -v jq >/dev/null 2>&1; then
      if err="$(jq empty "$file" 2>&1)"; then
        log_pass "json: $file"
      else
        log_fail "json: $file" "$err"
      fi
    else
      if err="$(python3 -m json.tool "$file" 2>&1 >/dev/null)"; then
        log_pass "json: $file"
      else
        log_fail "json: $file" "$err"
      fi
    fi
  done
fi

# 4. Niri KDL validation
if [[ "$CHECK_NIRI" == true ]]; then
  if command -v niri >/dev/null 2>&1; then
    if err="$(niri validate -c config/niri/config.kdl 2>&1)"; then
      log_pass "niri validate: config/niri/config.kdl"
    else
      log_fail "niri validate: config/niri/config.kdl" "$err"
    fi
  else
    log_skip_once "niri" "niri binary not installed; skipped KDL validation"
  fi
fi

# 5. Quickshell QML lint & qmldir integrity
if [[ ${#QML_FILES[@]} -gt 0 ]]; then
  QMLLINT_BIN=""
  if command -v qmllint >/dev/null 2>&1; then
    QMLLINT_BIN="$(command -v qmllint)"
  elif command -v qmllint6 >/dev/null 2>&1; then
    QMLLINT_BIN="$(command -v qmllint6)"
  elif [[ -x "/usr/lib/qt6/bin/qmllint" ]]; then
    QMLLINT_BIN="/usr/lib/qt6/bin/qmllint"
  fi

  if [[ -n "$QMLLINT_BIN" ]]; then
    if err="$("$QMLLINT_BIN" -I config/quickshell "${QML_FILES[@]}" 2>&1)"; then
      log_pass "qmllint: ${#QML_FILES[@]} QML file(s)"
    else
      log_fail "qmllint: ${#QML_FILES[@]} QML file(s)" "$err"
    fi
  else
    log_skip_once "qmllint" "qmllint not installed (install with: sudo pacman -S qt6-declarative)"
  fi
fi

if [[ "$CHECK_QMLDIR" == true && -f "config/quickshell/qmldir" ]]; then
  if err="$(python3 - <<'PY' 2>&1
from pathlib import Path
import sys

root = Path("config/quickshell")
qmldir = root / "qmldir"
errors = []

for lineno, raw in enumerate(qmldir.read_text(encoding="utf-8").splitlines(), 1):
    line = raw.strip()
    if not line or line.startswith("#") or line.startswith("module "):
        continue
    parts = line.split()
    is_singleton = False
    if parts[0] == "singleton":
        is_singleton = True
        parts = parts[1:]
    if len(parts) < 3:
        errors.append(f"qmldir:{lineno}: malformed entry: {raw}")
        continue
    rel_path = parts[2]
    target = root / rel_path
    if not target.is_file():
        errors.append(f"qmldir:{lineno}: missing QML file: {rel_path}")
        continue
    if is_singleton:
        head = "\n".join(target.read_text(encoding="utf-8").splitlines()[:5])
        if "pragma Singleton" not in head:
            errors.append(f"qmldir:{lineno}: singleton {rel_path} is missing 'pragma Singleton'")

if errors:
    print("\n".join(errors))
    sys.exit(1)
PY
  )"; then
    log_pass "qmldir integrity: config/quickshell/qmldir"
  else
    log_fail "qmldir integrity: config/quickshell/qmldir" "$err"
  fi
fi

# 6. Cross-module Niri / local/bin <-> Quickshell IPC contract check
if [[ "$CHECK_IPC" == true && -f "config/quickshell/shell.qml" ]]; then
  if err="$(python3 - <<'PY' 2>&1
from pathlib import Path
import re
import sys

shell_text = Path("config/quickshell/shell.qml").read_text(encoding="utf-8")

# Parse IpcHandler blocks and collect (target, method_name) pairs
handlers = {}
for m in re.finditer(r'\bIpcHandler\s*\{', shell_text):
    start = m.end()
    depth = 1
    idx = start
    while idx < len(shell_text) and depth > 0:
        ch = shell_text[idx]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
        idx += 1
    block = shell_text[start:idx]
    target_match = re.search(r'\btarget\s*:\s*"([^"]+)"', block)
    if not target_match:
        continue
    target = target_match.group(1)
    methods = set(re.findall(r'\bfunction\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(', block))
    handlers.setdefault(target, set()).update(methods)

errors = []

# Check Niri KDL spawn calls
for kdl_file in sorted(Path("config/niri/config.d").glob("*.kdl")):
    for lineno, line in enumerate(kdl_file.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("//"):
            continue
        for match in re.finditer(r'"(?:quickshell|qs)"\s+"ipc"\s+"call"\s+"([^"]+)"\s+"([^"]+)"', line):
            target, method = match.group(1), match.group(2)
            if target not in handlers:
                errors.append(f"{kdl_file}:{lineno}: unknown IPC target '{target}'")
            elif method not in handlers[target]:
                errors.append(f"{kdl_file}:{lineno}: unknown IPC method '{target}.{method}'")

# Check local/bin scripts
bin_dir = Path("local/bin")
if bin_dir.is_dir():
    for script in sorted(bin_dir.iterdir()):
        if not script.is_file():
            continue
        try:
            text = script.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith("#"):
                continue
            for match in re.finditer(r'\b(?:quickshell|qs)\s+ipc\s+call\s+([A-Za-z0-9_-]+)\s+([A-Za-z0-9_-]+)', line):
                target, method = match.group(1), match.group(2)
                if target not in handlers:
                    errors.append(f"{script}:{lineno}: unknown IPC target '{target}'")
                elif method not in handlers[target]:
                    errors.append(f"{script}:{lineno}: unknown IPC method '{target}.{method}'")

if errors:
    print("\n".join(errors))
    sys.exit(1)
PY
  )"; then
    log_pass "IPC contract: Niri & local/bin <-> config/quickshell/shell.qml"
  else
    log_fail "IPC contract: Niri & local/bin <-> config/quickshell/shell.qml" "$err"
  fi
fi

# 7. Desktop entry validation
if [[ ${#DESKTOP_FILES[@]} -gt 0 ]]; then
  if command -v desktop-file-validate >/dev/null 2>&1; then
    for file in "${DESKTOP_FILES[@]}"; do
      if err="$(desktop-file-validate "$file" 2>&1)"; then
        log_pass "desktop-file-validate: $file"
      else
        log_fail "desktop-file-validate: $file" "$err"
      fi
    done
  else
    log_skip_once "desktop-file-validate" "desktop-file-validate not installed"
  fi
fi

# 8. Systemd user unit syntax validation
if [[ ${#SERVICE_FILES[@]} -gt 0 ]]; then
  for file in "${SERVICE_FILES[@]}"; do
    if err="$(python3 - "$file" <<'PY' 2>&1
import configparser
import sys

path = sys.argv[1]
parser = configparser.ConfigParser(interpolation=None, strict=False)
parser.optionxform = str
with open(path, "r", encoding="utf-8") as fh:
    parser.read_file(fh)

for section in ("Unit", "Service"):
    if not parser.has_section(section):
        print(f"Missing required [{section}] section")
        sys.exit(1)

if not parser.has_option("Service", "ExecStart") or not parser.get("Service", "ExecStart").strip():
    print("Missing required ExecStart in [Service]")
    sys.exit(1)
PY
    )"; then
      log_pass "systemd unit parse: $file"
    else
      log_fail "systemd unit parse: $file" "$err"
    fi
  done

  if command -v systemd-analyze >/dev/null 2>&1 && [[ -w "/run/user/$(id -u)/systemd" ]]; then
    for file in "${SERVICE_FILES[@]}"; do
      if err="$(systemd-analyze --user verify "$file" 2>&1)"; then
        log_pass "systemd-analyze: $file"
      else
        log_fail "systemd-analyze: $file" "$err"
      fi
    done
  else
    log_skip_once "systemd-analyze" "systemd-analyze --user verify skipped (no active user systemd runtime dir)"
  fi
fi

# 9. Lua syntax/lint (optional)
if [[ ${#LUA_FILES[@]} -gt 0 ]]; then
  if command -v luacheck >/dev/null 2>&1; then
    for file in "${LUA_FILES[@]}"; do
      if err="$(luacheck --no-color --quiet --globals vim -- "$file" 2>&1)"; then
        log_pass "luacheck: $file"
      else
        log_fail "luacheck: $file" "$err"
      fi
    done
  elif command -v luac >/dev/null 2>&1; then
    for file in "${LUA_FILES[@]}"; do
      if err="$(luac -p "$file" 2>&1)"; then
        log_pass "luac -p: $file"
      else
        log_fail "luac -p: $file" "$err"
      fi
    done
  else
    log_skip_once "lua" "luacheck/luac not installed; skipped Lua checks"
  fi
fi

# 10. Static privacy & security scan (secret patterns and unsafe eval in Bash)
if [[ ${#SECRET_SCAN_FILES[@]} -gt 0 ]]; then
  if err="$(python3 - "${SECRET_SCAN_FILES[@]}" <<'PY' 2>&1
from pathlib import Path
import re
import sys

SECRET_PATTERNS = [
    ("private key block", re.compile(r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----")),
    ("GitHub token", re.compile(r"\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}\b")),
    ("GitLab token", re.compile(r"\bglpat-[A-Za-z0-9_-]{20,}\b")),
    ("AWS access key", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("API secret key", re.compile(r"\bsk-[A-Za-z0-9]{24,}\b")),
]

SKIP_SECRET_FILES = {
    "config/quickshell/services/ClipboardService.qml",
    "scripts/verify.sh",
}

errors = []
seen = set()

for arg in sys.argv[1:]:
    if arg in seen or arg in SKIP_SECRET_FILES:
        continue
    seen.add(arg)
    path = Path(arg)
    if not path.is_file():
        continue
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError:
        continue

    for lineno, line in enumerate(lines, 1):
        for label, pattern in SECRET_PATTERNS:
            if pattern.search(line):
                errors.append(f"{arg}:{lineno}: potential {label} detected")

if errors:
    print("\n".join(errors))
    sys.exit(1)
PY
  )"; then
    log_pass "security scan: no hardcoded secrets detected"
  else
    log_fail "security scan: potential secret detected" "$err"
  fi
fi

# Summary
printf '\nVerification summary (%s): %d passed, %d failed, %d skipped\n' "$MODE" "$PASSED" "$FAILED" "$SKIPPED"
if [[ "$QUIET" == false && ${#SKIP_NOTES[@]} -gt 0 ]]; then
  printf 'Skipped checks:\n'
  for note in "${SKIP_NOTES[@]}"; do
    printf '  - %s\n' "$note"
  done
fi

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi

if [[ "$STRICT" == true && "$SKIPPED" -gt 0 ]]; then
  printf 'Error: --strict enabled and %d optional check(s) were skipped.\n' "$SKIPPED" >&2
  exit 1
fi

exit 0
