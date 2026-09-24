# Changelog

## 2.0.0

- Added native GitHub Stacked Pull Request detection via stack metadata/API.
- Added official `github/gh-stack` sync/rebase/merge path.
- Added repository-wide concurrency to avoid overlapping stack rewrites.
- Added strategy labels and stack strategy-conflict detection.
- Added fork-aware `same-repo` default merge mode.
- Added Conventional Commit PR title normalization with `type:*`, `scope:*`, and `title:keep`.
- Added a single upserted PR status comment.
- Added dry-run mode.
- Added reusable workflow, composite action, direct-action example, and self-contained standalone workflow.
- Added protected immediate-merge fallback when repository-level auto-merge is unavailable.
- Added explicit root `action.yml` integrity validation to prevent broken Action relocations.
- Live canary validated the real `@v2` merge path before release.
