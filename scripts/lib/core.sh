#!/usr/bin/env bash

API_VERSION="${PRC_API_VERSION:-2026-03-10}"
MARKER="<!-- pr-conductor:v2 -->"

GH_REPO="${GH_REPO:?GH_REPO is required}"
EVENT_NAME="${EVENT_NAME:-workflow_dispatch}"
TARGET_PR="${TARGET_PR:-0}"
AUTO_MERGE_MODE="${AUTO_MERGE_MODE:-same-repo}"
AUTO_REBASE="${AUTO_REBASE:-true}"
STACK_SYNC="${STACK_SYNC:-true}"
NORMALIZE_TITLES="${NORMALIZE_TITLES:-true}"
COMMENT_ENABLED="${COMMENT_ENABLED:-true}"
DRY_RUN="${DRY_RUN:-false}"
DEFAULT_SINGLE_STRATEGY="${DEFAULT_SINGLE_STRATEGY:-rebase}"
DEFAULT_MULTI_STRATEGY="${DEFAULT_MULTI_STRATEGY:-squash}"
RELEASE_STRATEGY="${RELEASE_STRATEGY:-merge}"
DEFAULT_STACK_STRATEGY="${DEFAULT_STACK_STRATEGY:-squash}"

declare -a LABELS=()
declare -A SEEN_STACKS=()
STACK_EXTENSION_READY=false

log() {
  printf '[pr-conductor] %s\n' "$*"
}

warn() {
  printf '::warning::%s\n' "$*"
}

api() {
  gh api \
    -H 'Accept: application/vnd.github+json' \
    -H "X-GitHub-Api-Version: $API_VERSION" \
    "$@"
}

bool_true() {
  [[ "${1,,}" == "true" || "$1" == "1" || "${1,,}" == "yes" ]]
}

has_label() {
  local wanted="$1"
  local label
  for label in "${LABELS[@]:-}"; do
    [[ "$label" == "$wanted" ]] && return 0
  done
  return 1
}

load_labels() {
  local json="$1"
  mapfile -t LABELS < <(jq -r '.labels[]?.name' <<<"$json")
}

upsert_comment() {
  local pr="$1"
  local body="$2"

  bool_true "$COMMENT_ENABLED" || return 0

  if bool_true "$DRY_RUN"; then
    log "DRY RUN comment for PR #$pr: ${body//$'\n'/ | }"
    return 0
  fi

  local comment_id=""
  comment_id="$(
    api --paginate "repos/$GH_REPO/issues/$pr/comments" \
      --jq '.[] | select(.body | contains("<!-- pr-conductor:v2 -->")) | .id' \
      2>/dev/null | head -n 1 || true
  )"

  if [[ -n "$comment_id" ]]; then
    api --method PATCH "repos/$GH_REPO/issues/comments/$comment_id" \
      -f body="$body" >/dev/null 2>&1 || warn "Could not update PR Conductor comment on PR #$pr."
  else
    api --method POST "repos/$GH_REPO/issues/$pr/comments" \
      -f body="$body" >/dev/null 2>&1 || warn "Could not create PR Conductor comment on PR #$pr."
  fi
}

