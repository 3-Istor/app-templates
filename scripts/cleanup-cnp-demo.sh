export AWS_PROFILE="3-istor"
BUCKET="3-istor-tf-infra-aws"
PREFIX="cnp/"
REGION="eu-west-3"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

echo "🔍 Loading secrets from secrets.sh..."
source "$REPO_ROOT/scripts/secrets.sh"

REQUIRED_VARS=(
  "TF_VAR_github_token"
  "TF_VAR_vault_token"
  "TF_VAR_keycloak_admin_password"
  "TF_VAR_github_registry_token"
  "TF_VAR_cloudflare_api_token"
  "TF_VAR_cloudflare_account_id"
  "TF_VAR_cloudflare_zone_id"
  "TF_VAR_vault_url"
  "TF_VAR_keycloak_url"
  "TF_VAR_keycloak_admin_username"
  "TF_VAR_github_installation_id"
  "TF_VAR_github_app_private_key"
)

MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
  VAL="${!var}"
  if [ -z "$VAL" ] || [[ "$VAL" == YOUR_* ]]; then
    MISSING_VARS+=("$var")
  fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
  echo "❌ Error: The following required environment variables are missing or still have placeholder values:"
  for var in "${MISSING_VARS[@]}"; do
    echo "   - $var"
  done
  echo ""
  echo "💡 Please edit your scripts/secrets.sh file and export these variables before running."
  exit 1
fi

export VAULT_ADDR="$TF_VAR_vault_url"
export VAULT_TOKEN="$TF_VAR_vault_token"

echo "✅ All secrets loaded."
echo "🔍 Scanning S3 bucket ($BUCKET) for Terraform states..."

STATE_FILES=$(aws s3api list-objects-v2 \
    --bucket "$BUCKET" \
    --prefix "$PREFIX" \
    --query "Contents[?ends_with(Key, '.tfstate')].Key" \
    --output text)

if [ -z "$STATE_FILES" ] || [ "$STATE_FILES" == "None" ]; then
    echo "✅ No state files found."
    exit 0
fi

gitops_states=()
bootstrap_states=()

for key in $STATE_FILES; do
    aws s3 cp "s3://$BUCKET/$key" /tmp/temp.tfstate --quiet || continue

    IS_GITOPS=$(jq 'contains({"resources": [{"type": "github_repository"}]})' /tmp/temp.tfstate)
    IS_BOOTSTRAP=$(jq 'contains({"resources": [{"type": "keycloak_group"}]})' /tmp/temp.tfstate)

    if [[ "$IS_GITOPS" == "true" ]]; then
        gitops_states+=("$key")
    elif [[ "$IS_BOOTSTRAP" == "true" ]]; then
        bootstrap_states+=("$key")
    fi
done

destroy_state() {
    local key=$1
    local template_dir=$2
    local template_type=$3

    aws s3 cp "s3://$BUCKET/$key" /tmp/temp.tfstate --quiet

    if [ "$template_type" == "gitops" ]; then
        VAULT_PATH=$(jq -r '.resources[] | select(.type == "vault_kv_secret_v2" and .name == "app_secrets") | .instances[0].attributes.path // empty' /tmp/temp.tfstate)

        if [ -n "$VAULT_PATH" ]; then
            APP_NAME=$(echo "$VAULT_PATH" | awk -F'/' '{print $NF}')
            PROJECT_NAME=$(echo "$VAULT_PATH" | awk -F'/' '{print $(NF-1)}')
        else
            PROJECT_NAME=$(echo "$key" | awk -F'/' '{print $(NF-2)}')
            APP_NAME=$(echo "$key" | awk -F'/' '{print $(NF-1)}' | sed 's/\.tfstate//')
        fi

        export TF_VAR_app_name="$APP_NAME"
        export TF_VAR_project_name="$PROJECT_NAME"
        export TF_VAR_github_owner="3-Istor"
        export TF_VAR_template_repo_name="dummy"
        export TF_VAR_app_type="static"

        echo "🔥 Destroying GitOps App: $APP_NAME (Project: $PROJECT_NAME)"

    elif [ "$template_type" == "bootstrap" ]; then
        GROUP_NAME=$(jq -r '.resources[] | select(.type == "keycloak_group" and .name == "project_members") | .instances[0].attributes.name // empty' /tmp/temp.tfstate)
        PROJECT_NAME=$(echo "$GROUP_NAME" | sed 's/^project-//' | sed 's/-members$//')

        if [ -z "$PROJECT_NAME" ]; then
            PROJECT_NAME=$(echo "$key" | awk -F'/' '{print $(NF-1)}')
        fi

        export TF_VAR_project_name="$PROJECT_NAME"
        echo "🔥 Destroying Bootstrap Project: $PROJECT_NAME"
    fi

    pushd "$template_dir" > /dev/null
    rm -rf .terraform .terraform.lock.hcl

    terraform init -upgrade -input=false \
        -backend-config="bucket=$BUCKET" \
        -backend-config="key=$key" \
        -backend-config="region=$REGION" \
        -backend-config="encrypt=true" > /dev/null

    if [ $? -eq 0 ]; then
        terraform destroy -auto-approve -input=false
    else
        echo "❌ Failed to initialize backend for: $key"
    fi
    popd > /dev/null
}

if [ ${#gitops_states[@]} -gt 0 ]; then
    echo "========================================"
    echo "🚀 Phase 1: Destroying GitOps Applications"
    echo "========================================"
    for key in "${gitops_states[@]}"; do
        destroy_state "$key" "$REPO_ROOT/templates/k3s-gitops-app" "gitops"
    done
fi

if [ ${#bootstrap_states[@]} -gt 0 ]; then
    echo "========================================"
    echo "🚀 Phase 2: Destroying Project Bootstraps"
    echo "========================================"
    for key in "${bootstrap_states[@]}"; do
        destroy_state "$key" "$REPO_ROOT/templates/k3s-project-bootstrap" "bootstrap"
    done
fi

rm -f /tmp/temp.tfstate
echo "🎉 Cleanup completed!"
