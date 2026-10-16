# CLAUDE.md

## Project Overview

This document is a router. It does not hold the project overview, planning
context, or rules themselves — follow the references below.

Flutter app for DAMSO (담소), a parent–teacher communication app. Dart package
`damso_app`, Android and iOS only. The backend lives in a separate repository
(`damsoWE/damso_server`) and owns the API contract; this app consumes `docs/api/openapi.yaml`.

## Important Note for AI Agent

As the AI Agent, you must not perform any actions or make any changes to the
codebase that have not been explicitly instructed by the user. Adhere strictly
to the user's commands and avoid proactive modifications or additions.

## References

| Target | File |
|---|---|
| Security principles (immutable, override the planning doc) | `.specify/memory/constitution.md` |
| Planning doc (reference only, may change during development) | `docs/아기하마_개발기획서.pdf` |
| IA / User Flow (original) | `docs/소개딩_IA.pdf` |
| Screen tree and screen states (text) | `docs/ia.md` |
| Design (draft) | [Figma](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=102-2) — reference by frame link (node-id) |
| API contract (copy of the backend's, pinned by tag) | `docs/api/openapi.yaml` |
| Deviations from the planning doc | backend repo `docs/decisions.md` |
| Feature specs | `specs/` — each spec names its backend counterpart spec path |

## Skill Routing

| Step | Skill |
|---|---|
| Project principles | `/speckit-constitution` |
| Feature spec (what/why only, no tech stack) | `/speckit-specify` |
| Resolve ambiguity | `/speckit-clarify` |
| Tech plan + API contracts | `/speckit-plan` |
| Task breakdown | `/speckit-tasks` |
| Cross-artifact check | `/speckit-analyze` |
| Implementation | `/speckit-implement` |

Skill definitions: `.claude/skills/speckit-*/SKILL.md`.

## Code Layout

`lib/app` (root widget, router) · `lib/core` (config, network, storage) ·
`lib/features/<feature>/{data,domain,presentation}` · `lib/mock` (mock
Repository overrides). Screens depend on `domain` interfaces; `data` holds the
real-server implementation; `lib/mock` swaps it without touching screens.

## General Rules

- Always respond in Korean.
- Do not modify files unrelated to the user's requested changes.
- Confirm before decisions with large impact, such as new permissions,
  external systems, or new packages.
- Never put secrets (API keys, tokens) in the app or in `env/*.json`.
- Do not delete files or run destructive Git commands without user approval.
- Only run git push or git commit when explicitly requested by the user.

## Git Workflow

- Start every task from a GitHub issue (template: `.github/ISSUE_TEMPLATE/`).
- Branch from `main`: `features/<feature-name>` for features, `fix/<fix-name>`
  for fixes. Link the issue to the branch (e.g. `gh issue develop <number>
  --name <branch>`).
- Never commit or push directly to `main`. Merge only through a Pull Request
  and reference the issue in it (`Closes #<number>`).
- Commit messages: `Feat : <summary>` / `Fix : <summary>` (Korean, one line,
  space on both sides of the colon).
- Do not add Claude or any AI as co-author or in attribution lines of commits
  and PR descriptions.

## Verification

Run `flutter analyze` and `flutter test`. Report failures clearly — do not hide
or bypass them.

Run the app:

```
flutter run --dart-define-from-file=env/dev.json   # real server (Android emulator: 10.0.2.2)
flutter run -t lib/main_mock.dart                  # mock Repository, no server
```

Release builds must use `--obfuscate --split-debug-info=<dir>`.
