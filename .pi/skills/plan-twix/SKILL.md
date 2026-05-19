---
name: plan-twix
description: Use this skill to create concise implementation plans for Twix iOS work, save them to handoff files, and track plan approval before handoff-twix implementation.
---

# plan-twix

## 목적

`plan-twix`는 Twix iOS 작업을 위한 concise implementation plan을 작성하고 approval state를 추적합니다.

이 skill은 독립적으로 사용할 수 있고, `handoff-twix` 전에 사용할 수도 있습니다.

- `.agent/handoff/PLAN.md`를 작성합니다.
- `.agent/handoff/PLAN_APPROVAL.md`를 생성 또는 갱신합니다.
- 사용자가 plan을 approve / revise / reject할 수 있게 합니다.
- 코드를 구현하지 않습니다.
- `.agent/handoff/PLAN.md`와 `.agent/handoff/PLAN_APPROVAL.md` 외의 project file을 수정하지 않습니다.

## Planner choice

Preferred planner:

- Codex / GPT-5.5 when available

Fallback planner:

- Pi internal planning

Optional fallback:

- Claude Code plan mode may be mentioned only as an optional fallback.
- Claude Code는 `handoff-twix`의 fixed implementation agent이므로 default planner로 사용하지 않습니다.

Planning and implementation separation:

- Codex/GPT-5.5 plans.
- Claude Code implements through `handoff-twix`.
- Pi reviews/fixes/finalizes through review/fix/final workflows.

## Invocation behavior

1. `/skill:plan-twix`가 concrete task 없이 호출된 경우:
   - task를 추론하지 않습니다.
   - 어떤 작업을 계획할지 질문합니다.

2. concrete task와 함께 호출된 경우:
   - `AGENTS.md`를 읽습니다.
   - 필요한 경우에만 relevant canonical docs를 읽습니다.
   - docs 내용을 plan에 길게 복사하지 않습니다.
   - `.agent/handoff/PLAN.md`를 작성합니다.
   - `.agent/handoff/PLAN_APPROVAL.md`를 `STATUS: PENDING`으로 생성 또는 갱신합니다.
   - 한국어로 짧게 요약합니다.
   - 사용자에게 approve / revise / reject 중 선택하라고 요청합니다.

3. 사용자가 plan을 approve한 경우:
   - `.agent/handoff/PLAN_APPROVAL.md`를 `STATUS: APPROVED`로 갱신합니다.
   - 필요한 경우 `.agent/handoff/PLAN.md`의 status를 `STATUS: APPROVED`로 갱신합니다.
   - 구현을 시작하지 않습니다.
   - 이제 `handoff-twix`를 실행할 수 있다고 안내합니다.

4. 사용자가 revise를 요청한 경우:
   - `.agent/handoff/PLAN.md`를 갱신합니다.
   - `.agent/handoff/PLAN_APPROVAL.md`는 `STATUS: PENDING`으로 유지합니다.
   - 구현을 시작하지 않습니다.

5. 사용자가 reject한 경우:
   - `.agent/handoff/PLAN_APPROVAL.md`를 `STATUS: REJECTED`로 갱신합니다.
   - 필요한 경우 `.agent/handoff/PLAN.md`의 status를 `STATUS: REJECTED`로 갱신합니다.
   - 진행하지 않습니다.

## PLAN.md required format

```text
STATUS: PROPOSED | APPROVED | BLOCKED | REJECTED
# Plan
## Goal
## Scope
## Relevant canonical docs
## Expected files/modules
## Architecture constraints
## Forbidden patterns
## Verification expectation
## Open questions
## Handoff notes
```

## PLAN_APPROVAL.md required format

```text
STATUS: PENDING | APPROVED | REJECTED
# Plan Approval
## Decision
## Approved plan file
## Notes
```

## Planning rules

- Plan approval은 implementation approval이 아닙니다.
- Plan approval은 commit approval이 아닙니다.
- `handoff-twix`는 implementation에 여전히 Claude Code runner를 사용해야 합니다.
- `final-review`는 verification, commit, PR draft를 계속 담당해야 합니다.
- plan이 broad refactor, public API change, new architecture exception, owner decision을 암시하면:
  - `STATUS: BLOCKED`로 표시하거나
  - `Open questions`에 명시합니다.
- `xcodebuild` command를 invent하지 않습니다.
- Verification expectation은 Pi/final-review의 Fastlane 기준을 사용합니다.
  - `bundle exec fastlane ios ci_pr`
  - fallback: `fastlane ios ci_pr`
- direct `TokenStorage`, Keychain, UserDefaults 접근을 제안하지 않습니다.
- `StackState`, `StackActionOf`를 제안하지 않습니다.
- feature client를 기본적으로 protocol-based로 제안하지 않습니다.
- Interface public type을 강제로 `Source.swift`에 몰아넣는 계획을 제안하지 않습니다.
- 프로젝트 문서의 긴 내용을 plan에 복사하지 않고 path로 참조합니다.
- 최소 diff, module boundary, dependency direction, public API 최소화를 우선합니다.

## Relationship to handoff-twix

- `handoff-twix`는 `.agent/handoff/PLAN_APPROVAL.md`가 `STATUS: APPROVED`일 때만 `.agent/handoff/PLAN.md`를 reuse해야 합니다.
- `PLAN.md`가 있어도 approval이 pending/rejected이면 `handoff-twix`는 중단하고 plan approval 또는 revision을 요청해야 합니다.
- 이 skill은 명시 요청이 없는 한 `.agent/handoff/IMPLEMENTATION_REQUEST.md`를 만들지 않습니다.
- 이 skill은 implementation agent를 실행하지 않습니다.

## Output format

한국어로 보고합니다.

```text
작성한 파일:
- 

planner:
- 

plan status:
- 

핵심 계획 요약:
- 

열린 질문:
- 

승인 선택지:
- approve
- revise
- reject

다음 단계:
- 
```
