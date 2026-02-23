# CLAUDE.md

This file provides context and guidance for AI assistants (such as Claude) working in this repository.

## Repository Overview

**Name:** Testtemp
**Status:** New / minimal repository — no application code exists yet.

The repository currently contains only a placeholder README. This CLAUDE.md will be updated as the project evolves.

## Current Repository Structure

```
Testtemp/
├── .git/          # Git metadata
├── README.md      # Project title placeholder
└── CLAUDE.md      # This file
```

## Git Workflow

### Branches

- `master` — primary integration branch
- `claude/<description>` — branches used by AI assistants for scoped work

### Commit Conventions

Use clear, descriptive commit messages in the imperative mood:

```
Add user authentication module
Fix null pointer in data parser
Update README with setup instructions
```

### Push Instructions

Always push with upstream tracking set:

```bash
git push -u origin <branch-name>
```

Branch names for AI-assisted work must follow the pattern:
`claude/<description>-<session-id>`

## Development Setup

No build system, package manager, or runtime dependencies exist yet. When they are added, update this file with:

- Installation steps (`npm install`, `pip install -r requirements.txt`, etc.)
- How to run the project locally
- Environment variable requirements (`.env.example` contents)

## Testing

No test framework is configured yet. When tests are added, document here:

- How to run the full test suite
- How to run a single test file
- Coverage requirements or thresholds

## Linting / Formatting

No linter or formatter is configured yet. When one is added, document the command to run it (e.g., `eslint .`, `black .`, `golangci-lint run`).

## Key Conventions for AI Assistants

- **Read before modifying.** Always read a file before editing it.
- **Minimal changes.** Only change what is necessary for the task at hand; avoid refactoring unrelated code.
- **No speculative features.** Do not add error handling, abstractions, or flexibility beyond what the current task requires.
- **No commented-out code.** Delete unused code rather than commenting it out.
- **No new files without clear need.** Prefer editing existing files; only create new files when the task explicitly requires it.
- **No documentation files unless asked.** Do not create additional `.md` files or docstrings unless explicitly requested.
- **Commit and push when done.** After completing an implementation task, commit with a descriptive message and push to the designated branch.
- **Update this file** when the project structure, dependencies, or workflows change significantly.
