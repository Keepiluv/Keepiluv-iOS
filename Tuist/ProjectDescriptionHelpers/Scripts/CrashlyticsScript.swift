import ProjectDescription

public extension TargetScript {
    /// Firebase Crashlytics dSYM 업로드 스크립트입니다.
    ///
    /// 로컬 Archive 빌드 시 생성된 dSYM 전부를 Firebase Console로 업로드해 크래시 스택을
    /// 심볼화합니다. 앱뿐 아니라 `$DWARF_DSYM_FOLDER_PATH` 안의 모든 `.dSYM`(Firebase,
    /// GoogleSignIn, Kakao 등 framework 포함)을 순회합니다.
    ///
    /// CI 환경(`$CI == "true"`)에선 Fastlane `upload_symbols_to_crashlytics`가 동일 작업을
    /// 더 신뢰성 있게 수행하므로 중복 방지를 위해 즉시 종료합니다.
    static let crashlyticsUploadSymbols = TargetScript.post(
        script: #"""
        if [ "${CI:-}" = "true" ]; then
            echo "note: CI environment detected — dSYM upload handled by Fastlane (skipping build-phase upload)"
            exit 0
        fi

        if [ ! -d "$DWARF_DSYM_FOLDER_PATH" ]; then
            echo "note: $DWARF_DSYM_FOLDER_PATH not found (DEBUG_INFORMATION_FORMAT may not be dwarf-with-dsym) — skipping"
            exit 0
        fi

        UPLOAD_SYMBOLS="$SRCROOT/../../Tuist/.build/checkouts/firebase-ios-sdk-xcframeworks/Sources/FirebaseCrashlytics/upload-symbols"
        if [ ! -x "$UPLOAD_SYMBOLS" ]; then
            UPLOAD_SYMBOLS=$(find "$SRCROOT/../.." -maxdepth 8 -name "upload-symbols" -path "*/FirebaseCrashlytics/*" 2>/dev/null | head -1)
        fi
        if [ -z "$UPLOAD_SYMBOLS" ] || [ ! -x "$UPLOAD_SYMBOLS" ]; then
            echo "warning: Firebase Crashlytics upload-symbols not found. Run 'tuist install'."
            exit 0
        fi

        GSP="$SRCROOT/Resources/GoogleService-Info.plist"
        if [ ! -f "$GSP" ]; then
            echo "warning: GoogleService-Info.plist not found at $GSP — skipping"
            exit 0
        fi

        FAIL=0
        for DSYM in "$DWARF_DSYM_FOLDER_PATH"/*.dSYM; do
            [ -e "$DSYM" ] || continue
            echo "Uploading dSYM: $DSYM"
            if ! "$UPLOAD_SYMBOLS" -gsp "$GSP" -p ios "$DSYM"; then
                echo "warning: upload-symbols failed for $DSYM"
                FAIL=1
            fi
        done
        exit $FAIL
        """#,
        name: "Firebase Crashlytics",
        basedOnDependencyAnalysis: false
    )
}
