#!/usr/bin/env bash
# Validates the read-secrets inputs for the selected backend before any step reaches a secret store.
# It reads the inputs from the environment and prints only the names of the missing inputs.
set -euo pipefail
set +x

missing=()
require() {
  local name="$1" value="$2"
  [ -n "$value" ] || missing+=("$name")
}

backend="${BACKEND:-}"
case "$backend" in
  vault)
    require ts-oauth-secret "${TS_OAUTH_SECRET:-}"
    require vault-addr "${VAULT_ADDR:-}"
    require vault-role "${VAULT_ROLE:-}"
    ;;
  gsm)
    require gcp-project "${GCP_PROJECT:-}"
    require gcp-workload-identity-provider "${GCP_WORKLOAD_IDENTITY_PROVIDER:-}"
    require gcp-service-account "${GCP_SERVICE_ACCOUNT:-}"
    ;;
  *)
    echo "::error::read-secrets: backend must be 'vault' or 'gsm', got '$backend'."
    exit 1
    ;;
esac

if [ "${#missing[@]}" -gt 0 ]; then
  echo "::error::read-secrets: backend '$backend' with target '${TARGET:-}' requires: ${missing[*]}."
  exit 1
fi
echo "read-secrets: inputs valid for backend '$backend'."
