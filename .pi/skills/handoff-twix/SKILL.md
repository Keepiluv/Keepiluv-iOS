---
name: handoff-twix
description: Use this skill to coordinate concise low-token handoffs between Pi, Claude Code, review-twix, fix-review, and final-review in the Twix iOS repository.
---

# handoff-twix

## 목적

`handoff-twix`는 Pi, Claude Code, `review-twix`, `fix-review`, `final-review` 사이의 low-token handoff를 조율합니다.

이 skill은 implementation skill이 아닙니다. 명시 요청이 없는 한 Pi가 feature를 직접 구현하지 않습니다. Pi가 계획과 handoff 파일을 만들고, Claude Code가 구현하며, Pi가 review/fix/finalize를 이어갈 수 있도록 간결한 handoff 파일과 runner를 사용합니다.

## Invocation behavior

`handoff-twix`는 누가 작업을 수행할지 조율하는 orchestration skill입니다. 사용자가 handoff를 명시적으로 요청한 경우, 의미상 가장 가까운 다른 skill로 collapse하거나 silent switch하지 않습니다. 명시 요청이 없는 한 Pi가 직접 구현/문서 rewrite를 수행하지 않습니다.

Rules:

1. 사용자가 concrete task 없이 `/skill:handoff-twix`만 호출한 경우:
   - task를 추론하지 않습니다.
   - `docs-refactor`, `review-twix`, `fix-review`, `final-review`로 전환하지 않습니다.
   - 어떤 handoff workflow를 원하는지 질문합니다.
   - 다음 선택지를 간결하게 제시합니다.
     - full handoff with Claude Code
     - create handoff files only
     - continue after Claude implementation
     - review implementation result
     - apply approved fixes
     - proceed to final-review

2. 사용자가 `/skill:handoff-twix`와 concrete task/command를 함께 제공한 경우:
   - matching handoff workflow를 즉시 수행합니다.
   - 필수 정보가 빠진 경우가 아니면 redundant clarification을 묻지 않습니다.
   - `handoff-twix` 책임 범위 안에 머무릅니다.
   - 사용자가 명시적으로 요청하지 않는 한 Pi가 직접 requested change를 구현하지 않습니다.
   - full handoff가 요청되면 Pi는 handoff 파일을 만들고 Claude Code runner를 사용하거나 준비합니다.
   - partial mode가 요청되면 해당 partial mode만 수행합니다.

3. 요청 task가 의미상 `docs-refactor`, `review-twix`, `fix-review`, `final-review`에 가까운 경우:
   - 사용자가 `handoff-twix` full handoff를 요청했다면 해당 skill로 silent switch하지 않습니다.
   - full handoff mode에서 해당 skills는 Claude implementation을 대체하지 않고 references/phases로만 사용합니다.
   - `docs-refactor`, `review-twix`, `fix-review`, `final-review`는 적절한 phase에서만 사용하거나 사용자가 해당 partial workflow를 명시적으로 요청한 경우에만 사용합니다.

4. task가 `handoff-twix` scope 밖인 경우:
   - `handoff-twix` scope 밖이라고 말합니다.
   - 적절한 skill을 제안하되, 사용자가 요청하지 않으면 자동 전환하지 않습니다.

5. 사용자가 이미 다음을 제공한 경우 “진행할까요?”를 묻지 않습니다.
   - workflow type
   - implementation agent 또는 default Claude Code runner
   - task
   - handoff 파일 작성에 충분한 scope

6. 다음처럼 필수 detail이 빠진 경우에만 질문합니다.
   - task가 제공되지 않음
   - full handoff와 files-only가 모호함
   - external Claude Code 실행이 요청되었지만 approval이 필요함
   - task에 owner decision이 필요함
   - broad refactor 또는 public API change가 암시됨

Examples:

- Example A — skill only
  - User: `/skill:handoff-twix`
  - Expected behavior: 어떤 handoff workflow를 실행할지 질문합니다. `docs-refactor`나 implementation을 시작하지 않습니다.

- Example B — full handoff
  - User: `/skill:handoff-twix` + `Run full handoff with Claude Code: make docs-refactor/review-twix/fix-review/final-review usable by Codex/Claude Code through shared workflow docs.`
  - Expected behavior: `PLAN.md`와 `IMPLEMENTATION_REQUEST.md`를 작성한 뒤 approval gates에 따라 Claude Code runner를 준비/실행합니다. Pi가 직접 docs를 수정하지 않습니다.

- Example C — files only
  - User: `/skill:handoff-twix` + `Create handoff files only for this task: ...`
  - Expected behavior: `PLAN.md`와 `IMPLEMENTATION_REQUEST.md`를 작성한 뒤 중단합니다.

