#!/usr/bin/env bash
# ==============================================================================
# Nirakase: .agents/hooks/stop-verify.sh
# Description: Antigravity Stop lifecycle hook that automatically runs
#              scripts/verify.sh --changed before an agent finishes its turn.
# License: MIT License | Copyright (c) 2026-present rbailon
# ==============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PAYLOAD="$(cat)"

emit_allow() {
  printf '{"decision":"allow"}\n'
}

# Parse Stop hook input safely: only gate normal turn completion and prevent loops
SHOULD_VERIFY="$(python3 - "$PAYLOAD" <<'PY'
import json
import sys

try:
    data = json.loads(sys.argv[1]) if sys.argv[1].strip() else {}
except Exception:
    data = {}

reason = data.get("terminationReason", "")
continuation_active = bool(data.get("continuationActive", False))

if reason == "NO_TOOL_CALL" and not continuation_active:
    print("yes")
else:
    print("no")
PY
)"

if [[ "$SHOULD_VERIFY" != "yes" ]]; then
  emit_allow
  exit 0
fi

# Skip quickly if the repository working tree has no uncommitted changes
if [[ -z "$(git -C "$REPO_DIR" status --porcelain=v1 -uall 2>/dev/null || true)" ]]; then
  emit_allow
  exit 0
fi

VERIFY_SCRIPT="$REPO_DIR/scripts/verify.sh"
if [[ ! -x "$VERIFY_SCRIPT" ]]; then
  emit_allow
  exit 0
fi

if OUTPUT="$("$VERIFY_SCRIPT" --changed --quiet 2>&1)"; then
  emit_allow
  exit 0
fi

# Verification failed: instruct the agent to fix issues before stopping
python3 - "$OUTPUT" <<'PY'
import json
import sys

output = sys.argv[1].strip()
max_len = 2000
if len(output) > max_len:
    output = output[:max_len] + "\n... (output truncated)"

reason = (
    "Automatic verification (./scripts/verify.sh --changed) failed. "
    "Fix the reported issues and re-run ./scripts/verify.sh --changed before concluding:\n\n"
    + output
)

print(json.dumps({"decision": "continue", "reason": reason}))
PY
