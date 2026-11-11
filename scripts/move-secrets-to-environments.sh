#!/usr/bin/env bash
# Moves the vigeo deploy secrets from repository level to the stg and prod
# GitHub environments of each repository. The script reads each value from
# Vault or the terminal into memory and pipes it to `gh secret set`.
# It deletes a repository-level copy only after every environment copy of
# that secret is set in the same run.
#
# Usage: scripts/move-secrets-to-environments.sh [--dry-run]
set -euo pipefail

ORG=techflouu
export VAULT_ADDR="${VAULT_ADDR:-https://main.folk-tortoise.ts.net:8200}"
export VAULT_NAMESPACE="${VAULT_NAMESPACE:-admin}"
unset GITHUB_TOKEN

DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

# Each line: repo|environments|NAME|source
# source is one of:
#   vault:<mount>:<path>:<field>   read the field from Vault KV v2
#   prompt                         read the value hidden from the terminal
# A commented line under "# needs value:" is a secret with no known source.
# Uncomment it and set its source to move that secret.
SECRETS=$(cat <<'TABLE'
# journeyflouu
journeyflouu|prod|GCP_PROJECT_ID|vault:app/journeyflouu:server-prod:GCP_PROJECT
# needs value: NOMAD_ADDR
#journeyflouu|stg|NOMAD_ADDR|prompt
# needs value: NOMAD_TOKEN
#journeyflouu|stg|NOMAD_TOKEN|prompt
# needs value: TS_AUTHKEY
#journeyflouu|stg,prod|TS_AUTHKEY|prompt
# needs value: VAULT_ADDR
#journeyflouu|stg,prod|VAULT_ADDR|prompt
# needs value: VAULT_ROLE
#journeyflouu|stg,prod|VAULT_ROLE|prompt

# journeyflouu-ops
journeyflouu-ops|stg,prod|DATADOG_API_KEY|vault:app/journeyflouu:dd:DD_API_KEY
# needs value: TS_OAUTH_SECRET
#journeyflouu-ops|stg,prod|TS_OAUTH_SECRET|prompt
# needs value: VAULT_ADDR
#journeyflouu-ops|stg,prod|VAULT_ADDR|prompt
# needs value: VAULT_AUTH_PATH
#journeyflouu-ops|stg,prod|VAULT_AUTH_PATH|prompt
# needs value: VAULT_ROLE
#journeyflouu-ops|stg,prod|VAULT_ROLE|prompt
# needs value: VERCEL_ORG_ID
#journeyflouu-ops|stg,prod|VERCEL_ORG_ID|prompt
# needs value: VERCEL_PROJECT_ID
#journeyflouu-ops|stg,prod|VERCEL_PROJECT_ID|prompt
# needs value: VERCEL_SCOPE
#journeyflouu-ops|stg,prod|VERCEL_SCOPE|prompt
# needs value: VERCEL_TOKEN
#journeyflouu-ops|stg,prod|VERCEL_TOKEN|prompt

# journeyflouu-pwa
journeyflouu-pwa|stg,prod|DATADOG_API_KEY|vault:app/journeyflouu:dd:DD_API_KEY
# needs value: TS_OAUTH_SECRET
#journeyflouu-pwa|stg,prod|TS_OAUTH_SECRET|prompt
# needs value: VAULT_ADDR
#journeyflouu-pwa|stg,prod|VAULT_ADDR|prompt
# needs value: VAULT_AUTH_PATH
#journeyflouu-pwa|stg,prod|VAULT_AUTH_PATH|prompt
# needs value: VAULT_AUTH_ROLE
#journeyflouu-pwa|stg,prod|VAULT_AUTH_ROLE|prompt
# needs value: VAULT_ROLE
#journeyflouu-pwa|stg,prod|VAULT_ROLE|prompt
# needs value: VERCEL_ORG_ID
#journeyflouu-pwa|stg,prod|VERCEL_ORG_ID|prompt
# needs value: VERCEL_PROJECT_ID
#journeyflouu-pwa|stg,prod|VERCEL_PROJECT_ID|prompt
# needs value: VERCEL_SCOPE
#journeyflouu-pwa|stg,prod|VERCEL_SCOPE|prompt
# needs value: VERCEL_TOKEN
#journeyflouu-pwa|stg,prod|VERCEL_TOKEN|prompt

# journey-app
journey-app|stg|HUGEICONS_LICENSE_KEY|vault:app/journeyflouu:ops-stg:HUGEICONS_LICENSE_KEY
journey-app|prod|HUGEICONS_LICENSE_KEY|vault:app/journeyflouu:ops-prod:HUGEICONS_LICENSE_KEY
# needs value: EXPO_TOKEN
#journey-app|stg,prod|EXPO_TOKEN|prompt
# needs value: TS_OAUTH_CLIENT_ID
#journey-app|stg,prod|TS_OAUTH_CLIENT_ID|prompt
# needs value: TS_OAUTH_SECRET
#journey-app|stg,prod|TS_OAUTH_SECRET|prompt
# needs value: VAULT_ADDR
#journey-app|stg,prod|VAULT_ADDR|prompt
# needs value: VAULT_ROLE
#journey-app|stg,prod|VAULT_ROLE|prompt
TABLE
)

