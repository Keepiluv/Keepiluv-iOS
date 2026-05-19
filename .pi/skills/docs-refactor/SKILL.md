---
name: docs-refactor
description: Use this skill for documentation refactoring, architecture rule changes, canonical docs cleanup, AGENTS.md updates, and reference cleanup in the Twix iOS repository.
---

# docs-refactor

## 목적

프로젝트 문서를 최소 diff로 정리하고, 아키텍처 규칙 변경/정리/이동을 안전하게 수행합니다.

이 skill은 기존 임시 MODE 1 문서 정리 흐름을 대체합니다.

## 사용 시점

- 문서 중복 제거
- canonical docs 정리
- AGENTS.md 업데이트
- architecture rule 변경 검토
- stale reference / deleted-file reference 정리
- compatibility redirect 제거 또는 이동 계획
- 문서 간 모순 해소

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

## 절차

1. 요청 범위를 확인합니다.
2. 관련 문서를 읽습니다.
3. 필요한 경우 `rg`로 참조를 확인합니다.
4. 문서 변경의 기술적 타당성을 먼저 검증합니다.
5. broad documentation edit 전에는 계획을 먼저 제시합니다.
6. 승인 후 최소 diff로 수정합니다.
7. 수정 후 다음을 검증합니다.
   - broken links
   - stale references
   - duplicate docs
   - deleted-file references
   - unresolved contradictions
   - AGENTS.md와 canonical docs 간 불일치

## 금지 사항

- 스타일만을 위한 대규모 rewrite 금지
- 아키텍처 규칙 invent 금지
- source code 수정 금지, 단 사용자가 명시적으로 요청한 경우는 예외
- implementation skill 생성 금지
- TypeScript extension 생성 금지
- `CLAUDE.md`를 아키텍처 source of truth로 취급 금지

## 검증 정책

- Setup/generation: `tuist install`, `tuist generate`, 필요 시 `tuist clean`
- CI/PR verification: `bundle exec fastlane ios ci_pr`
- Bundler 사용 불가 시: `fastlane ios ci_pr`
- direct `xcodebuild`는 scheme / destination / configuration이 명시적으로 문서화되었거나 제공된 경우에만 사용합니다.
- 검증을 실행할 수 없으면 검증 한계를 보고합니다.

## 출력 형식

한국어로 보고합니다.

```text
상태:

검토한 문서:
- 

타당성 판단:
- 

수정 파일:
- 

변경 요약:
- 

삭제/이동/병합한 규칙:
- 

남은 결정 사항:
- 

review-twix에 전달할 영향:
- 
```
