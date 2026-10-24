#!/usr/bin/env bash
# Registers every value in a rendered config directory with the Actions log masker.
# Dotenv files are parsed as KEY=VALUE, *.json files by jq, every other text file whole and by line.
# The script prints a value only inside an ::add-mask:: command.
set -euo pipefail
set +x

dir="${1:?usage: mask-config-values.sh <config-dir>}"
if [ ! -d "$dir" ]; then
  echo "No config directory at $dir."
  exit 0
fi
declare -A seen=()
count=0

# Trims, escapes and registers one single value. A repeated value is registered once.
mask_one() {
  local v="$1"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  [ -n "$v" ] || return 0
  [ -z "${seen[$v]+x}" ] || return 0
  seen[$v]=1
  count=$((count + 1))
  v="${v//%/%25}"
  v="${v//$'\r'/%0D}"
  v="${v//$'\n'/%0A}"
  printf '::add-mask::%s\n' "$v"
}

# Registers a value, each of its lines, and each segment between literal \n sequences.
mask_value() {
  local v="$1" line rest
  mask_one "$v"
  if [[ $v == *$'\n'* ]]; then
    while IFS= read -r line || [ -n "$line" ]; do mask_one "$line"; done <<<"$v"
  fi
  if [[ $v == *'\n'* ]]; then
    rest="$v"
    while [[ $rest == *'\n'* ]]; do
      mask_one "${rest%%\\n*}"
      rest="${rest#*\\n}"
    done
    mask_one "$rest"
  fi
}

mask_dotenv() {
  local line value quote="" pending="" q rest
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    if [ -n "$quote" ]; then
      if [[ $line == *"$quote"* ]]; then
        pending+=$'\n'"${line%"$quote"*}"
        mask_value "$pending"
        quote=""
        pending=""
      else
        pending+=$'\n'"$line"
      fi
      continue
    fi
    line="${line#"${line%%[![:space:]]*}"}"
    [[ -z $line || $line == \#* || $line != *=* ]] && continue
    value="${line#*=}"
    value="${value#"${value%%[![:space:]]*}"}"
    q="${value:0:1}"
    if [[ $q == '"' || $q == "'" || $q == '`' ]]; then
      rest="${value:1}"
      if [[ $rest == *"$q"* ]]; then
        mask_value "${rest%"$q"*}"
      else
        quote="$q"
        pending="$rest"
      fi
    else
      mask_value "$value"
      mask_value "${value%%[[:space:]]#*}"
    fi
  done <"$1"
  if [ -n "$quote" ]; then mask_value "$pending"; fi
}

mask_json() {
  local v
  if ! jq -e . "$1" >/dev/null 2>&1; then
    mask_text "$1"
    return
  fi
  while IFS= read -r -d '' v; do mask_value "$v"; done \
    < <(jq -j '.. | strings | (., "\u0000")' "$1")
  # Registers the JSON-escaped form of each string, because the file holds that form.
  while IFS= read -r -d '' v; do mask_one "$v"; done \
    < <(jq -j '.. | strings | (tojson | .[1:-1]) as $e | select($e != .) | ($e, "\u0000")' "$1")
}

mask_text() {
  grep -Iq . "$1" || return 0
  mask_value "$(<"$1")"
}

while IFS= read -r -d '' file; do
  case "$(basename "$file")" in
    .env | .env.* | *.env) mask_dotenv "$file" ;;
    *.json) mask_json "$file" ;;
    *) mask_text "$file" ;;
  esac
done < <(find "$dir" -type f -print0 | sort -z)

echo "Registered $count values from $dir with the log masker."
