#!/usr/bin/env bash
# Moves every project-* mount to <app>/<prod|staging>/{secrets,registry,...}.
#   plan     print what copy and cleanup would do (default)
#   copy     write the new paths, never overwrite one that exists
#   cleanup  delete the old paths once copy was checked
# Optional mounts after the mode limit the run (default: every project-*).
# Needs the vault-data elevation (CNP-124) to reach every project. Values only
# travel through pipes, never to disk or stdout.
set -euo pipefail
mode="${1:-plan}"
shift || true
: "${VAULT_ADDR:?set VAULT_ADDR}"

# Fixed moves outside the generic rule: "mount src dst".
EXTRA="project-iot optispace-demo-accounts-staging optispace/staging/demo-accounts"
# Leftovers of the pre-#26 imports layout, nothing reads them.
DROP_PREFIX="system/imports/"
PROJECT_FOLDERS=" system _staging-realm backups keycloak-tenant-admin keycloak-tenant-admin-staging "

list() { vault kv list -format=json -mount="$1" "${2:-}" 2>/dev/null | jq -r '.[]' || true; }
exists() { vault kv metadata get -mount="$1" "$2" >/dev/null 2>&1; }

plan_mount() {
  local m=$1 e name c
  while read -r line; do [[ $line == "$m "* ]] && echo "${line#"$m "}"; done <<<"$EXTRA"
  for e in $(list "$m"); do
    name=${e%/}
    [[ $PROJECT_FOLDERS == *" $name "* ]] && continue
    [[ $EXTRA == *"$m $name "* ]] && continue
    if [[ $e != */ ]]; then
      echo "$name $name/prod/secrets"
      continue
    fi
    for c in $(list "$m" "$e"); do
      case $c in
        registry | backup | bucket | ai-oidc) echo "$name/$c $name/prod/$c" ;;
        imports | secrets) echo "$name/$c $name/prod/secrets" ;;
        staging) echo "$name/staging $name/staging/secrets" ;;
        staging/ | prod/) ;;
        *) echo "WARN $m/$name/$c: unknown, left as is" >&2 ;;
      esac
    done
  done
}

copy_one() {
  local m=$1 src=$2 dst=$3 cm
  if exists "$m" "$dst"; then echo "  skip $m/$dst (exists)"; return; fi
  vault kv get -format=json -mount="$m" "$src" | jq '.data.data' | vault kv put -mount="$m" "$dst" - >/dev/null
  cm=$(vault kv metadata get -format=json -mount="$m" "$src" | jq -r '.data.custom_metadata // {} | to_entries[] | "-custom-metadata=\(.key)=\(.value)"')
  [ -n "$cm" ] && vault kv metadata put -mount="$m" $cm "$dst" >/dev/null
  echo "  copy $m/$src -> $dst"
}

for m in ${*:-$(vault secrets list -format=json | jq -r 'keys[] | select(startswith("project-")) | rtrimstr("/")')}; do
  moves=$(plan_mount "$m")
  dsts=$(awk '{print $2}' <<<"$moves" | sort)
  if [ -n "$dsts" ] && [ "$(uniq -d <<<"$dsts")" ]; then
    echo "ABORT $m: two sources for $(uniq -d <<<"$dsts" | tr '\n' ' ')" >&2; exit 1
  fi
  drops=$(list "$m" "$DROP_PREFIX" | sed "s#^#$DROP_PREFIX#")
  [ -z "$moves$drops" ] && continue
  echo "== $m"
  while read -r src dst; do
    [ -z "$src" ] && continue
    case $mode in
      plan) echo "  $src -> $dst" ;;
      copy) copy_one "$m" "$src" "$dst" ;;
      cleanup)
        exists "$m" "$dst" || { echo "  KEEP $m/$src: $dst missing" >&2; continue; }
        vault kv metadata delete -mount="$m" "$src" >/dev/null && echo "  delete $m/$src" ;;
    esac
  done <<<"$moves"
  for d in $drops; do
    case $mode in
      plan) echo "  drop $d" ;;
      cleanup) vault kv metadata delete -mount="$m" "$d" >/dev/null && echo "  delete $m/$d" ;;
    esac
  done
done
