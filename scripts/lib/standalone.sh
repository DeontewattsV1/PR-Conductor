#!/usr/bin/env bash

process_standalone() {
  local pr="$1" data="$2" title="$3" strategy="$4"
  local head_repo head_ref base_ref mergeable_state

  head_repo="$(jq -r '.head.repo.full_name // ""' <<<"$data")"
  head_ref="$(jq -r '.head.ref' <<<"$data")"
  base_ref="$(jq -r '.base.ref' <<<"$data")"
  mergeable_state="$(jq -r '.mergeable_state // "unknown"' <<<"$data")"

  if [[ "$strategy" == 'conflict' ]]; then
    upsert_comment "$pr" "$MARKER
**PR Conductor:** paused — multiple merge strategy labels are present. Keep exactly one of 'merge:squash', 'merge:rebase', or 'merge:commit'."
    return
  fi

  if [[ "$mergeable_state" == 'dirty' ]]; then
    upsert_comment "$pr" "$MARKER
**PR Conductor:** conflict detected · strategy '$strategy' · automatic merge paused until conflicts are resolved."
    return
  fi

  if bool_true "$AUTO_REBASE" \
    && [[ "$head_repo" == "$GH_REPO" ]] \
    && ! has_label 'rebase:off' \
    && [[ "$mergeable_state" == 'behind' ]]; then

    if bool_true "$DRY_RUN"; then
      upsert_comment "$pr" "$MARKER
**PR Conductor:** dry run · would rebase '$head_ref' onto '$base_ref' · strategy '$strategy'."
      return
    fi

    if gh pr update-branch "$pr" --repo "$GH_REPO" --rebase >/dev/null 2>&1; then
      upsert_comment "$pr" "$MARKER
**PR Conductor:** rebased '$head_ref' onto '$base_ref' · CI will rerun · planned merge '$strategy'."
    else
      upsert_comment "$pr" "$MARKER
**PR Conductor:** rebase could not be completed automatically · strategy '$strategy' · waiting for manual conflict resolution."
    fi
    return
  fi

  if ! should_auto_merge "$head_repo"; then
    upsert_comment "$pr" "$MARKER
**PR Conductor:** ready · mode 'standalone' · strategy '$strategy' · automatic merge is not enabled for this PR."
    return
  fi

  if bool_true "$DRY_RUN"; then
    upsert_comment "$pr" "$MARKER
**PR Conductor:** dry run · would enable auto-merge · mode 'standalone' · strategy '$strategy'."
    return
  fi

  local -a args=()
  case "$strategy" in
    squash) args+=(--squash) ;;
    rebase) args+=(--rebase) ;;
    merge) args+=(--merge) ;;
    *)
      upsert_comment "$pr" "$MARKER
**PR Conductor:** paused · unsupported strategy '$strategy'."
      return
      ;;
  esac

  local status='waiting for repository requirements'
  if gh pr merge "$pr" --repo "$GH_REPO" --auto "${args[@]}" --subject "$title" >/dev/null 2>&1; then
    status='auto-merge enabled'
  elif gh pr merge "$pr" --repo "$GH_REPO" --auto >/dev/null 2>&1; then
    status='merge queue / auto-merge enabled'
  fi

  upsert_comment "$pr" "$MARKER
**PR Conductor:** $status · mode 'standalone' · strategy '$strategy'."
}
