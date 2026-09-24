# PR Conductor v2

**PR Conductor** is a reusable GitHub Actions control plane for pull requests. It normalizes PR titles, keeps branches current, selects an appropriate merge strategy, maintains one small status comment, supports merge queues, and understands GitHub Stacked Pull Requests.

> The workflow is deliberately metadata-first. It checks out the repository's trusted default branch and never executes code from a pull request.

## What it does

| Situation | Default action |
|---|---|
| Draft PR | Normalize title, comment, wait |
| 1-commit ordinary PR | Rebase merge |
| Multi-commit ordinary PR | Squash merge |
| `release/*` / `hotfix/*` | Merge commit |
| Branch behind base | `gh pr update-branch --rebase` |
| GitHub stacked PR | `gh stack sync` then `gh stack merge` |
| Merge queue | Let GitHub's queue select/execute the merge method |
| Conflict | Pause and update the PR status comment |
| Fork PR | Event run stays read-only; trusted sweep handles metadata; automatic merge requires `merge:auto` by default |

Repository rules, required checks, CODEOWNERS, approvals, and merge queues remain authoritative. PR Conductor never uses `--admin` to bypass them.

If repository-level auto-merge is disabled, PR Conductor can fall back to an ordinary protected `gh pr merge` once the PR is eligible. The fallback still respects required checks, reviews, rulesets, and branch protection because it never uses `--admin`.

## Fastest installation

Create this file in any repository:

`.github/workflows/pr-conductor.yml`

```yaml
name: PR Conductor

on:
  pull_request:
    types:
      - opened
      - reopened
      - synchronize
      - ready_for_review
      - converted_to_draft
      - labeled
      - unlabeled
      - edited
  schedule:
    - cron: "*/10 * * * *"
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write
  issues: write

concurrency:
  group: pr-conductor-${{ github.repository }}
  cancel-in-progress: false

jobs:
  conduct:
    uses: DeontewattsV1/PR-Conductor/.github/workflows/reusable.yml@v2
    with:
      pr_number: ${{ github.event.pull_request.number || 0 }}
      auto_merge_mode: same-repo
      auto_rebase: true
      stack_sync: true
      normalize_titles: true
      comments: true
      default_single_strategy: rebase
      default_multi_strategy: squash
      release_strategy: merge
```

For a repository that cannot call reusable workflows, use `examples/direct-action.yml`. For a one-file copy/paste installation that calls the versioned action directly, use `examples/standalone.yml`.

## One-time repository setup

Enable the merge methods PR Conductor may select and allow auto-merge:

```bash
gh repo edit OWNER/REPO \
  --enable-auto-merge \
  --enable-squash-merge \
  --enable-rebase-merge \
  --enable-merge-commit \
  --allow-update-branch \
  --delete-branch-on-merge
```

Then create the control labels:

```bash
./scripts/create-labels.sh OWNER/REPO
```

## Control labels

| Label | Meaning |
|---|---|
| `merge:auto` | Explicitly allow automatic merge. Also overrides the default fork restriction. |
| `merge:manual` | Keep merge execution manual. |
| `merge:hold` | Hard pause. |
| `merge:squash` | Force squash merge. |
| `merge:rebase` | Force rebase merge. |
| `merge:commit` | Force merge commit. |
| `rebase:off` | Never automatically rewrite/update the branch or stack. |
| `title:keep` | Preserve the title exactly. |
| `conductor:off` | Opt out completely. |
| `type:*` | Conventional-title type override. |
| `scope:*` | Optional Conventional-title scope, e.g. `scope:runtime`. |

Only one merge strategy label should be present. If multiple are found, the conductor pauses instead of guessing. If stacked PRs included in one merge request specify conflicting methods, the whole stack merge is paused.

## Title behavior

Existing Conventional Commit-style titles are preserved unless `type:*` or `scope:*` explicitly requests a rewrite.

Examples:

```text
Add macOS compatibility gate
+ type:ci
+ scope:private-shield

→ ci(private-shield): Add macOS compatibility gate
```

```text
feat: add token broker

→ feat: add token broker
```

Use `title:keep` to opt out.

## Small status comment

PR Conductor maintains a single comment instead of posting a new message on every run:

```text
PR Conductor: auto-merge enabled · mode standalone · strategy squash.
```

For a stack:

```text
PR Conductor: stack #7 cascade-rebased and pushed with lease protection · CI will rerun · planned merge squash.
```

## Automatic policy

Without an explicit merge-method label:

```text
1 commit                  -> rebase
2+ commits                -> squash
release/* or hotfix/*     -> merge commit
```

