#!/usr/bin/env bash
set -Eeuo pipefail

REPO="${1:-${GH_REPO:-}}"
if [[ -z "$REPO" ]]; then
  echo "Usage: $0 OWNER/REPO" >&2
  exit 2
fi

create_label() {
  local name="$1" color="$2" description="$3"
  gh label create "$name" \
    --repo "$REPO" \
    --color "$color" \
    --description "$description" \
    --force
}

create_label 'merge:auto'    '1F883D' 'Allow PR Conductor to merge this PR automatically.'
create_label 'merge:manual'  '8250DF' 'Keep merge execution manual while retaining Conductor metadata.'
create_label 'merge:hold'    'D1242F' 'Hard pause for PR Conductor merge automation.'
create_label 'merge:squash'  '0969DA' 'Force squash merge strategy.'
create_label 'merge:rebase'  '0969DA' 'Force rebase merge strategy.'
create_label 'merge:commit'  '0969DA' 'Force merge-commit strategy.'
create_label 'rebase:off'    'BF8700' 'Do not automatically rebase/update this PR or stack.'
create_label 'title:keep'    '57606A' 'Preserve the current PR title exactly.'
create_label 'conductor:off' 'D1242F' 'Disable PR Conductor entirely for this PR.'

create_label 'type:feat'     'A2EEEF' 'Feature change.'
create_label 'type:fix'      'D73A4A' 'Bug fix.'
create_label 'type:docs'     '0075CA' 'Documentation change.'
create_label 'type:refactor' 'C5DEF5' 'Refactoring change.'
create_label 'type:perf'     'BFD4F2' 'Performance change.'
create_label 'type:test'     'F9D0C4' 'Test change.'
create_label 'type:build'    'D4C5F9' 'Build-system change.'
create_label 'type:ci'       '5319E7' 'CI/workflow change.'
create_label 'type:chore'    'EDEDED' 'Maintenance change.'

echo "PR Conductor labels are ready on ${REPO}."
