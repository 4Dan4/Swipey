# Swipey agent instructions

## Mandatory project context

For every task in this repository, use the project-local `maintain-project-docs` skill located at `.agents/skills/maintain-project-docs/SKILL.md`.

Before inspecting or changing implementation:

1. Read `PROJECT_GUIDE.md` completely.
2. Read `README.md` when the task touches product behavior, roadmap, setup, subscriptions, limits, or planned functionality.
3. Follow the workflow in the skill.

For every code, configuration, architecture, behavior, dependency, build, test, or workflow change, review the documentation before finishing and update it in the same task when repository facts changed. Add a concise entry to the `Documentation change log` in `PROJECT_GUIDE.md` for material completed changes.

Do not make artificial documentation edits when no documented fact changed. In that case, explicitly report that the documentation was reviewed and remains accurate.

Code and project configuration are the source of truth for implemented behavior. Keep planned work clearly separated from implemented functionality.