Explicit labels always override this policy.

## Auto-merge modes

`auto_merge_mode` accepts:

- `same-repo` — recommended default. Automatically conduct PRs whose head branch lives in the same repository. Fork PRs require `merge:auto`.
- `labeled` — only PRs carrying `merge:auto` are merged.
- `all` — allow every eligible PR, including fork PRs, to enter merge automation.
- `off` — title/rebase/comment automation only; no automatic merge.

`same-repo` is the default because a public reusable workflow should not silently turn an unprotected public repository into an auto-accept bot for arbitrary forks.

## Stacked PRs

GitHub's stacked PR feature exposes stack membership through the pull request payload/API. PR Conductor uses that metadata instead of inferring a stack from branch names.

For stack maintenance it installs the official GitHub extension:

```bash
gh extension install github/gh-stack
```

The automated stack path is:

```text
stack detected
  -> validate drafts/holds/strategy labels
  -> gh stack checkout <PR>
  -> gh stack sync
       fetch
       reconcile
       cascade rebase if needed
       push using lease protection
       sync PR/stack state
  -> if SHA changed: wait for CI to rerun
  -> gh stack merge <PR> --yes --<strategy>
```

`gh stack push`/sync use lease-protected rewriting rather than an unconditional force push. If a stack diverges or develops a rebase conflict, the extension aborts rather than inventing a resolution.

GitHub currently does not provide ordinary auto-merge semantics for stacked PR merges. PR Conductor therefore retries waiting stacks through the scheduled sweep; when the requirements are actually satisfied, the stack merge succeeds or enters the configured merge queue.

Stacked Pull Requests are currently a GitHub public-preview feature, so this integration should be versioned and tested when GitHub changes the preview APIs.

## Security model

PR Conductor intentionally does **not**:

- run PR code with a write token
- use `pull_request_target` to execute fork content
- use `--admin`
- resolve merge conflicts by guessing
- use plain `git push --force`
- override branch protection, CODEOWNERS, required checks, or merge queues

The privileged workflow checks out only the repository's trusted default branch. Fork PR event runs defer writes to the scheduled trusted sweep.

## Dry run

The reusable workflow supports `dry_run: true`.

For a direct action call:

```yaml
- uses: DeontewattsV1/PR-Conductor@v2
  with:
    pr-number: ${{ github.event.pull_request.number || 0 }}
    dry-run: true
```

Use dry-run when rolling PR Conductor into an existing high-volume repository.

## Reusable organization pattern

An organization can place a tiny caller in every repository while keeping policy in this versioned central workflow. Pin production repositories to a release tag or full commit SHA rather than `main`.

```text
org/repo-a ─┐
org/repo-b ─┼──> DeontewattsV1/PR-Conductor@v2
org/repo-c ─┘        │
                     ├── title policy
                     ├── rebase policy
                     ├── merge policy
                     ├── stack policy
                     └── status comments
```

## Versioning

The repository publishes a moving major-version branch named `v2` from validated `main`.

Consumers can reference:

```yaml
uses: DeontewattsV1/PR-Conductor/.github/workflows/reusable.yml@v2
```

For stronger supply-chain pinning, reference a full commit SHA. When cutting a formal GitHub release, add an immutable version tag such as `v2.0.0`.

## Profile snippet

```md
### PR Conductor
Policy-driven GitHub PR automation for titles, rebase, squash/rebase/merge strategy selection, merge queues, and native stacked PRs — without bypassing repository protections.

[View PR Conductor](https://github.com/DeontewattsV1/PR-Conductor)
```

## Requirements

- GitHub Actions
- GitHub CLI (`gh`) — included on GitHub-hosted Ubuntu runners
- `jq` — included on GitHub-hosted Ubuntu runners
- GitHub Stacked PR support for stack-specific features
- Appropriate repository Actions/token permissions
- `action.yml` must remain at the repository root for direct `uses: DeontewattsV1/PR-Conductor@...` calls

## Upstream references

- GitHub Stacked Pull Requests: https://docs.github.com/en/pull-requests/reference/stacked-pull-requests
- Stacked PR APIs: https://docs.github.com/en/pull-requests/reference/stacked-pull-requests-apis-and-webhooks
- Stacks REST API: https://docs.github.com/en/rest/pulls/stacks
- `github/gh-stack`: https://github.com/github/gh-stack
- `gh pr merge`: https://cli.github.com/manual/gh_pr_merge
- `gh pr update-branch`: https://cli.github.com/manual/gh_pr_update-branch

## License

MIT. See `LICENSE`.
