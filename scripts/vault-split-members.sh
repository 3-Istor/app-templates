#!/usr/bin/env bash
#
# vault-split-members: one-off migration for projects bootstrapped before the
# read/write split in templates/project-bootstrap. Brings Vault to what the
# module now creates: project-<p>-read-policy, an external group
# project-<p>-members holding it, the members OIDC alias on that group and the
# admins OIDC alias on project-<p>-devs.
#
# The admins alias is repaired too: an external group keeps a single alias, so
# the old module's second alias silently replaced the first and one of the two
# is missing on every existing project.
#
# Idempotent. Reads VAULT_ADDR and VAULT_TOKEN from the environment.
#
#   ./vault-split-members.sh --dry-run                 # iot joetest self-runner test-link
#   ./vault-split-members.sh iot joetest
#
set -euo pipefail

readonly DEFAULT_PROJECTS=(iot joetest self-runner test-link)
readonly OIDC_MOUNT="oidc/"

DRY_RUN=false
PROJECTS=()

usage() {
  sed -n '3,17p' "$0" | sed 's/^# \{0,1\}//'
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -h | --help) usage; exit 0 ;;
    -*) echo "unknown flag: $arg" >&2; exit 2 ;;
    *) PROJECTS+=("$arg") ;;
  esac
done
[[ ${#PROJECTS[@]} -eq 0 ]] && PROJECTS=("${DEFAULT_PROJECTS[@]}")

: "${VAULT_ADDR:?VAULT_ADDR must be set}"
: "${VAULT_TOKEN:?VAULT_TOKEN must be set}"
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }
command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }

# The token goes to curl on stdin so it never shows in `ps`.
vault_api() {
  local method="$1" path="$2" body="${3:-}"
  local args=(-sS -X "$method" -H @- -w '\n%{http_code}' "${VAULT_ADDR%/}/v1/$path")
  [[ -n "$body" ]] && args+=(-H 'Content-Type: application/json' --data "$body")
  printf 'X-Vault-Token: %s\n' "$VAULT_TOKEN" | curl "${args[@]}"
}

# Prints the body on 2xx, nothing on 404, aborts otherwise.
api() {
  local out code
  out="$(vault_api "$@")"
  code="${out##*$'\n'}"
  out="${out%$'\n'*}"
  case "$code" in
    2??) printf '%s' "$out" ;;
    404) ;;
    *)
      echo "vault: $1 $2 returned $code: $(jq -c '.errors // .' <<<"$out" 2>/dev/null || echo "$out")" >&2
      exit 1
      ;;
  esac
}

change() {
  if $DRY_RUN; then
    echo "  [dry-run] $*"
  else
    echo "  [apply]   $*"
  fi
}

# Must match vault_policy.project_readers in templates/project-bootstrap/main.tf
# byte for byte, so a later `terraform import` shows no diff.
read_policy() {
  local p="$1"
  cat <<EOT
path "sys/mounts" {
  capabilities = ["read"]
}
path "sys/internal/ui/mounts/*" {
  capabilities = ["read"]
}

path "project-$p/data/*" {
  capabilities = ["read", "list"]
}
path "project-$p/metadata/*" {
  capabilities = ["read", "list"]
}
EOT
}

ensure_policy() {
  local name="$1" text="$2" current
  current="$(api GET "sys/policies/acl/$name" | jq -r '.data.policy // empty')"
  if [[ "$current" == "$text" ]]; then
    echo "  ok        policy $name"
    return
  fi
  change "$([[ -z "$current" ]] && echo create || echo update) policy $name"
  $DRY_RUN || api PUT "sys/policies/acl/$name" "$(jq -n --arg p "$text"$'\n' '{policy: $p}')" >/dev/null
}

# Prints the group id, or "<new>" when a dry run would have created it.
ensure_group() {
  local name="$1" policy="$2" group id
  group="$(api GET "identity/group/name/$name")"
  if [[ -z "$group" ]]; then
    change "create external group $name with policy $policy" >&2
    if $DRY_RUN; then
      echo "<new>"
      return
    fi
    api POST "identity/group/name/$name" \
      "$(jq -n --arg p "$policy" '{type: "external", policies: [$p]}')" >/dev/null
    api GET "identity/group/name/$name" | jq -r .data.id
    return
  fi
  id="$(jq -r .data.id <<<"$group")"
  if [[ "$(jq -r .data.type <<<"$group")" != "external" ]]; then
    echo "  group $name exists but is not external, fix by hand" >&2
    exit 1
  fi
  if jq -e --arg p "$policy" '.data.policies | index($p) == null' <<<"$group" >/dev/null; then
    change "add policy $policy to group $name" >&2
    $DRY_RUN || api POST "identity/group/id/$id" \
      "$(jq -c --arg p "$policy" '{policies: ((.data.policies // []) + [$p])}' <<<"$group")" >/dev/null
  else
    echo "  ok        group $name" >&2
  fi
  echo "$id"
}

ensure_alias() {
  local name="$1" accessor="$2" group_name="$3" group_id="$4" aliases alias_id current
  aliases="$(api LIST identity/group-alias/id)"
  [[ -n "$aliases" ]] || aliases='{}'
  alias_id="$(jq -r --arg n "$name" --arg a "$accessor" \
    '(.data.key_info // {}) | to_entries[] | select(.value.name == $n and .value.mount_accessor == $a) | .key' \
    <<<"$aliases")"
  if [[ -z "$alias_id" ]]; then
    change "create alias $name on group $group_name"
    $DRY_RUN || api POST identity/group-alias "$(jq -n --arg n "$name" --arg a "$accessor" --arg g "$group_id" \
      '{name: $n, mount_accessor: $a, canonical_id: $g}')" >/dev/null
    return
  fi
  current="$(jq -r --arg id "$alias_id" '.data.key_info[$id].canonical_id' <<<"$aliases")"
  if [[ "$current" == "$group_id" ]]; then
    echo "  ok        alias $name on group $group_name"
    return
  fi
  change "move alias $name ($alias_id) from group $current to $group_name"
  $DRY_RUN || api POST "identity/group-alias/id/$alias_id" "$(jq -n --arg n "$name" --arg a "$accessor" --arg g "$group_id" \
    '{name: $n, mount_accessor: $a, canonical_id: $g}')" >/dev/null
}

accessor="$(api GET sys/auth | jq -r --arg m "$OIDC_MOUNT" '.data[$m].accessor // .[$m].accessor // empty')"
[[ -n "$accessor" ]] || { echo "no auth mount $OIDC_MOUNT on $VAULT_ADDR" >&2; exit 1; }

$DRY_RUN && echo "dry run: nothing is written"
for p in "${PROJECTS[@]}"; do
  echo "project $p"
  devs="$(api GET "identity/group/name/project-$p-devs" | jq -r '.data.id // empty')"
  if [[ -z "$devs" ]]; then
    echo "  skip: group project-$p-devs not found, project not bootstrapped" >&2
    continue
  fi

  ensure_policy "project-$p-read-policy" "$(read_policy "$p")"
  members="$(ensure_group "project-$p-members" "project-$p-read-policy")"
  ensure_alias "project-$p-members" "$accessor" "project-$p-members" "$members"
  ensure_alias "project-$p-admins" "$accessor" "project-$p-devs" "$devs"
done
