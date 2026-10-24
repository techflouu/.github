#!/usr/bin/env bash
# Runs mask-config-values.sh over a fixture .env, JSON key file and nomad.token.
# It asserts one ::add-mask:: line per value and no other value output.
# Usage: mask-config-values.test.sh [fixture-dir]. The fixture directory stays for a later live check.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dir="${1:-$(mktemp -d)}"
mkdir -p "$dir"

cat >"$dir/.env" <<'ENV'
# fixture comment
EMPTY=
PLAIN=plain-value-1
export EXPORTED=exported-value-2
QUOTED="quoted value 3"
SINGLE='single-value-4'
WITH_EQ=a=b=c-5
INLINE=inline-value-6 # trailing comment
MULTI="-----BEGIN FIXTURE KEY-----
multi-body-7
-----END FIXTURE KEY-----"
ESCAPED="esc-line-8\nesc-line-9"
PERCENT=100%0Aoff-10
RELEASE_TAG=v9.9.9-fixture
ENV

cat >"$dir/key.json" <<'JSON'
{
  "type": "fixture_account",
  "private_key": "-----BEGIN PRIVATE FIXTURE-----\nkey-body-11\n-----END PRIVATE FIXTURE-----\n",
  "nested": { "client_email": "ci@fixture.test", "list": ["array-value-12", 13] }
}
JSON

printf 'nomad-token-fixture-14\n' >"$dir/nomad.token"

expected="$(cat <<'OUT'
::add-mask::-----BEGIN FIXTURE KEY-----
::add-mask::-----BEGIN FIXTURE KEY-----%0Amulti-body-7%0A-----END FIXTURE KEY-----
::add-mask::-----BEGIN PRIVATE FIXTURE-----
::add-mask::-----BEGIN PRIVATE FIXTURE-----%0Akey-body-11%0A-----END PRIVATE FIXTURE-----
::add-mask::-----BEGIN PRIVATE FIXTURE-----\nkey-body-11\n-----END PRIVATE FIXTURE-----\n
::add-mask::-----END FIXTURE KEY-----
::add-mask::-----END PRIVATE FIXTURE-----
::add-mask::100%250Aoff-10
::add-mask::a=b=c-5
::add-mask::array-value-12
::add-mask::ci@fixture.test
::add-mask::esc-line-8
::add-mask::esc-line-8\nesc-line-9
::add-mask::esc-line-9
::add-mask::exported-value-2
::add-mask::fixture_account
::add-mask::inline-value-6
::add-mask::inline-value-6 # trailing comment
::add-mask::key-body-11
::add-mask::multi-body-7
::add-mask::nomad-token-fixture-14
::add-mask::plain-value-1
::add-mask::quoted value 3
::add-mask::single-value-4
::add-mask::v9.9.9-fixture
OUT
)"

output="$(bash "$here/../mask-config-values.sh" "$dir")"
actual="$(grep '^::add-mask::' <<<"$output" | LC_ALL=C sort)"
other="$(grep -v '^::add-mask::' <<<"$output" || true)"

if [ "$actual" != "$(LC_ALL=C sort <<<"$expected")" ]; then
  echo "FAIL: mask lines differ from the expected set"
  diff <(LC_ALL=C sort <<<"$expected") <(echo "$actual") || true
  exit 1
fi
if [ "$other" != "Registered 25 values from $dir with the log masker." ]; then
  echo "FAIL: unexpected output outside ::add-mask:: lines"
  exit 1
fi
echo "PASS: 25 values, one ::add-mask:: line each"
