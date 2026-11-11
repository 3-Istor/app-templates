#!/usr/bin/env bash
#
# keycloak-split-realm-admin: one-off migration for project realms created
# before the modules mapped realm-admin role by role. On the tenant admin user
# "admin" and the group "project-admins" of each realm, maps the roles of
# realm-admin but impersonation, then removes realm-admin.
#
# Run it with the master admin, before the CMP switches to cmp-provisioner: the
# provisioner may not unmap realm-admin (403), so its next apply of
# project-bootstrap or staging-realm would fail on these realms.
#
# Idempotent. Reads KEYCLOAK_URL and KEYCLOAK_ADMIN_PASSWORD (and optionally
# KEYCLOAK_ADMIN_USERNAME, default admin) from the environment.
#
#   ./keycloak-split-realm-admin.sh --dry-run          # iot iot-staging joetest self-runner self-runner-staging test-link
#   ./keycloak-split-realm-admin.sh iot iot-staging
#
set -euo pipefail

readonly DEFAULT_REALMS=(iot iot-staging joetest self-runner self-runner-staging test-link)

# Must match local.tenant_admin_roles in templates/project-bootstrap/main.tf
# and local.admin_roles in templates/k3s-gitops-app/staging-realm/main.tf.
readonly ADMIN_ROLES=(
  create-client
  manage-authorization
  manage-clients
  manage-events
  manage-identity-providers
  manage-organizations
  manage-realm
  manage-users
  query-clients
  query-groups
  query-organizations
  query-realms
  query-users
  view-authorization
  view-clients
  view-events
  view-identity-providers
  view-organizations
  view-realm
  view-users
)

DRY_RUN=false
REALMS=()

usage() {
  sed -n '3,17p' "$0" | sed 's/^# \{0,1\}//'
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -h | --help) usage; exit 0 ;;
    -*) echo "unknown flag: $arg" >&2; exit 2 ;;
    *) REALMS+=("$arg") ;;
  esac
done
[[ ${#REALMS[@]} -eq 0 ]] && REALMS=("${DEFAULT_REALMS[@]}")

: "${KEYCLOAK_URL:?KEYCLOAK_URL must be set}"
: "${KEYCLOAK_ADMIN_PASSWORD:?KEYCLOAK_ADMIN_PASSWORD must be set}"
KEYCLOAK_ADMIN_USERNAME="${KEYCLOAK_ADMIN_USERNAME:-admin}"
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }
command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }

# The password goes to curl on stdin so it never shows in `ps`.
TOKEN="$(
  jq -rn --arg u "$KEYCLOAK_ADMIN_USERNAME" --arg p "$KEYCLOAK_ADMIN_PASSWORD" \
    '"grant_type=password&client_id=admin-cli&username=\($u|@uri)&password=\($p|@uri)"' |
    curl -sSf --data @- "${KEYCLOAK_URL%/}/realms/master/protocol/openid-connect/token" |
    jq -r .access_token
)"
readonly TOKEN

# Prints the body on 2xx, nothing on 404, aborts otherwise.
api() {
  local method="$1" path="$2" body="${3:-}" out code
  local args=(-sS -X "$method" -H @- -w '\n%{http_code}' "${KEYCLOAK_URL%/}/admin/realms/$path")
  [[ -n "$body" ]] && args+=(-H 'Content-Type: application/json' --data "$body")
  out="$(printf 'Authorization: Bearer %s\n' "$TOKEN" | curl "${args[@]}")"
  code="${out##*$'\n'}"
  out="${out%$'\n'*}"
  case "$code" in
    2??) printf '%s' "$out" ;;
    404) ;;
    *)
      echo "keycloak: $method $path returned $code: $out" >&2
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

# $1 realm, $2 label, $3 role-mappings path of the user or group, $4 client id
# of realm-management, $5 its roles as a JSON array.
split() {
  local realm="$1" label="$2" mapping="$3" rm="$4" roles="$5" have missing admin
  have="$(api GET "$mapping/clients/$rm" | jq -c '[.[].name]')"
  missing="$(jq -c --argjson have "$have" --args \
    '[.[] | select(.name as $n | ($ARGS.positional | index($n)) and ($have | index($n) | not))]' \
    "${ADMIN_ROLES[@]}" <<<"$roles")"
  if [[ "$missing" != "[]" ]]; then
    change "$label: map $(jq -r 'map(.name) | join(" ")' <<<"$missing")"
    $DRY_RUN || api POST "$mapping/clients/$rm" "$missing" >/dev/null
  fi
  admin="$(jq -c '[.[] | select(.name == "realm-admin")]' <<<"$roles")"
  if jq -e 'index("realm-admin")' <<<"$have" >/dev/null; then
    change "$label: remove realm-admin"
    $DRY_RUN || api DELETE "$mapping/clients/$rm" "$admin" >/dev/null
  fi
  [[ "$missing" == "[]" ]] && ! jq -e 'index("realm-admin")' <<<"$have" >/dev/null && echo "  ok        $label"
  return 0
}

$DRY_RUN && echo "dry run: nothing is written"
for realm in "${REALMS[@]}"; do
  echo "realm $realm"
  if [[ -z "$(api GET "$realm")" ]]; then
    echo "  skip: realm not found" >&2
    continue
  fi
  rm="$(api GET "$realm/clients?clientId=realm-management" | jq -r '.[0].id')"
  roles="$(api GET "$realm/clients/$rm/roles")"

  user="$(api GET "$realm/users?username=admin&exact=true" | jq -r '.[0].id // empty')"
  if [[ -n "$user" ]]; then
    split "$realm" "user admin" "$realm/users/$user/role-mappings" "$rm" "$roles"
  else
    echo "  skip: no user admin" >&2
  fi

  group="$(api GET "$realm/groups?search=project-admins&exact=true" |
    jq -r '[.[] | select(.name == "project-admins")][0].id // empty')"
  if [[ -n "$group" ]]; then
    split "$realm" "group project-admins" "$realm/groups/$group/role-mappings" "$rm" "$roles"
  else
    echo "  skip: no group project-admins" >&2
  fi
done
