# Security Policy

PR Conductor is designed around one boundary: **automation may coordinate repository policy, but it must not become a bypass around repository policy.**

## Security properties

- No `--admin` merge bypass.
- The privileged workflow checks out only the trusted default branch.
- Pull-request code is not executed by PR Conductor.
- Fork PR event runs do not perform write operations.
- Stacked branch rewrites use the official `github/gh-stack` workflow and lease protection.
- Merge/rebase conflicts pause automation.
- `merge:hold`, `merge:manual`, `rebase:off`, and `conductor:off` provide explicit human control points.

## Recommended deployment

Protect the default branch with required checks/reviews before enabling `auto_merge_mode: all` or `same-repo` in a repository where many people can create same-repository branches.

For shared production use, pin PR Conductor to an immutable release tag or commit SHA.
