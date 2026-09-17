#!/usr/bin/env bash
#
# cnp-clean — destroy everything CNP provisioned for a project, or for a whole
# cloud, and report anything left behind.
#
# Successor to cleanup-cnp-demo.sh, which destroyed every state it could find in
# the bucket with no way to say "only this project" or "only this cloud".
#
# This is a deleter, not a reporter. The guardrails are that the scope is always
# explicit, that dry-run is the default, and that the inventory runs both before
# and after — a resource created by hand is not found by the destroy phase, but
# it is found by the inventory if it carries the markers.
#
#   ./cnp-clean.sh --project sandbox                 # show what would be destroyed
#   ./cnp-clean.sh --project sandbox --yes           # destroy it
#   ./cnp-clean.sh --cloud aws --yes                 # retire a cloud
#   ./cnp-clean.sh --all --inventory-only            # orphan report, all clouds
#
set -euo pipefail

# Provider credentials. Declared here so the contract is visible in one place;
# scripts/secrets.sh (gitignored) supplies the real values, and load_secrets
# refuses to continue if any is still empty or a placeholder.
TF_VAR_vault_url="${TF_VAR_vault_url:-}"
TF_VAR_vault_token="${TF_VAR_vault_token:-}"
TF_VAR_keycloak_url="${TF_VAR_keycloak_url:-}"
TF_VAR_keycloak_admin_password="${TF_VAR_keycloak_admin_password:-}"
TF_VAR_cloudflare_api_token="${TF_VAR_cloudflare_api_token:-}"
TF_VAR_cloudflare_account_id="${TF_VAR_cloudflare_account_id:-}"
TF_VAR_cloudflare_zone_id="${TF_VAR_cloudflare_zone_id:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly SCRIPT_DIR REPO_ROOT

readonly CLOUDS=(onprem aws gcp)
readonly BUCKET="${TF_BACKEND_S3_BUCKET:-3-istor-tf-infra-aws}"
readonly REGION="${TF_BACKEND_AWS_REGION:-eu-west-3}"
readonly REGISTRY_REPO="${CNP_REGISTRY_REPO:-3-Istor/cnp-projects}"
readonly REGISTRY_PREFIX="registry/projects"

SCOPE=""
SCOPE_VALUE=""
CONFIRMED=false
INVENTORY_ONLY=false
KEEP_REGISTRY=false

# ─────────────────────────────────────────────────────────────────────────────
# Output
# ─────────────────────────────────────────────────────────────────────────────

log()  { printf '%s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

# In dry-run, say what would happen instead of doing it.
run() {
  if [ "$CONFIRMED" = true ]; then
    "$@"
  else
    printf '   would run: %s\n' "$*"
  fi
}

usage() {
  # The header comment block, however long it grows — not a hardcoded range.
  sed -n '2,/^[^#]/p' "${BASH_SOURCE[0]}" | sed '$d' | sed 's|^# \{0,1\}||'
  cat <<'EOF'

Scope (exactly one is required — there is no scope-less invocation):
  --project <name>     one project and all of its applications
  --cloud <name>       every project whose target_cloud is <name>
  --all                every project on every cloud

Options:
  --yes                actually destroy. Without it, nothing is changed.
  --inventory-only     stop after the inventory, even with --yes
  --keep-registry      destroy resources but leave the Git registry record
  -h, --help           this text
EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────────────────────────

set_scope() {
  [ -z "$SCOPE" ] || die "scope already set to --$SCOPE; pass exactly one of --project, --cloud, --all"
  SCOPE="$1"
  SCOPE_VALUE="${2-}"
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --project) [ $# -ge 2 ] || die "--project needs a name"; set_scope project "$2"; shift 2 ;;
      --cloud)   [ $# -ge 2 ] || die "--cloud needs a name";   set_scope cloud "$2";   shift 2 ;;
      --all)     set_scope all ""; shift ;;
      --yes)             CONFIRMED=true;      shift ;;
      --inventory-only)  INVENTORY_ONLY=true; shift ;;
      --keep-registry)   KEEP_REGISTRY=true;  shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown argument: $1" ;;
    esac
  done

  [ -n "$SCOPE" ] || { usage; exit 2; }

  if [ "$SCOPE" = "cloud" ]; then
    local known=false
    for c in "${CLOUDS[@]}"; do [ "$c" = "$SCOPE_VALUE" ] && known=true; done
    [ "$known" = true ] || die "unknown cloud '$SCOPE_VALUE' (expected one of: ${CLOUDS[*]})"
  fi
}

