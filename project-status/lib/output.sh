#!/usr/bin/env bash
#ddev-generated
# Shared helpers for project-status and project-commands. Sourced, not executed.

# Colors only on a terminal and without NO_COLOR (https://no-color.org), so piped output and tests get plain text.
# PROJECT_STATUS_COLOR=1 or 0 overrides that, e.g. for the hook run.
cb_set_colors() {
  local use_color=0
  if [[ -n "${PROJECT_STATUS_COLOR:-}" ]]; then
    [[ "$PROJECT_STATUS_COLOR" == "1" ]] && use_color=1
  elif [[ -z "${NO_COLOR:-}" && -t 1 ]]; then
    use_color=1
  fi
  if (( use_color )); then
    normal=$'\e[0m' bold=$'\e[1m' dim=$'\e[2m' green=$'\e[32m' cyan=$'\e[36m' yellow=$'\e[1;33m' red=$'\e[1;31m'
  else
    normal="" bold="" dim="" green="" cyan="" yellow="" red=""
  fi
  export PROJECT_STATUS_COLOR="$use_color"
}
cb_set_colors

# Width of the first column in cb_row, shared by all commands so that the output lines up
CB_COLUMN_WIDTH=20

# Defaults, then .ddev/project-status/config. Every value is exported, so checks in any language can read it.
# Loads the texts for OUTPUT_LANGUAGE afterwards (lib/i18n.sh).
cb_load_config() {
  set -a
  PROJECT_STATUS_DIR="$STATUS_DIR"
  OUTPUT_LANGUAGE="en"
  BRAND=""
  HOOK="true"
  HOOK_OPTIONS=""
  TIMEOUT="20"
  SKIP_CHECKS=""
  COMPOSER_DIR="."
  FRONTEND_DIR=""
  REQUIRED_DIRS=""
  REQUIRED_ASSETS=""
  COMPOSER_HINT="ddev composer install"
  NPM_HINT=""
  BUILD_HINT=""
  # shellcheck disable=SC1090
  [[ -f "$STATUS_DIR/config" ]] && source "$STATUS_DIR/config"
  # hints that depend on FRONTEND_DIR
  [[ -n "$NPM_HINT" ]] || NPM_HINT="ddev exec -d /var/www/html${FRONTEND_DIR:+/$FRONTEND_DIR} npm ci"
  [[ -n "$BUILD_HINT" ]] || BUILD_HINT="ddev exec -d /var/www/html${FRONTEND_DIR:+/$FRONTEND_DIR} npm run build"
  set +a
  source "$STATUS_DIR/lib/i18n.sh"
}

# Header with brand and project name
cb_header() {
  local project="${DDEV_PROJECT:-${DDEV_SITENAME:-}}"
  echo
  echo "${bold}${BRAND:+$BRAND · }${project}${normal}"
}

# Section heading, preceded by an empty line
cb_section() {
  echo
  echo "${bold}$1${normal}"
}

# Two-column row: key and value
cb_row() {
  printf "  %-${CB_COLUMN_WIDTH}s %s\n" "$1" "$2"
}

# Status line of a check: OK, INFO, WARN, FAIL or SKIP plus message
cb_status() {
  local color
  case "$1" in
    OK)   color="$green" ;;
    INFO) color="$cyan" ;;
    WARN) color="$yellow" ;;
    FAIL) color="$red" ;;
    SKIP) color="$dim" ;;
    *)    color="$normal" ;;
  esac
  printf "  %s%-7s%s %s\n" "$color" "[$1]" "$normal" "$2"
}
