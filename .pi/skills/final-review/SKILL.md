---
name: final-review
description: Use this skill before opening a PR to run final review, Fastlane CI verification, commit preparation, approved commit execution, and PR draft generation.
---

# final-review

## 목적

Twix iOS 저장소에서 PR 생성 전 또는 집중 구현/리팩터링 완료 후 사용하는 pre-PR finalization skill입니다.

이 skill은 구현 skill이 아닙니다. 기본적으로 scope 점검, 최종 리뷰, 검증, 실패 분석, 커밋 준비/실행, PR 초안 생성을 수행합니다. 명시 요청 없이는 코드를 수정하거나 리팩터링하지 않으며, PR을 열거나 push하지 않습니다.

## 기준 문서

항상 다음 기준을 따릅니다.

1. `AGENTS.md`
2. `docs/Reference/Checklists.md`
3. `docs/Reference/ProjectRules.md`
4. `.pi/skills/review-twix/SKILL.md`가 있으면 review standard로 사용

`review-twix`의 세부 규칙을 이 skill에 중복하지 않습니다. 최종 리뷰 단계에서는 `review-twix` 기준을 적용합니다.

## 금지 사항

- push 금지
- PR 생성/open 금지
- force push 금지
- 명시 요청 없는 amend / rebase / reset / stash 금지
- 명시 요청 없는 파일 수정 금지
- 명시 요청 없는 리팩터링 금지
- 명시 요청 없는 문서 수정 금지
- 테스트 생성 금지
- 구현 작업 생성 금지
- TypeScript extension 생성 금지
- 실패한 검증 숨김 금지
- secrets, env files, credentials, 예상하지 못한 generated files 커밋 금지
- tool 또는 generation source를 식별하는 commit metadata 추가 금지

## 검증 정책

우선 검증 명령:

```bash
bundle exec fastlane ios ci_pr
```

Bundler를 사용할 수 없는 경우에만 fallback:

```bash
fastlane ios ci_pr
```

- `tuist build`는 표준 검증 명령으로 사용하지 않습니다.
- direct `xcodebuild` scheme / destination / configuration을 invent하지 않습니다.
- direct `xcodebuild`는 명시적으로 문서화되었거나 제공된 경우에만 사용합니다.
- Fastlane을 로컬에서 실행할 수 없으면 정확한 검증 한계를 보고하고, 검증이 통과했다고 말하지 않습니다.

## 커밋 정책

커밋 전 반드시 확인합니다.

```bash
git branch --show-current
git status --short
git diff --stat
git diff --cached --stat
```

- 관련 없는 파일을 커밋에 포함하지 않습니다.
- 파일을 blind stage하지 않습니다.
- unstaged changes가 있으면 staging 전에 요약합니다.
- 이미 staged changes가 있으면 사용자의 staging 의도를 보존합니다.
- staged/unstaged 변경이 여러 commit scope를 암시하면 중단하고 확인합니다.
- review에서 blocking issue가 있으면 커밋하지 않습니다.
- Fastlane 검증 실패 시 커밋하지 않습니다.
- 예상하지 못한 파일, secret, env, credential, generated file 변경이 있으면 커밋하지 않습니다.
- 사용자 승인이 없으면 커밋하지 않습니다. 단, 사용자가 요청에서 명시적으로 커밋까지 지시한 경우는 예외입니다.

## 커밋 메시지 정책

형식:

```text
<type>: <Korean summary> - #<issue-number>
```

허용 type:

- `feat`
- `fix`
- `refactor`
- `docs`
- `test`
- `chore`

규칙:

- summary는 간결한 한국어로 작성합니다.
- 사용자가 명시적으로 요청하지 않으면 commit body를 추가하지 않습니다.
- footer, co-author metadata, tool attribution, generation/source marker를 추가하지 않습니다.
- issue number를 invent하지 않습니다.
- 현재 branch name에서 numeric issue suffix를 추출합니다.
- 예: `feat/#302/TWI-86` → commit suffix는 `#302`
- `TWI-86` 같은 Linear issue key는 workflow/integration 용도로 존재할 수 있지만 commit suffix를 대체하지 않습니다.
- 여러 issue-like identifier가 있으면 numeric `#<number>` segment를 우선합니다.
- numeric issue number가 없으면 커밋 전에 사용자에게 issue number를 요청합니다.
- 여러 unrelated changes가 있으면 commit split을 권장합니다.

Type 선택 기준:

- `feat`: 사용자에게 보이는 새 기능
- `fix`: 버그 수정
- `refactor`: 동작 보존 구조 변경
- `docs`: 문서만 변경
- `test`: 테스트만 변경
- `chore`: 유지보수/config/tooling 변경

## Phase 1 — Scope and branch status

- `AGENTS.md`를 읽습니다.
- 현재 branch name을 확인합니다.
- `git status --short`로 상태를 확인합니다.
- changed files와 diff summary를 확인합니다.
- staged / unstaged / mixed 상태를 구분합니다.
- 다음 정보를 바탕으로 의도된 PR/change scope를 추론합니다.
  - branch name
  - changed files
  - diff summary
  - 필요한 경우 existing commit messages