infer_type_from_branch() {
  case "$1" in
    feat/*|feature/*) printf 'feat' ;;
    fix/*|bugfix/*|bug/*) printf 'fix' ;;
    docs/*) printf 'docs' ;;
    refactor/*) printf 'refactor' ;;
    perf/*) printf 'perf' ;;
    test/*|tests/*) printf 'test' ;;
    ci/*) printf 'ci' ;;
    build/*) printf 'build' ;;
    chore/*|deps/*|dependency/*) printf 'chore' ;;
    *) printf 'chore' ;;
  esac
}

make_title() {
  local current="$1"
  local branch="$2"

  if ! bool_true "$NORMALIZE_TITLES" || has_label 'title:keep'; then
    printf '%s' "$current"
    return
  fi

  local type_override=false scope_override=false label
  for label in "${LABELS[@]:-}"; do
    [[ "$label" == type:* ]] && type_override=true
    [[ "$label" == scope:* ]] && scope_override=true
  done

  if [[ "$current" =~ ^(feat|fix|docs|refactor|perf|test|build|ci|chore)(\([^\)]+\))?!?:[[:space:]].+ ]] \
    && [[ "$type_override" == false && "$scope_override" == false ]]; then
    printf '%s' "$current"
    return
  fi

  local kind="" scope="" clean="$current"
  for label in "${LABELS[@]:-}"; do
    case "$label" in
      type:feat|type:feature) kind='feat' ;;
      type:fix|type:bug) kind='fix' ;;
      type:docs) kind='docs' ;;
      type:refactor) kind='refactor' ;;
      type:perf) kind='perf' ;;
      type:test) kind='test' ;;
      type:build) kind='build' ;;
      type:ci) kind='ci' ;;
      type:chore) kind='chore' ;;
      scope:*) scope="${label#scope:}" ;;
    esac
  done

  [[ -n "$kind" ]] || kind="$(infer_type_from_branch "$branch")"

  clean="$(
    printf '%s' "$clean" |
      sed -E 's/^(feat|fix|docs|refactor|perf|test|build|ci|chore)(\([^)]*\))?!?:[[:space:]]*//'
  )"
  clean="$(printf '%s' "$clean" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  [[ -n "$clean" ]] || clean="$(printf '%s' "$branch" | tr '/_-' '   ' | sed -E 's/[[:space:]]+/ /g')"

  if [[ -n "$scope" ]]; then
    scope="$(printf '%s' "$scope" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9._/-')"
    printf '%s(%s): %s' "$kind" "$scope" "$clean"
  else
    printf '%s: %s' "$kind" "$clean"
  fi
}

explicit_strategy_from_labels() {
  local count=0 selected=""
  has_label 'merge:squash' && { count=$((count + 1)); selected='squash'; }
  has_label 'merge:rebase' && { count=$((count + 1)); selected='rebase'; }
  has_label 'merge:commit' && { count=$((count + 1)); selected='merge'; }

  if (( count > 1 )); then
    printf 'conflict'
  elif (( count == 1 )); then
    printf '%s' "$selected"
  fi
}

choose_strategy() {
  local head_ref="$1" commits="$2" explicit
  explicit="$(explicit_strategy_from_labels)"
  if [[ -n "$explicit" ]]; then
    printf '%s' "$explicit"
  elif [[ "$head_ref" =~ ^(release|hotfix)/ ]]; then
    printf '%s' "$RELEASE_STRATEGY"
  elif (( commits <= 1 )); then
    printf '%s' "$DEFAULT_SINGLE_STRATEGY"
  else
    printf '%s' "$DEFAULT_MULTI_STRATEGY"
  fi
}

should_auto_merge() {
  local head_repo="$1"

  has_label 'merge:hold' && return 1
  has_label 'merge:manual' && return 1
  has_label 'conductor:off' && return 1
  has_label 'merge:auto' && return 0

  case "${AUTO_MERGE_MODE,,}" in
    all) return 0 ;;
    same-repo|same_repo|same_repo_only) [[ "$head_repo" == "$GH_REPO" ]] ;;
    labeled|labelled|label-only|label_only|off|false|none) return 1 ;;
    *)
      warn "Unknown AUTO_MERGE_MODE=$AUTO_MERGE_MODE; falling back to same-repo."
      [[ "$head_repo" == "$GH_REPO" ]]
      ;;
  esac
}

normalize_pr_title() {
  local pr="$1" current="$2" head_ref="$3" next
  next="$(make_title "$current" "$head_ref")"

  if [[ "$next" == "$current" ]]; then
    printf '%s' "$current"
    return
  fi

  if bool_true "$DRY_RUN"; then
    log "DRY RUN title PR #$pr: $current -> $next"
    printf '%s' "$next"
    return
  fi

  if api --method PATCH "repos/$GH_REPO/pulls/$pr" -f title="$next" >/dev/null 2>&1; then
    log "Normalized title for PR #$pr: $next"
    printf '%s' "$next"
  else
    warn "Could not update title for PR #$pr; keeping current title."
    printf '%s' "$current"
  fi
}
