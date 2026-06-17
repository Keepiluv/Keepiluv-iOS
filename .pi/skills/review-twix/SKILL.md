---
name: review-twix
description: Use this skill for Twix iOS code, diff, PR, and architecture compliance review. Default behavior is report-only unless edits are explicitly requested.
---

# review-twix

## 목적

Twix iOS 코드, diff, PR, 문서 변경을 아키텍처/TCA/MFA 관점에서 리뷰합니다.

이 skill은 기존 임시 MODE 2 코드/아키텍처 리뷰 흐름을 대체합니다. 기본 동작은 **보고 전용**이며, 명시 요청 없이는 파일을 수정하지 않습니다.

## 사용 시점

- PR 리뷰
- 구현 전 아키텍처 적합성 검토
- 구현 후 리스크 점검
- 코드가 canonical docs를 따르는지 확인
- docs-refactor 또는 향후 구현 작업에 넘길 구조화된 발견 사항 생성

## 기준 문서

우선순위:

1. `AGENTS.md`
2. `docs/Architecture/Overview.md`
3. `docs/Reference/ProjectRules.md`
4. `docs/Reference/Checklists.md`
5. `docs/Reference/FileOrganization.md`
6. `docs/Reference/NamingConventions.md`
7. `docs/Guides/NavigationStack.md`
8. `docs/Guides/NetworkGuide.md`
9. `docs/QuickStart.md`는 튜토리얼로만 취급

`CLAUDE.md`는 Claude Code 진입점이며 아키텍처 source of truth가 아닙니다.

## 리뷰 항목

- Clean Architecture boundary
- MFA Interface/Sources split
- dependency direction
- 올바른 module / feature / layer 배치
- One Type Per File 기본 원칙
- TCA State / Action / Reducer ownership
- side effects through dependencies and Effects
- minimal public API
- duplicate clients / factories / routes / models
- struct-based TCA Clients by default
- protocol overgeneration 금지
- `[Route]` 배열 NavigationStack 패턴
- `StackState` / `StackActionOf` recommended usage 금지
- TokenManager / TokenStorage rule
- direct Keychain / UserDefaults / token persistence access 금지
- duplicated Authorization/header/refresh logic 금지
- testing/build verification limits

## 검증 정책

- Setup/generation: `tuist install`, `tuist generate`, 필요 시 `tuist clean`
- CI/PR verification: `bundle exec fastlane ios ci_pr`
- Bundler 사용 불가 시: `fastlane ios ci_pr`
- direct `xcodebuild`는 scheme / destination / configuration이 명시적으로 문서화되었거나 제공된 경우에만 사용합니다.
- 검증을 실행할 수 없으면 검증 한계를 보고합니다.

## 금지 사항

- 명시 요청 없이 파일 수정 금지
- 자동 refactor 금지
- 아키텍처 규칙 invent 금지
- implementation skill 생성 금지
- TypeScript extension 생성 금지
- `CLAUDE.md`를 아키텍처 source of truth로 취급 금지

## 출력 형식

한국어로 보고합니다.

```text
리뷰 범위:
- 

적용한 규칙:
- 

발견한 문제:
- ID:
  심각도:
  파일:
  위치:
  규칙/문서:
  문제:
  영향도:
  권장 수정:

바로 수정 가능한 항목:
- 

확인 필요한 항목:
- 

검증 결과 / 검증 한계:
- 

docs-refactor에 전달할 문서 이슈:
- 

향후 구현 작업에 전달할 수정 후보:
- 
```
