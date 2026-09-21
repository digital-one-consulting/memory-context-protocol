# Security

## What this software touches

The hooks read files inside the project directory and the harness's transcript directory for
that project, write two local files (`.claude/session-state.md` via the agent, and
`.claude/hooks/.session-baseline`), and remove git worktrees under `.claude/worktrees/` whose
branch is fully merged into the base branch and which are not locked. They run with the
permissions of the user who starts the session. They make no network requests.

Text the hooks print is injected into the agent's context. Anything that can write to
`memory/MEMORY.md` or `.claude/session-state.md` in a repository can therefore place text in
front of the agent at session start — the same trust boundary as `CLAUDE.md` itself. Treat
those files as you treat the repository's code: reviewed on the way in.

## Reporting

Report a vulnerability privately through GitHub's security advisory form for this repository
(Security → Report a vulnerability), or by email to foundation@digital1.foundation. Please do
not open a public issue for a security report. You will receive an acknowledgement within five
working days.

## Supported versions

The latest minor release receives fixes.
