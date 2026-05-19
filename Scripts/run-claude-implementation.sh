#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

HANDOFF_DIR=".agent/handoff"
REQUEST_FILE="$HANDOFF_DIR/IMPLEMENTATION_REQUEST.md"
RESULT_FILE="$HANDOFF_DIR/IMPLEMENTATION_RESULT.md"
OUT_FILE="$HANDOFF_DIR/claude.out"
ERR_FILE="$HANDOFF_DIR/claude.err"

if [[ ! -f "$REQUEST_FILE" ]]; then
  echo "Missing required file: $REQUEST_FILE" >&2
  exit 1
fi

mkdir -p "$HANDOFF_DIR"

if command -v uuidgen >/dev/null 2>&1; then
  SESSION_ID="$(uuidgen)"
else
  SESSION_ID="$(date +%Y%m%d%H%M%S)"
fi

set +e
claude -p \
  --session-id "$SESSION_ID" \
  --no-session-persistence \
  --permission-mode acceptEdits \
  --allowedTools "Read Edit Write Bash(git diff*) Bash(git status*) Bash(git log*) Bash(git branch*) Bash(rg *) Bash(find *) Bash(ls *) Bash(pwd)" \
  --disallowedTools "Bash(git push*) Bash(git add*) Bash(git commit*) Bash(rm -rf*) Bash(git reset --hard*) Bash(git clean*) Bash(sudo*) Bash(xcodebuild*) Bash(fastlane*) Bash(bundle exec fastlane*) Bash(tuist clean*)" \
  --max-budget-usd 5.00 \
  --output-format json \
  --append-system-prompt "Keep stdout concise. Do not stage files, commit, push, open PRs, run full CI, run xcodebuild, run Fastlane, or run tuist clean. Write .agent/handoff/IMPLEMENTATION_RESULT.md with STATUS: DONE, BLOCKED, NO_CHANGES, or FAILED." \
  < "$REQUEST_FILE" \
  > "$OUT_FILE" \
  2> "$ERR_FILE"
CLAUDE_EXIT_CODE=$?
set -e

RESULT_STATUS=""
if [[ -f "$RESULT_FILE" ]]; then
  RESULT_STATUS="$(grep -E '^STATUS:' "$RESULT_FILE" | head -n 1 | sed 's/^STATUS:[[:space:]]*//')"
fi

echo "Claude implementation summary:"
echo "- session id: $SESSION_ID"
echo "- exit code: $CLAUDE_EXIT_CODE"
echo "- result status: ${RESULT_STATUS:-MISSING}"
echo "- output files:"
echo "  - $OUT_FILE"
echo "  - $ERR_FILE"
echo "  - $RESULT_FILE"

if [[ $CLAUDE_EXIT_CODE -ne 0 ]]; then
  exit "$CLAUDE_EXIT_CODE"
fi

if [[ ! -f "$RESULT_FILE" ]]; then
  echo "Missing required result file: $RESULT_FILE" >&2
  exit 1
fi

if [[ -z "$RESULT_STATUS" ]]; then
  echo "Missing STATUS line in $RESULT_FILE" >&2
  exit 1
fi
