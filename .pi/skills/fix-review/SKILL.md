---
name: fix-review
description: Use this skill to apply explicitly approved review-twix findings with minimal diffs, without broad implementation or reinterpretation.
---

# fix-review

## 목적

`fix-review`는 `review-twix`가 보고한 finding 중 사용자가 명시적으로 선택하거나 승인한 항목만 최소 diff로 수정합니다.

이 skill은 review 결과에 대한 후속 실행 skill입니다. broad implementation skill이 아니며, 프로젝트 전체를 독자적으로 재해석하지 않습니다.

## 다른 skill과의 관계

- `review-twix`: 문제를 찾고 기본적으로 보고만 수행합니다.
- `fix-review`: 승인된 review finding만 수정합니다.
- `final-review`: 최종 리뷰, 검증, 커밋 준비/실행 승인, PR 초안 생성을 수행합니다.
- `docs-refactor`: 문서 아키텍처/규칙 변경을 다룹니다.

문서 전용 finding이 승인된 경우 `docs-refactor`의 지침을 참고할 수 있지만, `docs-refactor` 자체를 중복하지 않습니다.

## 기준 문서

항상 먼저 읽습니다.

1. `AGENTS.md`

필요한 경우에만 관련 canonical docs를 추가로 읽습니다.

- `review-twix` report: primary input
- `docs/Reference/Checklists.md`: implementation checklist
- `docs/Reference/ProjectRules.md`: project rules
- task-specific canonical docs

`CLAUDE.md`는 architecture source of truth로 취급하지 않습니다.

## 입력 기대값

사용자는 다음 중 하나 이상을 제공하거나 참조해야 합니다.

- finding ID: 예) `R1`, `R2`
- severity filter: 예) `High only`
- 명시 승인 문구: 예) “fix R1 and R2”
- 허용 scope: 예) docs only, source only, specific files only

## 기본 동작

- finding이 명시적으로 선택되거나 승인되지 않으면 수정하지 않습니다.
- 사용자가 “fix all”이라고 하면, scope가 작고 명확한 경우가 아니면 먼저 finding 요약과 확인 요청을 합니다.
- owner decision이 필요한 finding은 추측하지 않습니다.
- broad refactor가 필요한 finding은 파일을 수정하지 않고 계획을 제안합니다.
- finding이 `AGENTS.md` 또는 canonical docs와 충돌하면 중단하고 보고합니다.

## 수정 규칙

- 최소 diff를 적용합니다.
- 기술적 의미를 보존합니다.
- style-only rewrite를 하지 않습니다.
- 새 architecture pattern을 도입하지 않습니다.
- 명시 승인 없이 public interface를 변경하지 않습니다.
- 명시 요청 없이 테스트를 만들지 않습니다.
- build command를 invent하지 않습니다.
- `TokenStorage`, Keychain, UserDefaults에 직접 접근하지 않습니다.
- `StackState`, `StackActionOf`를 도입하지 않습니다.
- Feature client는 기본적으로 protocol-based로 만들지 않습니다.
- 명시 요청 없이 삭제된 legacy docs를 복원하지 않습니다.
- 관련 없는 파일을 수정하지 않습니다.

## 금지 사항

- general implementation 수행 금지
- final-review 대체 금지
- commit 금지
- push 금지
- PR 생성 금지
- TypeScript extension 생성 금지
- 승인되지 않은 finding opportunistic fix 금지

## Workflow

### Phase 1 — Parse approved findings

- 사용자가 선택한 review finding ID를 식별합니다.
- 허용 파일/scope를 식별합니다.
- 각 finding을 다음 중 하나로 분류합니다.
  - documentation fix
  - source code fix
  - example code fix
  - verification/config fix
  - owner-decision required
  - broad refactor
- 승인 scope가 모호하면 중단하고 확인합니다.

### Phase 2 — Plan fixes

- 승인된 각 finding별 최소 수정안을 제안합니다.
- 변경 예상 파일을 나열합니다.
- 위험을 식별합니다.
- 3개 초과 파일 변경 또는 broad refactor가 필요하면 편집 전에 확인을 요청합니다.

### Phase 3 — Apply fixes

- 승인된 finding 해결에 필요한 파일만 수정합니다.
- diff를 focused하게 유지합니다.
- 기존 convention을 보존합니다.
- 승인되지 않은 finding은 함께 수정하지 않습니다.

### Phase 4 — Self-check

- 수정한 finding을 다시 점검합니다.
- 원래 문제가 해결되었는지 확인합니다.
- 금지 패턴이 도입되지 않았는지 확인합니다.
- 관련 없는 파일이 변경되지 않았는지 확인합니다.

### Phase 5 — Report

한국어로 보고합니다.

포함 항목:

- 수정한 finding
- 수정하지 않은 finding과 이유
- 변경 파일
- 변경 요약
- 자체 점검 결과
- 검증 결과 / 검증 한계
- 후속으로 `review-twix`에 다시 맡길 항목

## 검증 정책

Fastlane은 기본 실행하지 않습니다.

검증 요청이 있으면 다음을 사용합니다.

```bash
bundle exec fastlane ios ci_pr
```

Bundler를 사용할 수 없는 경우에만 fallback을 사용합니다.

```bash
fastlane ios ci_pr
```

`tuist build`를 사용하지 않습니다. `xcodebuild` scheme/destination/configuration을 invent하지 않습니다.

## 출력 형식

```text
수정한 finding:
- 

수정하지 않은 finding과 이유:
- 

변경 파일:
- 

변경 요약:
- 

자체 점검 결과:
- 

검증 결과 / 검증 한계:
- 

후속으로 review-twix에 다시 맡길 항목:
- 
```
