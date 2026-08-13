# Xcode Cloud 가이드

> 기존 fastlane + GitHub Actions 파이프라인은 **그대로 유지**한 채, Xcode Cloud를 **병행**으로 올리기 위한 저장소 측 준비와 설정 절차입니다.

---

## 1. 배경

이 저장소는 Tuist로 프로젝트를 생성하고 `.xcodeproj` / `.xcworkspace`를 커밋하지 않습니다(`.gitignore`). Xcode Cloud는 clone 직후 `ci_scripts/ci_post_clone.sh`가 프로젝트를 생성해야만 빌드할 대상을 갖습니다.

병행 기간 동안 Xcode Cloud는 **아카이브까지만** 수행하고 TestFlight·App Store 업로드는 하지 않습니다. 기존 GitHub Actions가 이미 `commit_count * 100 + (GITHUB_RUN_NUMBER % 100)` 규칙으로 빌드번호를 올리고 있어, Xcode Cloud의 `CI_BUILD_NUMBER`(1부터 시작)와 같은 앱 레코드에서 충돌하기 때문입니다.

---

## 2. 저장소 측 구성 (이미 반영됨)

| 파일 | 역할 |
|---|---|
| `ci_scripts/ci_post_clone.sh` | mise 확보 → Tuist 설치 → `tuist install` → `tuist generate` |
| `Projects/App/Project.swift` | `TUIST_XCODE_CLOUD` 플래그에 따른 서명 분기 |

### 서명 분기가 필요한 이유

App 타겟은 기본적으로 수동 서명입니다.

- `CODE_SIGN_STYLE = "Manual"`
- `PROVISIONING_PROFILE_SPECIFIER = "match Development org.yapp.twix"`
- `DEVELOPMENT_TEAM = VZC79KP79S`

Xcode Cloud는 cloud-managed 자동 서명을 쓰고 match 프로파일이 존재하지 않으므로, 그대로 두면 아카이브가 실패합니다. `TUIST_XCODE_CLOUD=true`일 때만 `CODE_SIGN_STYLE`을 `Automatic`으로 바꾸고 `PROVISIONING_PROFILE_SPECIFIER`를 비웁니다. `DEVELOPMENT_TEAM`은 자동 서명에도 필요하므로 유지합니다.

플래그가 꺼져 있으면 빈 딕셔너리를 병합하고 `merging([:])`는 항등이므로, **로컬 `make generate`와 기존 GitHub Actions + fastlane 경로의 생성 결과는 달라지지 않습니다.**

### 환경변수 번역

Tuist 매니페스트는 `TUIST_` 접두 환경변수만 읽으므로 Xcode Cloud의 `CI_XCODE_CLOUD`를 직접 볼 수 없습니다. `ci_post_clone.sh`가 이를 `TUIST_XCODE_CLOUD`로 번역합니다.

`getBoolean`은 `1` / `true` / `TRUE` / `yes` / `YES`만 참으로 읽고 나머지는 **조용히 기본값(false)** 으로 떨어집니다. 값을 그대로 넘기면 표기가 달라졌을 때 아무 경고 없이 Manual 서명으로 빌드되므로, 스크립트가 `true` / `false` 리터럴로 정규화해서 내보냅니다.

---

## 3. 사전 확인 체크리스트 (사용자 작업)

- [ ] **Xcode Cloud 구독이 활성화되어 있는가** — Apple Developer Program 계정에 포함된 무료 컴퓨트 시간 및 유료 플랜 상태
- [ ] **월 컴퓨트 시간 한도** — 이 프로젝트는 `--cache-profile none`으로 SPM을 소스 컴파일하므로 빌드가 깁니다. 한도를 먼저 확인하세요
- [ ] **App Store Connect 팀 권한** — Xcode Cloud 워크플로를 만들려면 Account Holder 또는 Admin 권한 필요
- [ ] **GitHub 저장소 연동 권한** — Xcode Cloud가 저장소에 접근하도록 승인할 수 있는 GitHub 권한

---

## 4. 워크플로 생성 절차

Xcode에서 진행합니다 (App Store Connect 웹에서는 최초 생성이 제한적입니다).

1. 로컬에서 `make generate`로 `Twix.xcworkspace`를 생성하고 엽니다.
2. **Product → Xcode Cloud → Create Workflow**
3. 제품(`Twix`)과 워크플로 이름을 정합니다.
4. GitHub 저장소 연동을 승인합니다.

### 권장 설정값

| 항목 | 값 | 이유 |
|---|---|---|
| **Xcode 버전** | **26.4.1** | `.github/actions/setup-build-env/action.yml`이 고정한 버전과 일치시킵니다 |
| **Action** | **Archive** 만 | 병행 기간에는 배포하지 않습니다 |
| **Scheme** | `TwixDebug` (먼저) → `Twix` | 위험이 낮은 쪽부터 검증합니다 |
| **Post-Actions** | **없음** (TestFlight·App Store 비활성) | 빌드번호 충돌 회피 |
| **Start Conditions** | 대상 브랜치 한정 권장 | 모든 PR에 걸면 컴퓨트 시간을 빠르게 소진합니다 |
| **테스트 액션** | 넣지 않음 | 이 프로젝트에는 테스트 실행이 정착되어 있지 않습니다 |

---

## 5. 첫 빌드가 실패하면 — 확인 순서

**1. 생성된 프로젝트가 xcodebuild 단계까지 살아남았는가**

Apple 문서(*Writing custom build scripts*)에 이런 문장이 있습니다:

