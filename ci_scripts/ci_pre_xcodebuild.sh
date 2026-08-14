#!/bin/sh
#
# Xcode Cloud pre-xcodebuild script — 빌드번호 주입.
#
# Tuist 가 생성하는 Info.plist 의 CFBundleVersion 기본값은 1 이다. 그대로 아카이브하면
# App Store Connect 가 "이미 올라간 빌드보다 높아야 한다"며 거부한다.
#
# 규칙: UTC YYMMDDHHMM (예: 2608140135)
#   - fastlane/Fastfile 의 deploy_develop / deploy_main 과 **동일한 규칙**이다.
#     TwixDebug 와 Twix 는 번들 ID 가 같아 App Store Connect 앱 레코드를 공유하므로,
#     두 파이프라인이 같은 규칙을 써야 서로의 업로드를 막지 않는다.
#   - 항상 단조 증가한다. 기존 규칙(commit_count * 100 + run # % 100)은 같은 커밋에서
#     재실행하면 역행할 수 있었다.
#   - 한계: 분 단위 해상도라 같은 분에 두 번 업로드하면 충돌한다. 그 경우 재실행하면 된다.
#   - CFBundleVersion 각 구성요소의 상한은 2^32-1 이다. 이 규칙은 2042 년까지 안전하다.

set -eu

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO_ROOT"

BUILD_NUMBER="$(date -u +%y%m%d%H%M)"
echo "[pre-xcodebuild] CFBundleVersion = $BUILD_NUMBER"

written=0
for plist in \
    "Projects/App/Derived/InfoPlists/Twix-Info.plist" \
    "Projects/App/Derived/InfoPlists/TwixDebug-Info.plist"
do
    if [ -f "$plist" ]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$plist"
        echo "[pre-xcodebuild] wrote $plist"
        written=$((written + 1))
    fi
done

if [ "$written" -eq 0 ]; then
    echo "[pre-xcodebuild] ERROR: no Derived Info.plist found — did ci_post_clone.sh run?" >&2
    exit 1
fi

echo "[pre-xcodebuild] done ($written plist updated)"
