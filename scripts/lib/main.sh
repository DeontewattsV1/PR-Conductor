#!/usr/bin/env bash

process_pr() {
  local pr="$1"
  local sweep_mode="$2"

  [[ -n "$pr" && "$pr" != 'null' ]] || return

  echo "::group::PR #$pr"

  local data state draft title head_ref head_repo commits stack_present
  local strategy normalized_title default_branch

  data="$(api "repos/$GH_REPO/pulls/$pr" 2>/dev/null || true)"

  if [[ -z "$data" ]]; then
    warn "Unable to read PR #$pr."
    echo '::endgroup::'
    return
  fi

  state="$(jq -r '.state' <<<"$data")"
  if [[ "$state" != 'open' ]]; then
    log "PR #$pr is not open."
    echo '::endgroup::'
    return
  fi

  draft="$(jq -r '.draft // false' <<<"$data")"
  title="$(jq -r '.title' <<<"$data")"
  head_ref="$(jq -r '.head.ref' <<<"$data")"
  head_repo="$(jq -r '.head.repo.full_name // ""' <<<"$data")"
  commits="$(jq -r '.commits // 1' <<<"$data")"
  stack_present="$(jq -r 'if .stack == null then "false" else "true" end' <<<"$data")"
  default_branch="$(api "repos/$GH_REPO" --jq '.default_branch')"

  load_labels "$data"

  if has_label 'conductor:off'; then
    log "PR #$pr has conductor:off."
    echo '::endgroup::'
    return
  fi

  # pull_request runs from forks have a restricted token. The scheduled trusted
  # sweep can later update metadata; fork auto-merge still requires merge:auto
  # unless AUTO_MERGE_MODE=all.
  if [[ "$EVENT_NAME" == 'pull_request' && "$head_repo" != "$GH_REPO" ]]; then
    log "Fork PR #$pr: deferring write operations to trusted sweep."
    echo '::endgroup::'
    return
  fi

  normalized_title="$(normalize_pr_title "$pr" "$title" "$head_ref")"
  strategy="$(choose_strategy "$head_ref" "$commits")"

  if [[ "$draft" == 'true' ]]; then
    upsert_comment "$pr" "$MARKER
**PR Conductor:** draft detected · planned strategy `$strategy` · merge paused until the PR is ready for review."
    echo '::endgroup::'
    return
  fi

  if has_label 'merge:hold'; then
    upsert_comment "$pr" "$MARKER
**PR Conductor:** `merge:hold` is active · no merge action taken."
    echo '::endgroup::'
    return
  fi

  if has_label 'merge:manual'; then
    upsert_comment "$pr" "$MARKER
**PR Conductor:** manual merge requested · strategy `$strategy` · automation will not merge this PR."
    echo '::endgroup::'
    return
  fi

  if [[ "$stack_present" == 'true' ]]; then
    process_stack "$pr" "$data" "$strategy" "$default_branch" "$sweep_mode"
  else
    process_standalone "$pr" "$data" "$normalized_title" "$strategy"
  fi

  echo '::endgroup::'
}

prc_main() {
  case "${AUTO_MERGE_MODE,,}" in
    all|same-repo|same_repo|same_repo_only|labeled|labelled|label-only|label_only|off|false|none) ;;
    *) warn "AUTO_MERGE_MODE '$AUTO_MERGE_MODE' is not recognized." ;;
  esac

  if [[ "$TARGET_PR" =~ ^[0-9]+$ ]] && (( TARGET_PR > 0 )); then
    process_pr "$TARGET_PR" false
    return
  fi

  local -a open_prs=()
  mapfile -t open_prs < <(
    gh pr list --repo "$GH_REPO" --state open --limit 100 --json number --jq '.[].number'
  )

  local pr
  for pr in "${open_prs[@]:-}"; do
    process_pr "$pr" true
  done
}
