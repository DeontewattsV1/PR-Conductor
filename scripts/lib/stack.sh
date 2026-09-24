#!/usr/bin/env bash

ensure_stack_extension() {
  [[ "$STACK_EXTENSION_READY" == true ]] && return 0

  if gh stack --help >/dev/null 2>&1; then
    STACK_EXTENSION_READY=true
    return 0
  fi

  log 'Installing official github/gh-stack extension.'
  if ! gh extension install github/gh-stack; then
    warn 'Unable to install github/gh-stack.'
    return 1
  fi

  STACK_EXTENSION_READY=true
}

reset_worktree() {
  local default_branch="$1"

  # The runner is ephemeral. This resets only the automation checkout.
  gh stack unstack --local >/dev/null 2>&1 || true
  git rebase --abort >/dev/null 2>&1 || true
  git checkout -f "$default_branch" >/dev/null 2>&1 || true
  git fetch origin "$default_branch" --quiet >/dev/null 2>&1 || true
  git reset --hard "origin/$default_branch" >/dev/null 2>&1 || true
}

get_stack_object() {
  local pr="$1"
  api "repos/$GH_REPO/stacks?pull_request=$pr&per_page=1" 2>/dev/null |
    jq '.[0] // empty'
}

stack_top_open_pr() {
  local stack_json="$1"
  jq -r '[.pull_requests[] | select(.state == "open")] | last | .number // empty' <<<"$stack_json"
}

