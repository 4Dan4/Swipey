---
name: maintain-project-docs
description: Keep Swipey project documentation synchronized with the repository. Use for every task in the Swipey repository that inspects, changes, adds, removes, refactors, fixes, builds, configures, or documents application code, tests, dependencies, product behavior, architecture, build settings, or developer workflow. Read the project Markdown context before acting and update it whenever repository facts or decisions change.
---

# Maintain Swipey Documentation

Treat documentation maintenance as part of completing every Swipey task.

## Before working

1. Read `/PROJECT_GUIDE.md` completely.
2. Read `/README.md` completely when the task touches product goals, roadmap, setup, subscriptions, limits, or planned features.
3. Read `/AGENTS.md` for repository-wide rules.
4. Inspect the relevant source files. Treat code and project configuration as the source of truth for implemented behavior.
5. If documentation conflicts with code, call out the discrepancy and correct the documentation within the same task when edits are authorized.

Resolve paths relative to the repository root. If one of these files is missing, inspect the repository and recreate the smallest accurate replacement instead of silently skipping the documentation step.

## While working

- Keep a short list of facts affected by the task: behavior, architecture, files, data flow, dependencies, limits, permissions, setup, testing, and known constraints.
- Do not describe planned behavior as implemented behavior.
- Do not copy implementation details that provide no future navigation value.
- Preserve unrelated user edits in all Markdown files.
- Prefer updating an existing section over appending duplicate explanations.

## Before finishing a change

Compare the final diff with the documentation and update every affected section of `PROJECT_GUIDE.md`.

Update `README.md` only when its high-level overview, setup, product direction, milestones, or open decisions changed. Keep `PROJECT_GUIDE.md` as the detailed current-state source and `README.md` as the concise public overview/roadmap.

Update documentation for changes involving any of the following:

- user-visible behavior or copy;
- screens, navigation, gestures, states, or error handling;
- reducers, models, clients, managers, persistence, or data flow;
- files or module structure;
- dependencies, build settings, deployment target, permissions, or bundle metadata;
- limits, subscriptions, entitlement rules, or feature gating;
- completed roadmap items, new limitations, or resolved technical debt;
- test targets, test coverage, run commands, or verification requirements.

Do not make a meaningless Markdown edit when a task changes no documented fact. In that case, explicitly verify that no documentation update is required.

## Record the change

Maintain the `Documentation change log` section at the end of `PROJECT_GUIDE.md` for material repository changes.

- Add one concise entry per completed task, newest first.
- Use `YYYY-MM-DD — summary`.
- State what changed and which documented behavior or architecture it affected.
- Do not add entries for read-only questions, failed attempts, formatting-only documentation edits, or work not present in the final diff.
- Keep at most the latest 20 entries; older history remains available in Git.

Example:

```markdown
- 2026-07-16 — Перенесено удаление медиа в `SwipeFeature`; `SwipeView` больше не обращается к `PhotoManager` напрямую.
```

## Verify

1. Run `git diff --check`.
2. Search changed Markdown for stale values or statements affected by the task.
3. Run tests or a build appropriate to the code change.
4. Review `git diff -- PROJECT_GUIDE.md README.md AGENTS.md`.
5. In the final response, state which documentation files were updated, or state that they were reviewed and why no update was necessary.

The task is not complete while code and documentation contradict each other.
