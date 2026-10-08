# Agent Operating Contract

## Authority order

For work in this repository, follow this order of authority:

1. The user's current task and explicit constraints, subject to the non-bypassable repository gates below.
2. Required tests, CI, security, and release policies.
3. Repository-local instructions and architecture documentation.

User instructions govern task scope and merge decisions, but they do not authorize bypassing required repository gates.

## Review verification

Verify findings against current evidence before changing code. After each change, run the repository-required verification, including applicable tests, builds, lint, type checks, security, and evidence checks; report any unavailable or failing gate. Never weaken tests, security controls, lint, type checks, or required review gates. Resolve review threads only when their findings are fixed, already fixed, or verified false positive.

## Git and pull requests

Keep changes scoped and commits logically grouped. In PR mode, push only the intended working branch. Resolve review threads only after the issue is fixed, verified as already fixed, or verified as a false positive.

Do not merge a pull request unless the user explicitly authorizes that action for the current task. Never rewrite protected history or bypass required checks.

## Tool availability

PR workflows require authenticated GitHub tooling and a local checkout. Report unavailable verification capabilities; never fabricate results.