- Example D — continue
  - User: `/skill:handoff-twix` + `Claude implementation is done. Continue from IMPLEMENTATION_RESULT.md and git diff.`
  - Expected behavior: result file과 `git diff`를 읽고 `review-twix` standard를 적용한 뒤 `REVIEW_REPORT.md`를 작성합니다.

- Example E — outside scope
  - User: handoff 없이 직접 docs rewrite를 요청합니다.
  - Expected behavior: 사용자가 full handoff를 원하는 것이 아니라면 `docs-refactor`가 더 적절하다고 말합니다.

## Implementation agent

Claude Code가 고정 implementation agent입니다.

- Preferred runner: `Scripts/run-claude-implementation.sh`
- Claude invocation: `claude -p`
- `--bare`는 현재 사용하지 않습니다.
- timeout은 사용하지 않습니다.
- budget은 `--max-budget-usd 5.00`입니다.
- permission mode는 `--permission-mode acceptEdits`입니다.
- manual handoff는 Claude runner를 사용할 수 없거나 사용자가 명시적으로 선택한 경우의 fallback입니다.

Codex는 이 skill의 implementation orchestration 대상이 아닙니다.

Claude implementation은 Fastlane/build verification을 실행하지 않습니다. Pi의 `final-review`가 verification, commit, PR draft를 담당합니다.

## Primary workflow

기본 동작은 end-to-end handoff입니다. 사용자가 전체 handoff를 요청하면 plan 작성부터 Claude Code handoff, 구현 후 review, 승인된 safe fix, 필요 시 final-review handoff까지 한 흐름으로 조율합니다.

1. Pi가 concise implementation plan을 만듭니다.
2. Pi가 Claude Code용 handoff 파일을 작성합니다.
3. Claude Code가 runner 또는 manual handoff로 구현합니다.
4. Claude Code가 concise implementation result 파일을 작성합니다.
5. Pi가 `git diff`를 source of truth로 삼아 `review-twix` 기준으로 결과를 리뷰합니다.
6. 요청/승인 시 Pi가 `fix-review` 기준으로 승인된 safe finding만 수정합니다.
7. 요청 시 Pi가 `final-review`로 verification, commit, PR draft를 넘깁니다.

개별 Mode A-E는 명시적으로 요청할 때 사용하는 partial workflow입니다. 전체 흐름을 진행하려면 Default workflow를 우선합니다.

## 기준 문서

항상 먼저 읽습니다.

1. `AGENTS.md`

필요한 경우에만 canonical docs를 읽습니다.

- `docs/Reference/Checklists.md`
- `docs/Reference/ProjectRules.md`
- `docs/Guides/NavigationStack.md`
- `docs/Guides/NetworkGuide.md`
- task-specific canonical docs

규칙:

- 긴 docs 내용을 handoff 파일에 복사하지 않습니다.
- handoff 파일은 canonical docs를 path로 참조합니다.
- `CLAUDE.md`를 architecture source of truth로 취급하지 않습니다.
- 삭제된 `Prompt.md`를 사용하지 않습니다.
- 구현 후에는 `git diff`를 source of truth로 사용합니다.
- `AGENTS.md` 또는 project docs를 길게 재진술하지 않습니다.

## Handoff directory

사용 경로:

```text
.agent/handoff/
```

예상 파일:

```text
.agent/handoff/PLAN.md
.agent/handoff/IMPLEMENTATION_REQUEST.md
.agent/handoff/IMPLEMENTATION_RESULT.md
.agent/handoff/REVIEW_REPORT.md
.agent/handoff/FIX_REPORT.md
.agent/handoff/claude.out
.agent/handoff/claude.err
```

## 공통 원칙

- handoff 파일은 간결하게 유지합니다.
- 파일을 작성했다면 chat에는 큰 plan을 출력하지 않습니다.
- verbose chat output보다 structured handoff file을 우선합니다.
- full diff를 출력하지 않습니다. 요청 시에만 출력합니다.
- 다른 agent가 같은 session context를 갖고 있다고 가정하지 않습니다.
- file path와 concise instruction만 전달합니다.

## Default workflow — End-to-end handoff

사용 시점: 사용자가 full handoff process를 요청할 때.

Process:

1. `.agent/handoff/PLAN.md`를 작성합니다.
2. `.agent/handoff/IMPLEMENTATION_REQUEST.md`를 작성합니다.
3. Claude Code implementation 방식을 결정합니다.
   - preferred: `Scripts/run-claude-implementation.sh`
   - fallback: manual handoff to Claude Code
4. runner 실행이 요청된 경우:
   - `Scripts/run-claude-implementation.sh`를 사용합니다.
   - twix-gate confirmation을 존중합니다.
   - runner는 `claude -p`를 사용합니다.
   - runner는 `--bare`를 사용하지 않습니다.
   - runner는 timeout을 사용하지 않습니다.
   - runner는 budget `5.00 USD`를 사용합니다.
   - runner는 Claude에게 Read/Edit/Write와 limited read-only bash만 허용합니다.
   - runner는 git add/commit/push, Fastlane, xcodebuild, `tuist clean`, destructive commands를 금지합니다.
