# AGENTS.md

Cross-agent baseline instructions for this repository.

This file summarizes the stable project rules that apply to any coding agent. Detailed technical guidance remains in `docs/*.md`; Claude Code-specific guidance remains in `CLAUDE.md`; reusable Pi skills live under `.pi/skills/`.

---

## Project baseline

- Platform: iOS only
- Minimum target: iOS 17
- UI: SwiftUI
- State management: TCA 1.23
- Architecture: Clean Architecture + Micro Feature Architecture (MFA)
- Project docs are authoritative. Do not invent architecture rules.

Core principles:

- Keep Interface and Implementation separated.
- Use TCA Dependency Container for dependency injection.
- Use ViewFactory/factory-based external view composition where required.
- Do not access token storage directly; token access must be mediated through TokenManager.
- Prefer minimal, deterministic, reproducible changes.
- Ask for missing files or unclear project information instead of assuming.

---

## Documentation roles

### `AGENTS.md`

Cross-agent operational baseline:

- project stack
- safe editing policy
- architecture guardrails
- documentation lookup order
- known unresolved items

### `CLAUDE.md`

Claude Code-specific guide:

- Claude Code quick reference
- Claude-specific usage tips
- links into detailed documentation

Do not treat Claude-specific workflow tips as universal agent rules unless also stated here or in technical docs.

### Reusable agent skills

Canonical skill instructions live under `.pi/skills/`.

Cross-agent skills:

- `docs-refactor`: documentation refactoring and architecture rule cleanup
- `review-twix`: Twix iOS architecture/code review
- `fix-review`: apply explicitly approved review findings with minimal diffs
- `final-review`: pre-PR review, verification, commit preparation, and PR draft

Agent-specific access:

- Pi uses `.pi/skills/{name}/SKILL.md` directly.
- Claude Code uses `.claude/skills/{name}/SKILL.md` thin links that point back to the canonical `.pi/skills/` files.
- Codex CLI uses `.codex/skills/{name}/SKILL.md` thin links that point back to the canonical `.pi/skills/` files.

Pi-only skill:

- `handoff-twix` remains Pi-only because it orchestrates Pi-specific handoff, runner, review/fix/final-review flow.

### `docs/*.md`

Project technical documentation:

- architecture details
- feature implementation rules
- TCA patterns
- network guide
- navigation guide
- naming conventions
- file organization rules
- checklists and examples

Use these docs for implementation details rather than expanding `AGENTS.md` with long tutorials.

---

## Recommended documentation lookup order

Before architectural or feature work, read the relevant docs in this order:

1. `AGENTS.md`
2. `CLAUDE.md` if the workflow is Claude-specific
3. `docs/Reference/ProjectRules.md` when team/project rules are requested
4. `docs/Architecture/Overview.md`
5. Task-specific docs:
   - Canonical implementation checklist: `docs/Reference/Checklists.md`
   - Network/client patterns: `docs/Guides/NetworkGuide.md`
   - Navigation: `docs/Guides/NavigationStack.md`
   - File structure: `docs/Reference/FileOrganization.md`
   - Naming/style: `docs/Reference/NamingConventions.md`
   - Project/team rules: `docs/Reference/ProjectRules.md`
   - TCA onboarding/tutorial only: `docs/QuickStart.md`

If a referenced doc is missing, ask before assuming its contents.

---

## Architecture guardrails

### Feature structure

General Feature modules should follow Interface/Sources separation:

```text
Projects/Feature/{Feature}/
├── Interface/Sources/
└── Sources/
```

Interface layer is the public boundary. Consumers should generally depend on Interface modules, not implementation Sources. Interface typically contains public API/contracts:

- public Reducer type
- public State and Action
- Client definitions if needed
- ViewFactory/factory definitions if needed
- `DependencyValues` extensions
- `TestDependencyKey` conformance where appropriate

Sources layer hides implementation details. Sources typically contains implementation:

- default Reducer initializer
- reducer logic
- internal SwiftUI View
- live dependency implementations
- linker/static-library support if required by the project pattern

### Exception features

The following are documented as exception features:

- Auth
- Onboarding
- MainTab

They may be directly composed by App or coordinator/root features and are not always forced through the same Interface/ViewFactory constraints as ordinary feature modules.

### TCA rules

- Use `@Reducer` for reducers.
- Use `@ObservableState` for state.
- State should conform to `Equatable`.
- Keep TCA nested `State` and `Action` with their Reducer.
- Model actions as events, not commands.
- Use `@Dependency` for dependencies.
- Wrap asynchronous side effects in TCA Effects such as `.run`.
- Reducers should not directly perform side effects outside Effects/dependencies.

### Action naming

Follow documented naming conventions:

- User actions: `Tapped`, `Changed`, `Selected`
- System responses: `Response`
- Lifecycle: `onAppear`, `onDisappear`, etc.
- Delegate events: `delegate(Delegate)` when parent communication is needed

### Navigation

Use the project-wide `[Route]` array NavigationStack pattern documented in `docs/Guides/NavigationStack.md`.

Do not introduce TCA's official `StackState<Path.State>` + `@Reducer enum Path` pattern unless the architecture docs are explicitly changed first. The project currently documents that this pattern does not fit the Interface/Implementation split.

### Network clients

For feature dependencies, prefer struct-based TCA Clients documented in `docs/Guides/NetworkGuide.md`.

Protocol-based clients are allowed only when an existing Core protocol, platform abstraction, legacy integration, or explicit documentation requires them.

### Token access

Token access must be mediated by the current `TokenManager` pattern.

Current codebase evidence:

