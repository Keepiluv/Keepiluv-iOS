#!/bin/sh
#
# Xcode Cloud post-xcodebuild script — Crashlytics dSYM 업로드.
#
# 왜 필요한가:
#   Tuist/ProjectDescriptionHelpers/Scripts/CrashlyticsScript.swift 의 빌드 페이즈
#   스크립트는 CI=true 일 때 "fastlane 이 처리한다"며 업로드를 건너뛴다. Xcode Cloud 도
#   CI=true 를 설정하지만 fastlane 은 돌지 않으므로, 이 스크립트가 없으면 Xcode Cloud 로
#   올라간 빌드의 크래시가 영영 심볼화되지 않는다.
#
# 각 경로의 담당:
#   로컬 개발      → 빌드 페이즈 스크립트 (CI 미설정)
#   GitHub Actions → fastlane upload_symbols_to_crashlytics
#   Xcode Cloud    → 이 스크립트
#   서로 겹치지 않는다.
#
# 아카이브 안의 dSYM 전부(앱 + 프레임워크)를 올린다. 빌드 페이즈 스크립트는 타겟 하나의
# dSYM 만 보므로 이쪽이 fastlane 과 동등한 범위다.
#
# 실패 정책: 업로드에 실패하면 **빌드를 실패시킨다.** dSYM 이 조용히 빠지는 상황이
# 바로 이 스크립트를 만들게 된 원인이다. 경고만 하고 넘기려면 아래 `exit 1` 을 `exit 0`
# 으로 바꾸면 된다.

set -eu

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO_ROOT"

ACTION="${CI_XCODEBUILD_ACTION:-unknown}"
EXIT_CODE="${CI_XCODEBUILD_EXIT_CODE:-0}"

# 아카이브가 아니거나 xcodebuild 가 실패했으면 올릴 것이 없다.
if [ "$ACTION" != "archive" ]; then
    echo "[post-xcodebuild] action=$ACTION — 아카이브가 아니므로 dSYM 업로드 생략"
    exit 0
fi

if [ "$EXIT_CODE" != "0" ]; then
    echo "[post-xcodebuild] xcodebuild exit=$EXIT_CODE — 실패한 빌드이므로 dSYM 업로드 생략"
    exit 0
fi

if [ -z "${CI_ARCHIVE_PATH:-}" ] || [ ! -d "$CI_ARCHIVE_PATH" ]; then
    echo "[post-xcodebuild] ERROR: CI_ARCHIVE_PATH 가 없다 (${CI_ARCHIVE_PATH:-unset})" >&2
    exit 1
fi

DSYM_DIR="$CI_ARCHIVE_PATH/dSYMs"
if [ ! -d "$DSYM_DIR" ]; then
    echo "[post-xcodebuild] ERROR: $DSYM_DIR 가 없다 — DEBUG_INFORMATION_FORMAT 확인 필요" >&2
    exit 1
fi

# upload-symbols 는 tuist install 이 받아온 Firebase SPM 체크아웃 안에 있다.
UPLOAD_SYMBOLS="Tuist/.build/checkouts/firebase-ios-sdk-xcframeworks/Sources/FirebaseCrashlytics/upload-symbols"
if [ ! -x "$UPLOAD_SYMBOLS" ]; then
    UPLOAD_SYMBOLS="$(find Tuist/.build -name upload-symbols -path '*/FirebaseCrashlytics/*' 2>/dev/null | head -1)"
fi
if [ -z "$UPLOAD_SYMBOLS" ] || [ ! -x "$UPLOAD_SYMBOLS" ]; then
    echo "[post-xcodebuild] ERROR: upload-symbols 를 찾지 못했다 — ci_post_clone.sh 의 tuist install 이 돌았는지 확인" >&2
    exit 1
fi

GSP="Projects/App/Resources/GoogleService-Info.plist"
if [ ! -f "$GSP" ]; then
    echo "[post-xcodebuild] ERROR: $GSP 가 없다" >&2
    exit 1
fi

echo "[post-xcodebuild] archive : $CI_ARCHIVE_PATH"
echo "[post-xcodebuild] uploader: $UPLOAD_SYMBOLS"

uploaded=0
failed=0
for dsym in "$DSYM_DIR"/*.dSYM; do
    [ -e "$dsym" ] || continue
    name="$(basename "$dsym")"
    # usage 가 `upload-symbols [flags] -- <paths>` 이므로 `--` 로 경로를 분리한다.
    if "$UPLOAD_SYMBOLS" -gsp "$GSP" -p ios -- "$dsym"; then
        echo "[post-xcodebuild]   uploaded $name"
        uploaded=$((uploaded + 1))
    else
        echo "[post-xcodebuild]   FAILED   $name" >&2
        failed=$((failed + 1))
    fi
done

if [ "$uploaded" -eq 0 ]; then
    echo "[post-xcodebuild] ERROR: $DSYM_DIR 에서 올린 dSYM 이 하나도 없다" >&2
    exit 1
fi

if [ "$failed" -gt 0 ]; then
    echo "[post-xcodebuild] ERROR: dSYM $failed 개 업로드 실패 (성공 $uploaded 개)" >&2
    exit 1
fi

echo "[post-xcodebuild] done — dSYM $uploaded 개 업로드 완료"