# Secrets that stay at repository level, per repository.
keep_at_repo_level() {
  case "$1" in
    journeyflouu-ops | journeyflouu-pwa) echo "DISCORD_WEBHOOK HUGEICONS_LICENSE_KEY TEMP_VAULT_TOKEN" ;;
    *) echo "DISCORD_WEBHOOK" ;;
  esac
}

read_value() {
  local source=$1 name=$2 mount path field
  case "$source" in
    vault:*)
      IFS=: read -r _ mount path field <<<"$source"
      vault kv get -mount="$mount" -field="$field" "$path"
      ;;
    prompt)
      local v
      read -rs -p "Value for $name: " v </dev/tty
      echo >&2
      printf '%s' "$v"
      ;;
    *)
      echo "unknown source for $name: $source" >&2
      return 1
      ;;
  esac
}

RESULTS=$(mktemp)
trap 'rm -f "$RESULTS"' EXIT

while IFS='|' read -r repo envs name source; do
  case "$repo" in '' | '#'*) continue ;; esac
  if ! value=$(read_value "$source" "$name"); then
    echo "FAIL  $repo $name: cannot read $source"
    echo "$repo $name fail" >>"$RESULTS"
    continue
  fi
  if [ -z "$value" ]; then
    echo "FAIL  $repo $name: empty value from $source"
    echo "$repo $name fail" >>"$RESULTS"
    continue
  fi
  for env in ${envs//,/ }; do
    if $DRY_RUN; then
      echo "DRY   $repo $name -> environment $env"
      echo "$repo $name ok" >>"$RESULTS"
    elif printf '%s' "$value" | gh secret set "$name" --env "$env" --repo "$ORG/$repo"; then
      echo "SET   $repo $name -> environment $env"
      echo "$repo $name ok" >>"$RESULTS"
    else
      echo "FAIL  $repo $name -> environment $env"
      echo "$repo $name fail" >>"$RESULTS"
    fi
  done
  unset value
done <<<"$SECRETS"

# Delete the repository-level copy of each secret that moved with no failure.
awk '{print $1, $2}' "$RESULTS" | sort -u | while read -r repo name; do
  if grep -q "^$repo $name fail$" "$RESULTS"; then
    echo "KEEP  $repo $name: an environment copy failed, the repository copy stays"
    continue
  fi
  if ! gh secret list --repo "$ORG/$repo" --json name --jq '.[].name' | grep -qx "$name"; then
    continue
  fi
  if $DRY_RUN; then
    echo "DRY   $repo $name: delete repository copy"
  else
    gh secret delete "$name" --repo "$ORG/$repo"
    echo "DEL   $repo $name: repository copy"
  fi
done

echo
echo "TEMP_VAULT_TOKEN on journeyflouu-ops does not move. Revoke the token, then delete the repository copy:"
echo "  vault list auth/token/accessors"
echo "  vault token revoke -accessor <accessor of TEMP_VAULT_TOKEN>"
echo "  gh secret delete TEMP_VAULT_TOKEN --repo $ORG/journeyflouu-ops"

echo
echo "Repository-level secrets that still need to move:"
for repo in journeyflouu journeyflouu-ops journeyflouu-pwa journey-app; do
  keep=" $(keep_at_repo_level "$repo") "
  for name in $(gh secret list --repo "$ORG/$repo" --json name --jq '.[].name'); do
    case "$keep" in *" $name "*) continue ;; esac
    echo "  $repo $name"
  done
done