5. manual handoff가 선택된 경우:
   - handoff 파일 작성 후 중단합니다.
   - Claude Code에게 전달할 정확하고 간결한 instruction을 제공합니다.
6. Claude implementation 완료 후:
   - 있으면 `.agent/handoff/IMPLEMENTATION_RESULT.md`를 읽습니다.
   - result file에 `STATUS: DONE | BLOCKED | NO_CHANGES | FAILED` 중 하나가 있는지 확인합니다.
   - `git diff`를 inspect합니다.
   - `git diff`를 source of truth로 사용합니다.
7. `review-twix` standard를 실행합니다.
8. `.agent/handoff/REVIEW_REPORT.md`를 작성합니다.
9. finding이 있으면:
   - blocking / non-blocking으로 분류합니다.
   - `fix-review`로 안전하게 수정 가능한지 분류합니다.
10. 사용자가 safe finding 자동 수정을 이미 승인한 경우:
    - 승인되고 safe로 분류된 finding만 `fix-review`로 수정합니다.
    - `.agent/handoff/FIX_REPORT.md`를 작성합니다.
11. auto-fix 승인이 없으면:
    - 중단하고 어떤 finding을 수정할지 질문합니다.
12. 요청된 경우 `final-review`로 hand off합니다.
13. `handoff-twix` 내부에서는 commit, push, PR 생성을 하지 않습니다.

Important approval policy:

- Plan approval은 commit approval이 아닙니다.
- Handoff execution approval은 git commit approval이 아닙니다.
- Claude runner 실행 approval은 git commit approval이 아닙니다.
- `fix-review` approval은 `final-review` commit approval과 별개입니다.
- broad refactor, owner-decision finding, public API change, risky architecture change는 approval을 위해 중단합니다.

## Claude runner behavior

`Scripts/run-claude-implementation.sh`는 repository root에서 실행합니다.

Runner responsibilities:

- `.agent/handoff/IMPLEMENTATION_REQUEST.md` 존재 확인
- `.agent/handoff/` 생성 보장
- `uuidgen`이 있으면 UUID session id 생성, 없으면 timestamp fallback 사용
- Claude stdout을 `.agent/handoff/claude.out`에 저장
- Claude stderr를 `.agent/handoff/claude.err`에 저장
- Claude 종료 후 `.agent/handoff/IMPLEMENTATION_RESULT.md` 존재 확인
- result file에 `STATUS:` line이 있는지 확인
- session id, exit code, result status, output files를 짧게 출력
- Claude 실패, result file 누락, `STATUS:` 누락 시 non-zero 반환

Claude must write:

```text
.agent/handoff/IMPLEMENTATION_RESULT.md
```

Required result status:

```text
STATUS: DONE | BLOCKED | NO_CHANGES | FAILED
```

## Partial workflows / explicit subcommands

아래 Mode A-E는 사용자가 명시적으로 요청할 때 사용하는 optional partial workflow입니다. 정상적인 필수 순서가 아니며, full handoff 요청에는 Default workflow를 우선 적용합니다.

예시 요청:

- “Run full handoff with Claude Code”
- “Create handoff files only”
- “Run Claude implementation runner”
- “Continue after Claude implementation”
- “Review implementation result”
- “Apply approved fixes”
- “Proceed to final-review”

## Mode A — Create Claude implementation handoff

사용 시점: 사용자가 Claude Code용 작업 계획 파일만 만들라고 요청할 때.

Process:

1. `AGENTS.md`를 읽습니다.
2. 관련 파일만 inspect합니다.
3. architecture fit을 식별합니다.
4. `.agent/handoff/PLAN.md`를 작성합니다.
5. `.agent/handoff/IMPLEMENTATION_REQUEST.md`를 작성합니다.
6. 구현하지 않습니다.
7. 최종 chat output은 짧게 작성 파일만 알립니다.

`PLAN.md` 포함 항목:

- Goal
- Scope
- Relevant canonical docs
- Expected files or modules
- Architecture constraints
- Forbidden patterns
- Verification expectation
- Open questions

`IMPLEMENTATION_REQUEST.md` 포함 항목:

- `AGENTS.md` 먼저 읽기
- `PLAN.md` 읽기
- minimal diffs로 구현
- 구현 후 `IMPLEMENTATION_RESULT.md` 작성
- `IMPLEMENTATION_RESULT.md`에 `STATUS: DONE | BLOCKED | NO_CHANGES | FAILED` 포함
- 긴 설명 출력 금지
- `StackState`/`StackActionOf` 사용 금지
- `TokenStorage` 직접 접근 금지
- `xcodebuild` command invent 금지
- git add/commit/push 금지
- Fastlane/build verification 실행 금지
- `tuist clean` 실행 금지

