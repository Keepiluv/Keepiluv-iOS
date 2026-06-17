# Claude Code 가이드

> Claude Code CLI에서 이 저장소를 작업할 때 사용하는 얇은 진입점입니다.

## 먼저 읽기

- 공통 에이전트 기준: @AGENTS.md
- `@AGENTS.md` import/reference가 동작하지 않는 환경에서는 [AGENTS.md](./AGENTS.md)를 먼저 읽으세요.

`AGENTS.md`가 Pi, Codex CLI, Claude Code에 공통으로 적용되는 기준입니다. 이 파일은 Claude Code 전용 메모만 유지합니다.

---

## Claude Code 작업 메모

- 작업을 시작하기 전에 `AGENTS.md`의 문서 조회 순서와 편집 정책을 따르세요.
- 팀 규칙이 필요한 작업은 [docs/Reference/ProjectRules.md](./docs/Reference/ProjectRules.md)를 함께 확인하세요.
- 상세 구현은 작업 종류에 맞는 `docs/*.md`를 확인하세요.
- 재사용 skill은 `.claude/skills/{name}/SKILL.md`에서 진입하되, 실제 원본 지침은 해당 파일이 가리키는 `.pi/skills/{name}/SKILL.md`를 읽으세요.
- `handoff-twix`는 Pi 전용 orchestration skill이므로 Claude Code skill로 사용하지 않습니다.
- 누락되었거나 링크가 깨진 문서는 추정하지 말고 사용자에게 확인하세요.

---

## Claude Code 사용 예시

```text
"AGENTS.md와 docs/Reference/ProjectRules.md를 읽고 [작업 내용] 해줘"
"docs/Guides/NetworkGuide.md 참고해서 API Client 만들어줘"
"이 Reducer가 AGENTS.md와 ProjectRules.md 규칙을 잘 따르는지 확인해줘"
```

---

## 참고

- 이 파일은 Claude Code 전용 진입점입니다.
- 프로젝트의 공통 기준은 `AGENTS.md`에 있습니다.
- 상세 기술 문서는 `docs/*.md`에 있습니다.