- diff가 하나의 coherent PR scope인지 점검합니다.
- 여러 unrelated scope가 있으면 split commit 또는 split PR을 권장합니다.
- branch name에서 numeric issue suffix를 추출합니다.
- 예: `feat/#302/TWI-86`이면 `#302`를 commit issue suffix로 사용합니다.
- `TWI-86` 같은 Linear key는 workflow/integration metadata로 취급하며 commit suffix로 사용하지 않습니다.
- 다음 경우 중단하고 사용자에게 확인합니다.
  - 관련 없거나 위험한 파일이 있음
  - numeric issue number를 찾을 수 없음
  - branch naming이 모호함
  - staged/unstaged 변경이 여러 commit scope를 암시함

## Phase 2 — Final review

- `review-twix` 기준을 적용합니다.
- 사용자가 더 넓은 리뷰를 요청하지 않는 한 changed files / diff만 리뷰합니다.
- 다음 리스크를 확인합니다.
  - architecture fit
  - TCA / MFA boundaries
  - Interface/Sources split
  - navigation pattern
  - network/client rules
  - TokenManager / TokenStorage rules
  - dependency direction
  - public API growth
  - docs impact
  - unexpected generated / secrets / env files
- blocking / non-blocking issue를 구분해 보고합니다.
- 명시 요청 없이는 수정하지 않습니다.

## Phase 3 — Verification

- 우선 `bundle exec fastlane ios ci_pr`를 실행합니다.
- Bundler를 사용할 수 없는 경우 `fastlane ios ci_pr`를 실행합니다.
- pass/fail을 보고합니다.
- 실행할 수 없으면 정확한 한계를 보고합니다.
- undocumented `xcodebuild` 명령으로 대체하지 않습니다.

## Phase 3B — Verification failure analysis

검증이 실패하면 자동으로 커밋 단계로 진행하지 않습니다.

- failure output을 분석합니다.
- 실패 유형을 분류합니다.
  - compile
  - lint
  - test
  - dependency
  - signing/provisioning
  - script/tooling
  - unknown
- 관련 가능성이 높은 파일 또는 모듈을 식별합니다.
- 원인을 다음 중 하나로 구분합니다.
  - current diff caused
  - environment/tooling
  - pre-existing failure
  - unknown
- 최소 다음 조치를 제안합니다.
- 명시 요청 없이는 파일을 수정하지 않습니다.
- 실패한 검증을 숨기지 않습니다.
- 적절한 경우 retry command를 포함합니다.

## Phase 4 — Commit preparation

- 다음을 확인합니다.
  - `git status --short`
  - `git diff --stat`
  - staged file이 있으면 `git diff --cached --stat`
- 이미 staged files가 있으면 사용자의 staging 의도를 보존합니다.
- 파일을 blind stage하지 않습니다.
- 커밋 대상 파일을 요약합니다.
- 관련 없는 파일을 확인합니다.
- secrets, env files, credentials, 예상하지 못한 generated files를 확인합니다.
- 다음 형식으로 커밋 메시지를 제안합니다.

```text
<type>: <Korean summary> - #<issue-number>
```

- 필요 시 split commit을 권장합니다.
- 이미 명시적으로 커밋 권한을 받은 경우가 아니면 커밋 전 승인을 요청합니다.

## Phase 5 — Commit

- 승인된 파일만 stage합니다.
- 승인된 메시지로 commit합니다.
- 명시 요청이 없으면 commit body를 추가하지 않습니다.
- footer, 외부 authorship, tool metadata를 추가하지 않습니다.
- amend, rebase, reset, stash, force push, push, PR open은 명시 요청 없이는 수행하지 않습니다.
- 커밋 후 다음을 보고합니다.
  - commit hash
  - committed files
  - verification status
  - remaining uncommitted files

## Phase 6 — PR draft

PR 제목과 설명 초안을 생성합니다. PR을 열거나 push하지 않습니다.

PR 초안은 다음을 바탕으로 작성합니다.

- branch name
- committed 또는 pending diff
- review result
- verification result
- known risks

PR 제목:

- 저장소 convention이 명확히 영어를 요구하지 않는 한 간결한 한국어로 작성합니다.

PR 설명에는 다음을 포함합니다.

- 요약
- 변경 사항
- 검증 결과
- 리뷰 포인트
- 리스크 / 후속 작업
- 관련 이슈

관련 이슈:

- numeric issue suffix가 있으면 `#302`처럼 사용합니다.
- `TWI-86` 같은 Linear key는 branch/workflow 맥락상 유용할 때만 언급하며 numeric issue reference를 대체하지 않습니다.

## 최종 보고 형식

한국어로 작성합니다.

```text
변경 범위:
- 

브랜치 / 이슈 번호:
- 

Scope 점검 결과:
- 

최종 리뷰 결과:
- 

검증 결과:
- 

검증 실패 분석:
- 

커밋 대상 파일:
- 

제안 커밋 메시지:
- 

커밋 여부:
- 

PR 제목 초안:
- 

PR 설명 초안:
- 요약:
- 변경 사항:
- 검증 결과:
- 리뷰 포인트:
- 리스크 / 후속 작업:
- 관련 이슈:

남은 리스크:
- 

다음 PR 전 확인 사항:
- 
```