- `TokenManager`: `Projects/Domain/Auth/Interface/Sources/TokenManager.swift` (`DomainAuthInterface`, `public actor TokenManager`, `DependencyValues.tokenManager`)
- Token storage interface: `Projects/Core/Storage/Interface/Sources/TokenStorageProtocol.swift` (`CoreStorageInterface`, `TokenStorageProtocol`, `TokenStorageClient`, `DependencyValues.tokenStorage`)
- Keychain implementation: `Projects/Core/Storage/Sources/KeychainTokenStorage.swift` (`CoreStorage`)
- Current auth header pattern: `Projects/Domain/Auth/Sources/AuthInterceptor.swift` uses `TokenManager`
- Current App/root wiring: `Projects/App/Sources/View/TwixApp.swift` configures the live token storage dependency

Do not read/write token persistence directly from Features, Reducers, Views, ordinary Clients, or request-building code. Do not use `@Dependency(\.tokenStorage)`, `TokenStorageClient`, `TokenStorageProtocol`, `KeychainTokenStorage`, Keychain, or UserDefaults directly for token access outside the allowed exceptions.

Allowed direct TokenStorage usage is limited to TokenManager internals, Core Storage interface/implementation, App/root dependency wiring, tests/mocks, and approved auth infrastructure that depends on `TokenManager` rather than `TokenStorage` directly. Do not introduce another token/header path without owner approval.

---

## Implementation quality gate

Before non-trivial implementation, verify that the planned structure is not only compliant with documented team architecture, but also clean, maintainable, and appropriate for the change.

Check architecture fit before writing code:

- Clean Architecture boundaries are preserved.
- Interface/Implementation split is respected where applicable.
- Dependency direction remains correct; higher-level modules must not depend on lower-level implementation details in the wrong direction.
- New code is placed in the correct module, feature, layer, and target.
- TCA `State`, `Action`, and `Reducer` ownership is clear and belongs to the feature that owns the behavior.
- Side effects go through dependencies and TCA Effects, not directly through views or reducers.
- Public API is minimal; expose only what other modules actually need.
- Coupling is not increased unnecessarily between features, domains, clients, factories, routes, or models.
- Existing clients, factories, routes, models, and dependency keys are reused when appropriate; do not create duplicates for the same responsibility.
- The change does not create avoidable future refactoring cost, such as temporary abstractions becoming public contracts or feature-specific logic leaking into shared layers.

Stop and ask before introducing:

- new architectural patterns
- new module-boundary exceptions
- new global clients/factories/routes/models
- new shared abstractions that are not clearly required by current use cases
- changes that contradict existing docs or nearby code patterns

After implementation, summarize:

- the architecture decisions made
- why the chosen module/layer placement is appropriate
- any dependency-direction or public-API risks
- any follow-up cleanup or verification that remains

---

## File organization guardrails

Default rule:

- Prefer One Type Per File for major types.

Documented exceptions:

- Keep TCA `State` and `Action` nested inside the Reducer.
- Keep private helper types with their owner.
- Keep very small helper types with their owner when splitting would reduce cohesion.
- Preserve access levels and module boundaries when moving code.

Interface-specific rule:

- Interface modules are public boundaries, but still prefer One Type Per File for new or significantly modified Interface modules.
- Existing `Interface/Sources/Source.swift` files may remain as legacy/compatibility patterns.
- Follow nearby existing code patterns unless they weaken the public boundary or make the public API unclear.

---

## Build and verification

Tuist is canonical for setup/generation:

```bash
tuist install
tuist generate
tuist clean
```

Use `tuist clean` only when regeneration cleanup is needed. `tuist build` is not the standard command.

CI/PR-level verification uses Fastlane:

```bash
bundle exec fastlane ios ci_pr
```

Use `fastlane ios ci_pr` only when Bundler is not available. If a repo-local command documents a shorter `fastlane ci_pr` convention, follow that documented convention; otherwise prefer the Bundler command above.

Do not invent direct `xcodebuild` scheme, destination, or configuration values. Direct `xcodebuild` may be used only when scheme, destination, and configuration are explicitly documented or provided for a direct-xcodebuild-specific task. If verification cannot be run, report the verification limit.

### Testing

Tests are not currently established as a normal requirement.

- Do not create tests unless explicitly requested.
- Do not claim tests were run if no test target or command exists.
- For risky logic changes, propose a test plan.
- Report verification limits caused by missing tests or missing commands.

---

## Editing policy

- Do not edit files until the requested scope is clear.
- Prefer minimal diffs over rewrites.
- Do not rewrite unrelated sections.
- Verify feasibility before modifying architecture documents.
- Keep public interfaces stable unless the user explicitly requests breaking changes.
- Do not delete legacy documents unless explicitly approved.
- Do not create Pi skills or Pi extensions unless explicitly requested.

---

## Known documentation issues / unresolved items

These issues are known from the current docs. Do not silently fix them unless asked.

Intentional docs cleanup decisions: `Rules.md` was migrated into `docs/Reference/ProjectRules.md` and deleted; `Prompt.md` was replaced by Pi skills/workflows and deleted; `docs/Checklists.md` was replaced by `docs/Reference/Checklists.md` and deleted. This was owner-approved for that cleanup only; future legacy document deletions still require explicit approval.

- Direct `xcodebuild` values are intentionally not documented as the normal verification path; ask if a direct-xcodebuild-specific task requires them.
- SwiftLint follows the Tuist-configured script documented in `docs/Reference/ProjectRules.md`.
- Some existing documentation references may still point to docs that are not currently present.

When these affect a task, ask for confirmation before proceeding.
