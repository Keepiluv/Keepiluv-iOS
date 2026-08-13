#!/bin/sh
#
# Xcode Cloud post-clone script.
#
# 이 저장소는 Tuist 로 프로젝트를 생성하고 .xcodeproj / .xcworkspace 를 커밋하지 않는다
# (.gitignore). 따라서 clone 직후 이 스크립트가 프로젝트를 생성해야만 Xcode Cloud 가
# 빌드할 대상을 갖는다.
#
# 실행 환경 (Apple 문서 기준):
#   - CWD 는 ci_scripts/ 다. 저장소 루트는 $CI_PRIMARY_REPOSITORY_PATH.
#   - shebang 이 없으면 Xcode Cloud 가 zsh 로 다시 실행한다.
#   - sudo 는 사용할 수 없다.
#   - 실행 권한(755)이 필요하다.
#
# 로컬 검증:
#   sh ci_scripts/ci_post_clone.sh                       # OFF 경로 (기존과 동일하게 생성)
#   CI_XCODE_CLOUD=TRUE sh ci_scripts/ci_post_clone.sh   # ON 경로 (자동 서명으로 생성)

set -eu

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO_ROOT"
echo "[post-clone] repo root: $REPO_ROOT"

# ---------------------------------------------------------------------------
# Xcode Cloud 판별을 Tuist 매니페스트로 전달
#
# Tuist 매니페스트는 TUIST_ 접두 환경변수만 읽으므로 Xcode Cloud 의 CI_XCODE_CLOUD 를
# 직접 볼 수 없다. 여기서 번역한다.
#
# ProjectDescription 의 getBoolean 은 1/true/TRUE/yes/YES 만 참으로 읽고, 그 밖의 값은
# 조용히 default(false)로 떨어진다. 그대로 넘기면 Apple 이 값 표기를 바꿨을 때 아무 소리
# 없이 Manual 서명으로 빌드되므로, true/false 리터럴로 정규화해서 내보낸다.
# ---------------------------------------------------------------------------
normalize_bool() {
    case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
        1|true|yes) echo "true" ;;
        *)          echo "false" ;;
    esac
}

TUIST_XCODE_CLOUD="$(normalize_bool "${TUIST_XCODE_CLOUD:-${CI_XCODE_CLOUD:-false}}")"
export TUIST_XCODE_CLOUD
echo "[post-clone] TUIST_XCODE_CLOUD=$TUIST_XCODE_CLOUD (CI_XCODE_CLOUD=${CI_XCODE_CLOUD:-unset})"

# ---------------------------------------------------------------------------
# mise 확보 (Tuist 버전은 mise.toml 이 고정한다)
# ---------------------------------------------------------------------------
if [ -x "$HOME/.local/bin/mise" ]; then
    PATH="$HOME/.local/bin:$PATH"
    export PATH
fi

if ! command -v mise >/dev/null 2>&1; then
    echo "[post-clone] installing mise"
    TMP="$(mktemp -d)"
    # 파이프로 바로 실행하지 않는다 — 전송이 중간에 끊기면 잘린 설치 스크립트가
    # 실행된 뒤에야 파이프라인 상태를 읽게 된다.
    if curl --fail --location --show-error --silent \
            --retry 3 --retry-connrefused \
            -o "$TMP/mise-install.sh" https://mise.run; then
        sh "$TMP/mise-install.sh"
    elif command -v brew >/dev/null 2>&1; then
        echo "[post-clone] mise.run unreachable — falling back to Homebrew"
        brew install mise
    else
        echo "[post-clone] ERROR: cannot install mise (mise.run unreachable, no Homebrew)" >&2
        exit 1
    fi
    PATH="$HOME/.local/bin:$PATH"
    export PATH
fi

command -v mise >/dev/null 2>&1 || { echo "[post-clone] ERROR: mise not on PATH" >&2; exit 1; }
echo "[post-clone] mise: $(mise --version)"

# ---------------------------------------------------------------------------
# Tuist 설치 및 프로젝트 생성
# ---------------------------------------------------------------------------
mise install
echo "[post-clone] tuist: $(mise exec -- tuist version)"

mise exec -- tuist install

# --cache-profile none 은 유지해야 한다. binary cache 가 채워지면 XCFramework 경로가
# link line 에 누적되어 ARG_MAX 를 초과한다 (fastlane/Fastfile:107-113 참고).
mise exec -- tuist generate --no-open --cache-profile none

# ---------------------------------------------------------------------------
# 생성 결과 확인
# ---------------------------------------------------------------------------
if [ ! -d "$REPO_ROOT/Twix.xcworkspace" ]; then
    echo "[post-clone] ERROR: Twix.xcworkspace was not generated" >&2
    exit 1
fi

echo "[post-clone] done — Twix.xcworkspace generated"
