# CLAUDE.md

Guidelines for how Claude should approach development in this codebase.

---

## Scope & PR Discipline

- Target ~15 files changed per session. If the natural scope exceeds this, flag it and suggest splitting the work before writing any code.
- Before writing code, list the files you expect to touch. If the list feels large, say so.
- Features are product concepts — break them into independently mergeable engineering units. Each session should target one unit.
- Refactors and feature work should not be mixed. If you spot something worth refactoring while implementing a feature, note it in a comment (`# TODO: refactor candidate — <reason>`) and move on.
- Aim for the smallest change that moves the codebase to a valid, non-broken state.

---

## Module Design (after Ousterhout)

- **Prefer deep modules over shallow ones.** A module should hide significant complexity behind a simple interface. Avoid splitting logic into many small functions or classes just for the sake of it — each abstraction should earn its existence.
- **Different layer, different abstraction.** Each layer (e.g. repository, service, route) should have its own vocabulary. Don't pass raw DB models up to the API layer, and don't leak HTTP concepts down into business logic.
- **Define errors out of existence where possible.** Prefer designs that make invalid states unrepresentable over scattered defensive checks. When errors must exist, handle them at the right layer — not everywhere.
- **General-purpose over special-purpose.** When writing a module, ask whether a slightly more general version would serve multiple use cases without added complexity. Avoid one-off abstractions.

---

## Comments & Documentation

- Comments should explain _why_, not _what_. The code says what; the comment explains the reasoning, tradeoffs, or constraints that aren't obvious from reading it.
- Don't comment things that are self-evident from the code.
- Document interfaces, not implementations. A function's docstring should describe its contract — inputs, outputs, side effects — not narrate the body.

---

## Testing

- Tests are part of the implementation, not an afterthought. Write them in the same session unless explicitly told otherwise.
- **Test behaviour, not implementation.** Tests should assert on inputs and outputs, not on how the internals work. If refactoring breaks a test without changing observable behaviour, the test was wrong.
- **Test at the right layer.** Unit test pure logic. Integration test repositories and API routes. Don't write integration tests for things trivially covered by unit tests, and vice versa.
- One test file per module. Keep test structure parallel to source structure.
- Prefer real objects over mocks where it's not expensive. Mock at boundaries — external APIs, third-party services, the filesystem — not between internal layers.
- Each test should have one reason to fail. Avoid asserting on multiple unrelated behaviours in a single test.
- Tests should be readable as documentation. A test name should describe the scenario and expected outcome: `test_create_user_returns_409_when_email_already_exists`, not `test_create_user_error`.

### Stack: Fill per project

> Add stack-specific conventions here — test runner, directory layout, fixture strategy, CI integration, coverage thresholds.

---

## Error Handling

- **Handle errors at the right layer, not everywhere.** Repositories surface DB exceptions. Services translate them into domain errors. Routes translate domain errors into HTTP responses. Don't catch and re-raise through every layer.
- Prefer domain-specific exceptions over generic ones. `UserNotFoundError` is more useful than `ValueError("user not found")`.
- Use a single app-level error handler for consistent HTTP error shaping. Don't write `try/except` blocks in route handlers unless the handling is genuinely route-specific.
- Never expose internal error details (stack traces, DB messages) in API responses. Log them server-side; return a clean, structured error shape to the client.
- Distinguish between expected errors (user input, not found, conflict) and unexpected errors (infra failure, unhandled exception). Handle them differently — expected errors are part of the domain, unexpected errors should alert.

---

## Naming

- Names should be precise enough that a reader doesn't need to look at the implementation to understand the intent. If you find yourself writing a comment to explain what a variable holds, the name is probably wrong.
- Avoid generic names: `data`, `result`, `info`, `handler`, `manager`, `util`. Name things by what they specifically represent.
- Functions should be named for what they return or what they do — not how they do it. `get_active_users()` over `query_users_with_active_flag()`.
- Boolean variables and functions should read as assertions: `is_expired`, `has_permission`, `can_publish` — not `check_expiry` or `expiry_status`.
- Be consistent with the codebase's existing vocabulary. If the codebase calls it a `policy`, don't introduce `rule` or `regulation` for the same concept.
- When a name feels hard to choose, that's often a signal the abstraction itself isn't clear yet. Pause and reconsider the design before forcing a name.

---

## Git Commit Granularity

- Commit messages should complete the sentence: _"This commit will..."_ — e.g. `add user authentication middleware`, not `auth stuff` or `wip`.
- Don't bundle a refactor and a feature in the same commit. If a refactor was necessary to enable a feature, commit the refactor first, then the feature.
- Avoid committing commented-out code, debug logs, or `print` statements.
- If a session produces work that spans multiple logical changes, flag it and suggest how to split the commits before finishing.

---

## General

- When in doubt between two approaches, briefly note the tradeoff and your reasoning before implementing. Don't just pick one silently.
- Consistency with existing patterns in the codebase takes precedence over personal preference.
- Don't introduce a new dependency without flagging it. Prefer solving problems with what's already in the stack.

---

## Worktree Setup

After `git worktree add`, bootstrap both environments before writing any code or starting dev servers:

- **Backend:** install dependencies and create a local virtual environment so the language server and type checker discover the correct environment. Without this, type checking and import resolution will fail in the worktree.
- **Frontend:** install node dependencies. Dev server scripts typically do not install dependencies automatically — if you skip this step, the server will fail to start.

> Fill in the exact commands for this project's toolchain (e.g. `uv sync`, `bun install`, `npm ci`, `pip install -r requirements.txt`).

---

## Worktree Dev Servers

Each worktree should have scripts that start the backend and frontend dev servers independently. The pattern to follow:

- Scripts start their process in the background and poll until the server is ready, then exit and print the local URL.
- A separate teardown script stops all processes and cleans up any generated state (ports file, volumes, etc.).
- **For Claude Code:** start the backend script first and wait for it to print the URL, then start the frontend script and wait for its URL. Report both to the user. No need to run them as background tasks — the scripts handle that internally.

> Fill in the actual script names and any port/config file conventions for this project.

---

## Pre-PR Checklist

Before creating or pushing to a PR branch, run lint and format checks locally so CI doesn't fail on avoidable issues.

If either step reports errors, fix them and add a commit before pushing. Don't suppress linter rules — fix the underlying issue.

---

## Stack

> Fill in per project — backend framework, frontend framework, database, test runner, package manager, deployment target.

---

## Proposed Updates

If you encounter a pattern, decision, or constraint that isn't covered above
and is likely to recur, add it here as a candidate rather than modifying
existing sections directly. Flag it to the developer for review before it
becomes a standing rule.
