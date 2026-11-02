#!/usr/bin/env bash
#ddev-generated
# Translatable texts for project-status, project-commands and the bundled checks. Sourced, not executed.
#
# Catalogs in $PROJECT_STATUS_DIR/lang/, one "key = text" per line, text is a printf format (%s, literal %%):
#   <language>          bundled with the add-on, replaced on updates
#   <language>.custom   own texts and overrides, e.g. for own checks; never touched by updates
# Load order: en, en.custom, OUTPUT_LANGUAGE, OUTPUT_LANGUAGE.custom. Later files win, so a missing
# translation falls back to English and a missing key is printed as it is.
#
# Usage in a bash check:
#   source "$PROJECT_STATUS_DIR/lib/i18n.sh"
#   t composer.no_json "$COMPOSER_DIR"

declare -gA CB_TEXTS=()

cb_load_catalog() {
  local file="$1" line
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*([A-Za-z0-9_.-]+)[[:space:]]*=[[:space:]]?(.*)$ ]] || continue
    CB_TEXTS["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
  done < "$file"
}

cb_load_texts() {
  local dir="${PROJECT_STATUS_DIR:-}/lang" language="${OUTPUT_LANGUAGE:-en}"
  CB_TEXTS=()
  cb_load_catalog "$dir/en"
  cb_load_catalog "$dir/en.custom"
  if [[ "$language" != "en" ]]; then
    cb_load_catalog "$dir/$language"
    cb_load_catalog "$dir/$language.custom"
  fi
}

# Print the text for a key, formatted with the remaining arguments, followed by a newline
t() {
  local key="$1"
  shift
  # shellcheck disable=SC2059
  printf "${CB_TEXTS[$key]:-$key}\n" "$@"
}

cb_load_texts