stack_strategy_and_guards() {
  local stack_json="$1"
  local fallback_strategy="$2"
  local -a members=()
  local -a member_labels=()

  mapfile -t members < <(
    jq -r '.pull_requests[] | select(.state == "open") | .number' <<<"$stack_json"
  )

  if (( ${#members[@]} == 0 )); then
    printf 'error|stack has no open pull requests'
    return
  fi

  local selected=""
  local member member_json member_state member_draft member_strategy

  for member in "${members[@]}"; do
    member_json="$(api "repos/$GH_REPO/pulls/$member")"
    member_state="$(jq -r '.state' <<<"$member_json")"
    member_draft="$(jq -r '.draft // false' <<<"$member_json")"

    [[ "$member_state" == 'open' ]] || continue

    if [[ "$member_draft" == 'true' ]]; then
      printf 'blocked|PR #%s is still a draft' "$member"
      return
    fi

    mapfile -t member_labels < <(jq -r '.labels[]?.name' <<<"$member_json")
    LABELS=("${member_labels[@]:-}")

    if has_label 'conductor:off'; then
      printf 'blocked|PR #%s has conductor:off' "$member"
      return
    fi
    if has_label 'merge:hold'; then
      printf 'blocked|PR #%s has merge:hold' "$member"
      return
    fi
    if has_label 'merge:manual'; then
      printf 'blocked|PR #%s has merge:manual' "$member"
      return
    fi

    member_strategy="$(explicit_strategy_from_labels)"
    if [[ "$member_strategy" == 'conflict' ]]; then
      printf 'blocked|PR #%s has conflicting merge strategy labels' "$member"
      return
    fi

    if [[ -n "$member_strategy" ]]; then
      if [[ -n "$selected" && "$selected" != "$member_strategy" ]]; then
        printf 'blocked|stack members request different merge strategies'
        return
      fi
      selected="$member_strategy"
    fi
  done

  [[ -n "$selected" ]] || selected="$fallback_strategy"
  printf 'ok|%s' "$selected"
}

process_stack() {
  local pr="$1"
  local data="$2"
  local fallback_strategy="$3"
  local default_branch="$4"
  local sweep_mode="$5"

  local stack_json stack_number top_pr guard guard_state strategy
  stack_json="$(get_stack_object "$pr" || true)"

  if [[ -z "$stack_json" ]]; then
    upsert_comment "$pr" "$MARKER
**PR Conductor:** GitHub reports stack metadata on this PR, but the stack object could not be loaded. No stack mutation was attempted."
    return
  fi

  stack_number="$(jq -r '.number' <<<"$stack_json")"

  if [[ "$sweep_mode" == 'true' ]]; then
    top_pr="$(stack_top_open_pr "$stack_json")"

    if [[ -n "$top_pr" && "$pr" != "$top_pr" ]]; then
      log "Skipping PR #$pr; scheduled sweep will conduct stack #$stack_number from top PR #$top_pr."
      return
    fi

    if [[ -n "${SEEN_STACKS[$stack_number]:-}" ]]; then
      log "Stack #$stack_number already processed in this sweep."
      return
    fi

    SEEN_STACKS[$stack_number]=1
  fi

  guard="$(stack_strategy_and_guards "$stack_json" "$DEFAULT_STACK_STRATEGY")"
  guard_state="${guard%%|*}"
  strategy="${guard#*|}"

  # The stack guard inspects every member and changes LABELS, so restore the
  # current PR labels before applying per-PR auto-merge policy.
  load_labels "$data"

  if [[ "$guard_state" != 'ok' ]]; then
    upsert_comment "$pr" "$MARKER
**PR Conductor:** stack #$stack_number paused · $strategy."
    return
  fi

  local head_repo
  head_repo="$(jq -r '.head.repo.full_name // ""' <<<"$data")"

  if ! should_auto_merge "$head_repo"; then
    upsert_comment "$pr" "$MARKER
**PR Conductor:** stack #$stack_number recognized · strategy `$strategy` · automatic stack merge is not enabled for this PR."
    return
  fi

  if ! ensure_stack_extension; then
    upsert_comment "$pr" "$MARKER
**PR Conductor:** stack #$stack_number recognized, but the official `github/gh-stack` extension could not be installed."
    return
  fi

  local before_fingerprint after_fingerprint refreshed_stack
  before_fingerprint="$(
    jq -r '[.pull_requests[] | select(.state == "open") | .head.sha] | join(":")' <<<"$stack_json"
  )"

  if bool_true "$STACK_SYNC" && ! has_label 'rebase:off'; then
    if bool_true "$DRY_RUN"; then
      log "DRY RUN stack #$stack_number: would checkout + gh stack sync."
    else
      reset_worktree "$default_branch"
      git config rerere.enabled true
      git config user.name 'github-actions[bot]'
      git config user.email '41898282+github-actions[bot]@users.noreply.github.com'

      if ! gh stack checkout "$stack_number" >/dev/null 2>&1; then
        upsert_comment "$pr" "$MARKER
**PR Conductor:** stack #$stack_number checkout failed · no branches were rewritten."
        reset_worktree "$default_branch"
        return
      fi

      if ! gh stack sync >/dev/null 2>&1; then
        upsert_comment "$pr" "$MARKER
**PR Conductor:** stack #$stack_number needs manual rebase/conflict resolution · automatic merge paused."
        reset_worktree "$default_branch"
        return
      fi

      reset_worktree "$default_branch"

      refreshed_stack="$(get_stack_object "$pr" || true)"
      if [[ -n "$refreshed_stack" ]]; then
        after_fingerprint="$(
          jq -r '[.pull_requests[] | select(.state == "open") | .head.sha] | join(":")' <<<"$refreshed_stack"
        )"
      else
        after_fingerprint="$before_fingerprint"
      fi

      if [[ "$after_fingerprint" != "$before_fingerprint" ]]; then
        upsert_comment "$pr" "$MARKER
**PR Conductor:** stack #$stack_number cascade-rebased and pushed with lease protection · CI will rerun · planned merge `$strategy`."
        return
      fi
    fi
  fi

  if bool_true "$DRY_RUN"; then
    upsert_comment "$pr" "$MARKER
**PR Conductor:** dry run · would merge all currently open PRs in stack #$stack_number · strategy `$strategy`."
    return
  fi

  local -a merge_args=("$stack_number" --yes)
  case "$strategy" in
    squash) merge_args+=(--squash) ;;
    rebase) merge_args+=(--rebase) ;;
    merge) merge_args+=(--merge) ;;
    *)
      upsert_comment "$pr" "$MARKER
**PR Conductor:** stack #$stack_number paused · unsupported strategy `$strategy`."
      return
      ;;
  esac

  if gh stack merge "${merge_args[@]}" >/dev/null 2>&1; then
    upsert_comment "$pr" "$MARKER
**PR Conductor:** stack #$stack_number merge submitted · strategy `$strategy` · GitHub rules/queue remain authoritative."
  else
    upsert_comment "$pr" "$MARKER
**PR Conductor:** stack #$stack_number is waiting on checks, reviews, queue eligibility, or another GitHub merge requirement · strategy `$strategy`."
  fi
}
