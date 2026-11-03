#!/usr/bin/env bash
# Offline test for cnp-clean's deletion-protection filter: `gh` is stubbed, nothing leaves the machine.
set -euo pipefail

err=$(mktemp)
trap 'rm -f "$err"' EXIT

fail() { echo "FAIL: $*" >&2; cat "$err" >&2; exit 1; }

# Stub for `gh api repos/<repo>/contents/registry/projects/<project>.yaml --jq .content`
# and for the registry reachability check `gh api repos/<repo>`.
registry_up=true
gh() {
  case "$2" in
    */iot.yaml)     printf 'spec:\n  targetCloud: onprem\n  deletionProtection: true\n' | base64 ;;
    */demo.yaml)    printf 'spec:\n  targetCloud: onprem\n' | base64 ;;
    */missing.yaml) echo 'gh: Not Found (HTTP 404)' >&2; return 1 ;;
    */broken.yaml)  echo 'gh: Internal Server Error (HTTP 500)' >&2; return 1 ;;
    repos/*/contents/*) fail "unexpected gh call: $*" ;;
    repos/*)        [ "$registry_up" = true ] || { echo 'gh: Not Found (HTTP 404)' >&2; return 1; } ;;
    *)              fail "unexpected gh call: $*" ;;
  esac
}

source "$(dirname "${BASH_SOURCE[0]}")/cnp-clean.sh"

out=$(printf 'onprem iot\nonprem demo\nonprem missing\nonprem broken\n' | keep_unprotected 2>"$err") || fail "keep_unprotected errored"
[ "$out" = $'onprem demo\nonprem missing' ] || fail "kept: $out"
grep -q 'skipped: iot (deletion protection)' "$err" || fail "iot not reported"
grep -q 'skipped: broken (registry record unreadable' "$err" || fail "broken not reported"

# Registry unreachable (e.g. token without access): refuse everything, print nothing.
registry_up=false
out=$(printf 'onprem demo\n' | keep_unprotected 2>"$err") && fail "unreadable registry did not abort"
[ -z "$out" ] || fail "stdout not empty: $out"
grep -q 'cannot read the registry' "$err" || fail "registry error not reported"

echo "ok"