require_tools() {
  local missing=()
  for tool in aws curl jq terraform gh kubectl; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  [ ${#missing[@]} -eq 0 ] || die "missing required tools: ${missing[*]}"
}

load_secrets() {
  local secrets="$REPO_ROOT/scripts/secrets.sh"
  [ -f "$secrets" ] || die "no $secrets — the destroy phase needs provider credentials"
  # shellcheck source=/dev/null
  source "$secrets"

  local required=(
    TF_VAR_vault_token TF_VAR_keycloak_admin_password
    TF_VAR_cloudflare_api_token TF_VAR_cloudflare_account_id
    TF_VAR_cloudflare_zone_id TF_VAR_vault_url TF_VAR_keycloak_url
  )
  local missing=()
  for var in "${required[@]}"; do
    local value="${!var-}"
    if [ -z "$value" ] || [[ "$value" == YOUR_* ]]; then missing+=("$var"); fi
  done
  [ ${#missing[@]} -eq 0 ] || die "unset or placeholder in secrets.sh: ${missing[*]}"

  export VAULT_ADDR="$TF_VAR_vault_url"
  export VAULT_TOKEN="$TF_VAR_vault_token"
}

# ─────────────────────────────────────────────────────────────────────────────
# Discovery
# ─────────────────────────────────────────────────────────────────────────────

# State keys are laid out cmp/<cloud>/projects/<project>/... (D-09), which makes
# a per-cloud inventory a prefix listing rather than a scan of every state in the
# bucket followed by guessing what it is from its contents.
list_projects_on_cloud() {
  local cloud="$1"
  aws s3api list-objects-v2 \
    --bucket "$BUCKET" --region "$REGION" \
    --prefix "cmp/$cloud/projects/" --delimiter "/" \
    --query 'CommonPrefixes[].Prefix' --output text 2>/dev/null \
    | tr '\t' '\n' | grep -vxE '(None)?' \
    | sed -n "s|cmp/$cloud/projects/\(.*\)/|\1|p" | sort -u
}

list_app_states() {
  local cloud="$1" project="$2"
  # --output text prints the literal string "None" for an empty result, which is
  # indistinguishable from a key unless it is filtered out here. Letting it
  # through means running terraform destroy against a state key called "None".
  aws s3api list-objects-v2 \
    --bucket "$BUCKET" --region "$REGION" \
    --prefix "cmp/$cloud/projects/$project/apps/" \
    --query "Contents[?ends_with(Key, '.tfstate')].Key" --output text 2>/dev/null \
    | tr '\t' '\n' | grep -vxE '(None)?' || true
}

state_exists() {
  aws s3api head-object --bucket "$BUCKET" --region "$REGION" --key "$1" >/dev/null 2>&1
}

# Which cloud a project is on. The Git registry is the source of truth (D-01);
# the state layout is the fallback for a project whose record is already gone.
cloud_of_project() {
  local project="$1" record cloud
  if record=$(gh api "repos/$REGISTRY_REPO/contents/$REGISTRY_PREFIX/$project.yaml" \
                --jq '.content' 2>/dev/null); then
    cloud=$(printf '%s' "$record" | base64 -d | sed -n 's/^ *targetCloud: *//p' | tr -d '"'"'"' ' | head -1)
    if [ -n "$cloud" ]; then printf '%s' "$cloud"; return 0; fi
  fi

  for c in "${CLOUDS[@]}"; do
    if state_exists "cmp/$c/projects/$project/bootstrap.tfstate"; then
      warn "project '$project' has no registry record; found its state on '$c'"
      printf '%s' "$c"
      return 0
    fi
  done

  return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# Inventory — what is out there carrying this project's markers
# ─────────────────────────────────────────────────────────────────────────────

inventory_project() {
  local cloud="$1" project="$2" found=0

  log "   terraform states:"
  local app_states
  app_states=$(list_app_states "$cloud" "$project")
  if [ -n "$app_states" ]; then
    while IFS= read -r key; do log "     app       $key"; found=$((found + 1)); done <<<"$app_states"
  fi
  if state_exists "cmp/$cloud/projects/$project/bootstrap.tfstate"; then
    log "     bootstrap cmp/$cloud/projects/$project/bootstrap.tfstate"
    found=$((found + 1))
  fi
  [ "$found" -gt 0 ] || log "     (none)"

  log "   cloudflare dns:"
  local dns
  dns=$(curl -sf -X GET \
    "https://api.cloudflare.com/client/v4/zones/$TF_VAR_cloudflare_zone_id/dns_records?per_page=500" \
    -H "Authorization: Bearer $TF_VAR_cloudflare_api_token" 2>/dev/null \
    | jq -r --arg p "$project" \
        '.result[]? | select((.comment // "") | contains("cnp.project=" + $p)) | "     " + .name' || true)
  if [ -n "$dns" ]; then log "$dns"; found=$((found + 1)); else log "     (none carrying cnp.project=$project)"; fi

  log "   vault:"
  if vault secrets list -format=json 2>/dev/null | jq -e --arg m "project-$project/" 'has($m)' >/dev/null; then
    log "     mount project-$project"
    found=$((found + 1))
  else
    log "     (no mount project-$project)"
  fi

  log "   argocd:"
  local argocd_found=0
  if kubectl get appproject "$project" -n argocd >/dev/null 2>&1; then
    log "     AppProject/$project"
    argocd_found=$((argocd_found + 1))
  fi
  local app_count
  app_count=$(kubectl get applications -n argocd -l "cnp.3istor.com/project=$project" \
    --no-headers 2>/dev/null | wc -l)
  if [ "$app_count" -gt 0 ]; then
    log "     $app_count Application(s) still present"
    argocd_found=$((argocd_found + app_count))
  fi
  [ "$argocd_found" -gt 0 ] || log "     (none)"
  found=$((found + argocd_found))

  return "$found"
}

# ─────────────────────────────────────────────────────────────────────────────
# Destroy
# ─────────────────────────────────────────────────────────────────────────────

terraform_destroy_state() {
  local module_dir="$1" key="$2"
  shift 2

  if [ "$CONFIRMED" != true ]; then
    printf '   would destroy: %s (module %s)\n' "$key" "$(basename "$module_dir")"
    return 0
  fi

  local data_dir
  data_dir=$(mktemp -d)
  # shellcheck disable=SC2064  # expand data_dir now, not at trap time
  trap "rm -rf '$data_dir'" RETURN

  TF_DATA_DIR="$data_dir/.terraform" \
  TF_IN_AUTOMATION=1 TF_INPUT=0 \
  terraform -chdir="$module_dir" init -input=false -reconfigure \
    -backend-config="bucket=$BUCKET" \
    -backend-config="key=$key" \
    -backend-config="region=$REGION" \
    -backend-config="encrypt=true" \
    ${TF_BACKEND_S3_DYNAMODB_TABLE:+-backend-config="dynamodb_table=$TF_BACKEND_S3_DYNAMODB_TABLE"} \
    >/dev/null

  TF_DATA_DIR="$data_dir/.terraform" \
  TF_IN_AUTOMATION=1 TF_INPUT=0 \
  terraform -chdir="$module_dir" destroy -auto-approve -input=false "$@"
}

# Removing the record is what makes the generated Applications and the AppProject
# disappear, so it happens before the bootstrap destroy rather than after — Argo
# CD would otherwise re-create what Terraform has just removed.
deregister_project() {
  local project="$1"
  if [ "$KEEP_REGISTRY" = true ]; then
    log "   registry record kept (--keep-registry)"
    return 0
  fi

  local path="$REGISTRY_PREFIX/$project.yaml" sha
  if ! sha=$(gh api "repos/$REGISTRY_REPO/contents/$path" --jq '.sha' 2>/dev/null); then
    log "   no registry record to remove"
    return 0
  fi

  run gh api -X DELETE "repos/$REGISTRY_REPO/contents/$path" \
    -f message="chore(registry): deregister project $project [skip ci]" \
    -f sha="$sha"
}

clean_project() {
  local cloud="$1" project="$2"

  step "project '$project' on '$cloud'"
  inventory_project "$cloud" "$project" || true

  [ "$INVENTORY_ONLY" = false ] || return 0

  log "   -- destroying applications"
  local app_states
  app_states=$(list_app_states "$cloud" "$project")
  if [ -n "$app_states" ]; then
    while IFS= read -r key; do
      local app
      app=$(basename "$key" .tfstate)
      terraform_destroy_state "$REPO_ROOT/templates/k3s-gitops-app" "$key" \
        -var="project_name=$project" \
        -var="app_name=$app" \
        -var="target_cloud=$cloud" \
        -var="github_owner=3-Istor" \
        -var="template_repo_name=unused-on-destroy"
    done <<<"$app_states"
  else
    log "   (no application states)"
  fi

  log "   -- deregistering from Git"
  deregister_project "$project"

  log "   -- destroying project bootstrap"
  local bootstrap_key="cmp/$cloud/projects/$project/bootstrap.tfstate"
  if state_exists "$bootstrap_key"; then
    terraform_destroy_state "$REPO_ROOT/templates/project-bootstrap" "$bootstrap_key" \
      -var="project_name=$project" \
      -var="target_cloud=$cloud"
  else
    log "   (no bootstrap state)"
  fi

  log "   -- removing the orphaned AppProject"
  remove_orphaned_appproject "$project"
}

# Deregistering a project (above) deletes its <project>-appproject Application,
# but not the AppProject object itself: cnp-project-appprojects runs with
# preserveResourcesOnDeletion: true specifically so the AppProject survives
# long enough for the project's other Applications to finish their own
# deletion — each of them needs "get app project <name>" to succeed to clear
# their resources-finalizer, and if the AppProject is gone first they hang in
# Terminating permanently (found live, K3s#52).
#
# That makes this step's ordering non-optional: wait for the project's
# Applications to actually disappear before deleting the AppProject by hand,
# or this reintroduces the exact deadlock the preserveResourcesOnDeletion
# setting exists to avoid.
remove_orphaned_appproject() {
  local project="$1"

  if [ "$CONFIRMED" != true ]; then
    log "     would wait for Applications to clear, then: kubectl delete appproject $project -n argocd"
    return 0
  fi

  local waited=0 remaining
  while [ "$waited" -lt 300 ]; do
    remaining=$(kubectl get applications -n argocd \
      -l "cnp.3istor.com/project=$project" --no-headers 2>/dev/null | wc -l)
    [ "$remaining" -eq 0 ] && break
    sleep 10
    waited=$((waited + 10))
  done

  if [ "$remaining" -gt 0 ]; then
    warn "$remaining Application(s) for '$project' still present after ${waited}s — leaving its AppProject in place rather than risk the deadlock. Re-run cnp-clean for this project once they clear."
    return 0
  fi

  if kubectl get appproject "$project" -n argocd >/dev/null 2>&1; then
    kubectl delete appproject "$project" -n argocd
  else
    log "     no AppProject left to remove"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

collect_targets() {
  case "$SCOPE" in
    project)
      local cloud
      cloud=$(cloud_of_project "$SCOPE_VALUE") \
        || die "cannot determine which cloud '$SCOPE_VALUE' is on: no registry record and no state in $BUCKET"
      printf '%s %s\n' "$cloud" "$SCOPE_VALUE"
      ;;
    cloud)
      while IFS= read -r p; do
        [ -n "$p" ] && printf '%s %s\n' "$SCOPE_VALUE" "$p"
      done < <(list_projects_on_cloud "$SCOPE_VALUE")
      ;;
    all)
      for c in "${CLOUDS[@]}"; do
        while IFS= read -r p; do
          [ -n "$p" ] && printf '%s %s\n' "$c" "$p"
        done < <(list_projects_on_cloud "$c")
      done
      ;;
  esac
}

main() {
  parse_args "$@"
  require_tools
  load_secrets

  local targets
  targets=$(collect_targets)

  if [ -z "$targets" ]; then
    log "Nothing in scope. Nothing to do."
    exit 0
  fi

  step "scope: --$SCOPE ${SCOPE_VALUE}"
  log "$targets" | while read -r cloud project; do log "   $project ($cloud)"; done

  if [ "$CONFIRMED" != true ]; then
    log ""
    log "DRY RUN — nothing will be changed. Re-run with --yes to destroy."
  fi

  while read -r cloud project; do
    clean_project "$cloud" "$project"
  done <<<"$targets"

  if [ "$INVENTORY_ONLY" = true ]; then
    step "inventory complete"
    exit 0
  fi

  # The inventory runs again afterwards because the destroy phase only knows
  # about what is in Terraform state. Anything created by hand shows up here if
  # it carries the markers — which is the whole reason for the markers.
  step "final inventory — expected to be empty"
  local remaining=0
  while read -r cloud project; do
    log " $project ($cloud):"
    inventory_project "$cloud" "$project" || remaining=$((remaining + $?))
  done <<<"$targets"

  if [ "$CONFIRMED" = true ] && [ "$remaining" -gt 0 ]; then
    warn "$remaining object(s) still present — these are orphans, investigate before retrying"
    exit 1
  fi

  step "done"
}

main "$@"
