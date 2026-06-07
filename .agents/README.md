# Project Agent Skills

This directory contains agent skills that are local to the Swipey project.

## Skills

- `app-store-changelog`: Generate App Store release notes from git history since the last tag or a specified ref.
- `bug-hunt-swarm`: Run a parallel read-only bug investigation to rank likely root causes and fastest proof paths.
- `composable-architecture`: TCA guidance for reducer structure, dependencies, effects, navigation, SwiftUI bindings, performance, and testing.
- `github`: Use the `gh` CLI for GitHub issues, pull requests, workflow runs, and API queries.
- `ios-debugger-agent`: Build, run, and debug the app on a booted iOS simulator via XcodeBuildMCP tools.
- `orchestrate-batch-refactor`: Plan and coordinate larger refactors with dependency-aware parallel analysis.
- `project-skill-audit`: Audit project history and local skills to recommend high-value new or updated skills.
- `react-component-performance`: Analyze slow React components and reduce render churn or expensive UI work.
- `review-and-simplify-changes`: Review diffs for quality, reuse, and clarity issues, then optionally apply safe simplifications.
- `review-swarm`: Run a parallel read-only diff review for regressions, risks, and testing gaps.
- `swift-concurrency-expert`: Swift 6.2+ concurrency review and remediation guidance.
- `swiftui-liquid-glass`: iOS 26+ Liquid Glass implementation and review guidance.
- `swiftui-performance-audit`: SwiftUI performance audit guidance for render churn, layout thrash, and profiling.
- `swiftui-ui-patterns`: SwiftUI view and app-structure patterns for screens, navigation, sheets, and async UI state.
- `swiftui-view-refactor`: SwiftUI refactoring guidance for smaller views, explicit data flow, and Observation usage.

## Source

The `composable-architecture` skill is vendored from:

https://github.com/johnrogers/claude-swift-engineering/tree/main/plugins/swift-engineering/skills/composable-architecture

The upstream project is MIT licensed. A copy of the license is included in the skill directory.

The following skills are vendored from:

https://github.com/Dimillian/Skills

- `app-store-changelog`
- `bug-hunt-swarm`
- `github`
- `ios-debugger-agent`
- `orchestrate-batch-refactor`
- `project-skill-audit`
- `react-component-performance`
- `review-and-simplify-changes`
- `review-swarm`
- `swift-concurrency-expert`
- `swiftui-liquid-glass`
- `swiftui-performance-audit`
- `swiftui-ui-patterns`
- `swiftui-view-refactor`

The upstream project is MIT licensed. A copy of the license is included at `.agents/skills/LICENSE.dimillian`.

## Notes

- `ios-debugger-agent` expects XcodeBuildMCP tools to be available in the active Codex session.
- The upstream `docs/` and `scripts/` folders are support content, not standalone local skills, so they were not vendored into `.agents/skills`.
- The upstream `macos-menubar-tuist-app` and `macos-spm-app-packaging` skills were intentionally excluded per scope.
