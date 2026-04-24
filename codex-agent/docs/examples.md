# Codex Skills Usage Examples

This document provides examples of using the `/codex` and `/codex-review` skills.

> **Reference**: For CLI flags, configuration options, and troubleshooting, see [quickref.md](./quickref.md)

## `/codex` — Task Execution

### Code Generation

```
/codex create a function to parse CSV files with error handling
/codex implement a REST API endpoint for user authentication
/codex create a WebSocket server with reconnection logic
```

### Refactoring

```
/codex refactor the authentication module to use modern async patterns
/codex refactor the UserService class to follow SOLID principles
/codex convert this callback-based code to use promises
```

### Code Analysis

```
/codex analyze the codebase for potential performance bottlenecks
/codex analyze security vulnerabilities in the codebase
/codex review error handling patterns and suggest improvements
```

### Testing

```
/codex generate unit tests for the UserService class
/codex add integration tests for the API endpoints
/codex create test fixtures for the database models
```

### Bug Fixing

```
/codex fix the race condition in the connection pool
/codex debug why the authentication middleware fails on expired tokens
```

## `/codex-review` — Code Review

### Review Uncommitted Changes

```
/codex-review --uncommitted
```

Review all uncommitted changes in the working tree before committing.

### Review Against a Branch

```
/codex-review --base main
/codex-review --base develop
```

Review all changes on the current branch compared to a base branch. Useful before opening a pull request.

### Review a Specific Commit

```
/codex-review --commit abc123
/codex-review --commit HEAD~1
```

Review the changes introduced by a specific commit.

## How the Skills Work

### `/codex` Workflow

When you invoke `/codex <task>`:

1. **Gathers** context from the codebase using Read, Glob, Grep
2. **Formulates** an appropriate `codex exec` command
3. **Executes** the command with suitable flags
4. **Verifies** the results
5. **Reports** back with a summary of changes

### `/codex-review` Workflow

When you invoke `/codex-review <flags>`:

1. **Runs** `codex review` with the provided flags
2. **Presents** review findings (issues, suggestions, observations)

The review runs in an isolated context (`context: fork`) with a read-only agent, so it won't modify any files.

## Task Types Suitable for `/codex`

- **Code generation** — Creating new functions, classes, modules
- **Refactoring** — Modernizing code, improving structure
- **Bug fixing** — Debugging and fixing issues
- **Code analysis** — Security, performance, quality reviews
- **Documentation** — Generating code comments and docs
- **Testing** — Creating test cases
- **API implementation** — Building endpoints and handlers

---

> **Customization**: See [quickref.md](./quickref.md) for configuration options, CLI flags, hooks, and troubleshooting