> "Files you create with a custom build script aren't available to other custom build scripts, and Xcode Cloud deletes any files a custom build script creates. As a result, downloadable Xcode Cloud build artifacts don't include files you create with custom build scripts."

세 번째 문장이 이를 *다운로드 가능한 아티팩트*로 한정하고 있고, post-clone 생성은 Tuist·XcodeGen 사용자들 사이에서 널리 쓰이는 패턴이므로 문자 그대로의 해석은 거의 확실히 틀렸다고 봅니다. 다만 이건 **해석이지 검증된 사실이 아닙니다.** xcodebuild 로그에 workspace나 scheme을 찾지 못한다는 오류가 있으면 이 항목이 원인입니다.

**2. post-clone 로그**

`[post-clone]` 접두 로그로 어디까지 진행됐는지 확인합니다. mise 설치(프록시 환경에서 `mise.run` 접근), Tuist 버전, `tuist generate` 성공 여부 순입니다.

**3. `TUIST_XCODE_CLOUD` 값**

로그의 `[post-clone] TUIST_XCODE_CLOUD=...` 줄이 `true`인지 확인합니다. `false`면 Manual 서명으로 생성된 것이고, `CI_XCODE_CLOUD`의 실제 값도 같은 줄에 찍힙니다.

**4. 서명**

아래 두 가지가 후보입니다. **어느 쪽이 더 유력한지는 Apple 문서 근거가 없어 판단하지 않습니다.**

- **(a) 낡은 프로비저닝 프로파일 지정자** — `PROVISIONING_PROFILE_SPECIFIER`를 빈 문자열로 덮어쓰지만, `SettingsDictionary` 병합은 키를 *제거*하지 못하고 값만 바꿉니다. 빈 값이 실제로 지정자를 무력화하는지는 포럼 정황만 있습니다.
- **(b) Tuist가 주입하는 개발용 서명 ID** — Tuist의 `DefaultSettings.recommended`가 `CODE_SIGN_IDENTITY = "iPhone Developer"`를 생성된 pbxproj의 App 타겟 네 개 config 전부에 넣습니다(매니페스트 소스에는 없습니다). `Twix` 스킴은 Release로 아카이브하는데 거기에 개발용 ID가 박혀 있습니다. Xcode Cloud가 이를 덮어쓸 것으로 보고 선제적으로 키를 추가하지 않았으나, identity 관련 오류가 나면 이 항목을 재검토해야 합니다.

**5. 링크 단계**

`Argument list too long`이 나오면 `--cache-profile none`이 빠진 것입니다(`fastlane/Fastfile:107-113` 참고).

---

## 6. 알려진 리스크

**Apple이 이 구성은 실패할 수 있다고 문서로 경고합니다.** *Setting up your project to use Xcode Cloud*:

> "Xcode Cloud requires a consistent Xcode project or workspace that's continuously present. If you use a third-party tool that dynamically generates or edits your project or workspace, the initial configuration of Xcode Cloud and subsequent builds may fail."

동일한 구성(Tuist + gitignore된 프로젝트 + `ci_post_clone.sh`)에서 워크플로 생성 시 브랜치 선택기가 비어버린다는 [미해결 포럼 리포트](https://developer.apple.com/forums/thread/821480)가 있습니다.

**저장소 측에서 해결할 수 없는 문제입니다.** 실제로 시도해봐야 판명됩니다.

---

## 7. dSYM 방침 (병행 기간)

**Xcode Cloud 빌드는 dSYM을 업로드하지 않습니다.** 배포를 하지 않으므로 실제 공백은 없습니다.

다만 Xcode Cloud에서 배포를 켤 때는 반드시 재검토해야 합니다. `Tuist/ProjectDescriptionHelpers/Scripts/CrashlyticsScript.swift`의 빌드 페이즈 스크립트가 `CI=true`일 때 "fastlane이 처리한다"며 업로드를 건너뛰는데, **Xcode Cloud도 `CI=true`를 설정하면서 fastlane은 돌지 않습니다.** 그대로 배포를 켜면 dSYM이 아무 데도 올라가지 않습니다.

해결하려면 `ci_scripts/ci_post_xcodebuild.sh`를 추가하거나 위 스크립트의 분기 조건을 좁혀야 합니다. 둘 다 이번 범위 밖입니다.

---

## 8. 전환 시 정리할 것 (별도 승인 필요)

Xcode Cloud가 안정화되어 GitHub Actions CD를 폐기할 때 필요한 작업입니다.

- 빌드번호 전략 통일 — `CI_BUILD_NUMBER` vs 현재의 `commit_count * 100 + run # % 100`. **Xcode Cloud 업로드를 켜기 전 필수**
- `ci_post_xcodebuild.sh` + dSYM 업로드 + `CrashlyticsScript.swift`의 `CI=true` 분기 재검토
- `.github/workflows/cd_develop.yml`, `cd_main.yml`, `ci_pr.yml` 및 fastlane 자산 정리
- `.gitignore`의 fastlane 블록이 존재하지 않는 `src/` 경로를 가리키고 있어 `fastlane/report.xml` 등이 실제로는 무시되지 않는 문제

---

## 참고

- [Setting up your project to use Xcode Cloud](https://developer.apple.com/documentation/xcode/setting-up-your-project-to-use-xcode-cloud)
- [Writing custom build scripts](https://developer.apple.com/documentation/xcode/writing-custom-build-scripts)
- [Environment variable reference](https://developer.apple.com/documentation/xcode/environment-variable-reference)
- [Tuist — Dynamic configuration](https://tuist.dev/en/docs/guides/features/projects/dynamic-configuration)
