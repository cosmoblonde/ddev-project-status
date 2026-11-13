#!/usr/bin/env bash
#ddev-generated
# Git facts for checks/05-git and the project data. Sourced, not executed.
# Used on the host by commands/host/project-status, where bash may be 3.2 (macOS), and as fallback in the web
# container by the runner. Read only and offline: no fetch, only the local refs as of the last fetch.
#
# cb_git_facts <dir> [<branch>...] sets and exports:
#   PROJECT_STATUS_GIT_STATE     ok, no_git or no_repo
#   PROJECT_STATUS_GIT_BRANCH    current branch, empty when HEAD is detached
#   PROJECT_STATUS_GIT_HEAD      short hash of HEAD
#   PROJECT_STATUS_GIT_BRANCHES  one line per given local branch: name, upstream, track ("ahead 1, behind 2",
#                                "gone" or empty), tab separated
#   PROJECT_STATUS_GIT_FETCHED   time of the last fetch in seconds since 1970, empty if there was none

cb_git_facts() {
  local dir="$1" fetch_head pattern patterns=()
  shift
  PROJECT_STATUS_GIT_BRANCH=""
  PROJECT_STATUS_GIT_HEAD=""
  PROJECT_STATUS_GIT_BRANCHES=""
  PROJECT_STATUS_GIT_FETCHED=""

  if ! command -v git >/dev/null 2>&1; then
    PROJECT_STATUS_GIT_STATE="no_git"
  elif ! git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
    PROJECT_STATUS_GIT_STATE="no_repo"
  else
    PROJECT_STATUS_GIT_STATE="ok"
    PROJECT_STATUS_GIT_BRANCH=$(git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null)
    PROJECT_STATUS_GIT_HEAD=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)
    # only the given branches: computing ahead/behind for every local branch can take long in big repositories
    for pattern in "$@"; do
      patterns+=("refs/heads/$pattern")
    done
    if (( ${#patterns[@]} )); then
      PROJECT_STATUS_GIT_BRANCHES=$(git -C "$dir" for-each-ref \
        --format='%(refname:short)%09%(upstream:short)%09%(upstream:track,nobracket)' "${patterns[@]}" 2>/dev/null)
    fi
    # FETCH_HEAD is written by every fetch and pull; the path is relative to dir unless git returns an absolute one
    fetch_head=$(git -C "$dir" rev-parse --git-path FETCH_HEAD 2>/dev/null)
    case "$fetch_head" in
      /*|?:*) ;;
      *) fetch_head="$dir/$fetch_head" ;;
    esac
    if [[ -f "$fetch_head" ]]; then
      PROJECT_STATUS_GIT_FETCHED=$(date -r "$fetch_head" +%s 2>/dev/null)
    fi
  fi

  export PROJECT_STATUS_GIT_STATE PROJECT_STATUS_GIT_BRANCH PROJECT_STATUS_GIT_HEAD PROJECT_STATUS_GIT_BRANCHES \
    PROJECT_STATUS_GIT_FETCHED
}