## Mode B — Run or prepare Claude implementation

사용 시점: 사용자가 handoff를 기반으로 Claude Code 구현을 실행하거나 manual handoff instruction을 원할 때.

Process:

1. `IMPLEMENTATION_REQUEST.md`를 prompt source로 사용합니다.
2. preferred runner는 `Scripts/run-claude-implementation.sh`입니다.
3. runner 실행은 명시 요청과 twix-gate confirmation을 필요로 합니다.
4. runner를 사용할 수 없으면 manual handoff instruction을 제공합니다.
5. unknown Claude Code command를 hardcode하지 않습니다. 이 repo의 runner가 canonical command입니다.

## Mode C — Review implementation result

사용 시점: 사용자가 Claude Code 작업이 끝났고 review만 이어서 하라고 말할 때.

Process:

1. 있으면 `.agent/handoff/IMPLEMENTATION_RESULT.md`를 읽습니다.
2. `STATUS:` line을 확인합니다.
3. `git diff`를 inspect합니다.
4. 변경 diff에 `review-twix` standard를 적용합니다.
5. `.agent/handoff/REVIEW_REPORT.md`를 작성합니다.
6. 요청이 없으면 긴 review를 chat에 출력하지 않습니다.
7. blocking issue가 있으면 짧은 요약을 보고하고 `fix-review` 실행 여부를 묻습니다.

## Mode D — Apply approved fixes

사용 시점: 사용자가 review finding 수정을 승인했을 때.

Process:

1. `REVIEW_REPORT.md`를 primary input으로 사용합니다.
2. `fix-review` standard를 적용합니다.
3. 승인된 finding만 수정합니다.
4. `.agent/handoff/FIX_REPORT.md`를 작성합니다.
5. commit하지 않습니다.

## Mode E — Finalize

사용 시점: 사용자가 PR finalization으로 진행하라고 요청할 때.

Process:

1. `final-review`로 hand off합니다.
2. `final-review`가 verification, commit, PR draft를 처리합니다.
3. `final-review` workflow를 중복하지 않습니다.

## Token efficiency rules

- chat output을 짧게 유지합니다.
- file output을 우선합니다.
- 요청 없이 full diff를 출력하지 않습니다.
- end-to-end mode에서는 stage summary와 file path만 chat에 표시합니다.
- 요청 없이 full `PLAN.md`, full `REVIEW_REPORT.md`, full `IMPLEMENTATION_RESULT.md`, full diff를 출력하지 않습니다.
- `AGENTS.md` 또는 docs 전문을 붙여넣지 않습니다.
- 다른 agent에게 긴 summary 출력을 요구하지 않습니다.
- Claude Code는 verbose chat reply 대신 result file을 작성하도록 요청합니다.

## External agent rules

- Claude Code만 implementation agent로 사용합니다.
- Preferred execution path는 `Scripts/run-claude-implementation.sh`입니다.
- Manual Claude Code handoff는 fallback입니다.
- 사용자가 달리 말하지 않는 한 Pi가 review/fix/final-review 책임을 유지합니다.
- Claude Code가 같은 session context를 갖고 있다고 가정하지 않습니다.
- file path와 concise instruction만 전달합니다.

## Safety

- twix-gate approval gate를 존중합니다.
- 명시 사용자 승인 없이 Claude runner를 실행하지 않습니다.
- commit하지 않습니다.
- push하지 않습니다.
- PR을 열지 않습니다.
- permission을 우회하지 않습니다.
- dangerous auto-approval flag를 사용하지 않습니다.
- Claude를 full-auto/yolo/bypass mode로 실행하지 않습니다.
- plan/handoff/fix approval을 final-review commit approval로 간주하지 않습니다.
- Claude implementation은 verification/commit/PR draft를 수행하지 않습니다.

## 출력 형식

한국어로 보고합니다.

### End-to-end mode

```text
진행 단계:
- 

작성/갱신한 handoff 파일:
- 

구현 agent:
- Claude Code

리뷰 결과:
- 

자동 수정:
- 

다음 단계:
- 
```

### Mode A

```text
작성한 handoff 파일:
- 

Claude Code에게 줄 다음 명령:
- 

열린 질문:
- 

토큰 절약 방식:
- 
```

### Mode C

```text
리뷰 결과 요약:
- 

REVIEW_REPORT.md 위치:
- 

blocking 이슈:
- 

fix-review 실행 여부 질문:
- 
```

### Mode D

```text
수정한 finding:
- 

FIX_REPORT.md 위치:
- 

남은 이슈:
- 
```
