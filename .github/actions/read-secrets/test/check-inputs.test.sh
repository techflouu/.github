#!/usr/bin/env bash
# Runs check-inputs.sh over each backend and target case and asserts the exit code and the named inputs.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="$here/../check-inputs.sh"
failures=0

# Usage: expect <exit-code> <expected-output-substring> [VAR=value ...]
expect() {
  local code="$1" want="$2" got rc=0
  shift 2
  got="$(env -i PATH="$PATH" "$@" bash "$script" 2>&1)" || rc=$?
  if [ "$rc" != "$code" ] || [[ $got != *"$want"* ]]; then
    echo "FAIL: $* -> exit $rc, output: $got"
    failures=$((failures + 1))
  fi
}

vault=(TS_OAUTH_SECRET=ts VAULT_ADDR=https://vault.test VAULT_ROLE=role)
gsm=(GCP_PROJECT=journeyflouu GCP_WORKLOAD_IDENTITY_PROVIDER=projects/1/pools/p/providers/g GCP_SERVICE_ACCOUNT=sa@journeyflouu.iam.gserviceaccount.com)

expect 0 "valid for backend 'vault'" BACKEND=vault TARGET=stg "${vault[@]}"
expect 1 "requires: ts-oauth-secret vault-addr vault-role." BACKEND=vault TARGET=prod
expect 1 "requires: vault-role." BACKEND=vault TARGET=prod TS_OAUTH_SECRET=ts VAULT_ADDR=https://vault.test
expect 0 "valid for backend 'gsm'" BACKEND=gsm TARGET=prod "${gsm[@]}"
expect 0 "valid for backend 'gsm'" BACKEND=gsm TARGET=stg NOMAD_TOKEN=token "${gsm[@]}"
expect 1 "requires: nomad-token." BACKEND=gsm TARGET=stg "${gsm[@]}"
expect 1 "requires: gcp-workload-identity-provider gcp-service-account." BACKEND=gsm TARGET=prod GCP_PROJECT=journeyflouu
expect 1 "requires: gcp-project." BACKEND=gsm TARGET=prod GCP_WORKLOAD_IDENTITY_PROVIDER=p GCP_SERVICE_ACCOUNT=s
expect 1 "backend must be 'vault' or 'gsm', got 'GSM'" BACKEND=GSM TARGET=prod "${gsm[@]}"
expect 1 "backend must be 'vault' or 'gsm', got ''" TARGET=prod "${vault[@]}"

if [ "$failures" -gt 0 ]; then
  echo "FAIL: $failures of 10 cases"
  exit 1
fi
echo "PASS: 10 input-check cases"
