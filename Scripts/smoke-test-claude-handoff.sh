#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

HANDOFF_DIR=".agent/handoff"
REQUEST_FILE="$HANDOFF_DIR/IMPLEMENTATION_REQUEST.md"
RESULT_FILE="$HANDOFF_DIR/IMPLEMENTATION_RESULT.md"
OUT_FILE="$HANDOFF_DIR/claude.out"
ERR_FILE="$HANDOFF_DIR/claude.err"
TARGET_FILE="$HANDOFF_DIR/SMOKE_TEST_TARGET.md"
RUNNER="Scripts/run-claude-implementation.sh"

mkdir -p "$HANDOFF_DIR"

if [[ ! -x "$RUNNER" ]]; then
  echo "실패: runner가 없거나 실행 권한이 없습니다: $RUNNER" >&2
  exit 1
fi

status_without_handoff() {
  git status --porcelain --untracked-files=all \
    | grep -vE '^(.. )?\.agent/handoff/' \
    || true
}

BEFORE_STATUS="$(status_without_handoff)"
BEFORE_DIFF_HASH="$(git diff -- . ':(exclude).agent/handoff/**' | shasum | awk '{print $1}')"

rm -f \
  "$REQUEST_FILE" \
  "$RESULT_FILE" \
  "$OUT_FILE" \
  "$ERR_FILE" \
  "$TARGET_FILE"

cat > "$REQUEST_FILE" <<'REQUEST'
Read AGENTS.md first.

This is a smoke test for the Pi → Claude Code handoff runner.

Allowed change:
- Create or update only .agent/handoff/SMOKE_TEST_TARGET.md
- Write exactly this single line to it:
  smoke test completed

Required result file:
- Write .agent/handoff/IMPLEMENTATION_RESULT.md
- Include exactly one STATUS line:
  STATUS: DONE

Do not edit any other files.
Do not modify source code, docs, tests, AGENTS.md, CLAUDE.md, or skill files.
Do not run build/test/Fastlane/xcodebuild/tuist.
Do not git add, git commit, or git push.
Keep output minimal.
REQUEST

RUNNER_EXIT=0
set +e
"$RUNNER"
RUNNER_EXIT=$?
set -e

SMOKE_FAILED=0
FAIL_REASONS=()

if [[ $RUNNER_EXIT -ne 0 ]]; then
  SMOKE_FAILED=1
  FAIL_REASONS+=("runner exit code가 0이 아닙니다: $RUNNER_EXIT")
fi

if [[ ! -f "$TARGET_FILE" ]]; then
  SMOKE_FAILED=1
  FAIL_REASONS+=("SMOKE_TEST_TARGET.md가 생성되지 않았습니다")
fi

if [[ ! -f "$RESULT_FILE" ]]; then
  SMOKE_FAILED=1
  FAIL_REASONS+=("IMPLEMENTATION_RESULT.md가 생성되지 않았습니다")
elif ! grep -qE '^STATUS: DONE$' "$RESULT_FILE"; then
  SMOKE_FAILED=1
  FAIL_REASONS+=("IMPLEMENTATION_RESULT.md에 'STATUS: DONE'이 없습니다")
fi

if [[ ! -f "$OUT_FILE" ]]; then
  SMOKE_FAILED=1
  FAIL_REASONS+=("claude.out이 생성되지 않았습니다")
fi

if [[ ! -f "$ERR_FILE" ]]; then
  SMOKE_FAILED=1
  FAIL_REASONS+=("claude.err이 생성되지 않았습니다")
fi

AFTER_STATUS="$(status_without_handoff)"
AFTER_DIFF_HASH="$(git diff -- . ':(exclude).agent/handoff/**' | shasum | awk '{print $1}')"

if [[ "$BEFORE_STATUS" != "$AFTER_STATUS" || "$BEFORE_DIFF_HASH" != "$AFTER_DIFF_HASH" ]]; then
  SMOKE_FAILED=1
  FAIL_REASONS+=(".agent/handoff/ 밖의 git 상태 또는 tracked diff가 변경되었습니다")
fi

if [[ $SMOKE_FAILED -eq 0 ]]; then
  echo "성공: Claude handoff runner smoke test 통과"
else
  echo "실패: Claude handoff runner smoke test 실패" >&2
  for reason in "${FAIL_REASONS[@]}"; do
    echo "- $reason" >&2
  done
fi

echo "생성된 파일:"
echo "- $REQUEST_FILE"
echo "- $TARGET_FILE"
echo "- $RESULT_FILE"
echo "- $OUT_FILE"
echo "- $ERR_FILE"
echo "runner exit result: $RUNNER_EXIT"
echo "다음 수동 확인 명령:"
echo "- git status --short"
echo "- git diff --name-only"
echo "- sed -n '1,80p' $RESULT_FILE"

if [[ $SMOKE_FAILED -ne 0 ]]; then
  exit 1
fi
