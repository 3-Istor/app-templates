
# Configure AWS Profile
export AWS_PROFILE="3-istor"

BUCKET="3-istor-tf-infra-aws"
PREFIX="cnp/"
REGION="eu-west-3"

# Resolve the absolute path of the repository root
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

source "$REPO_ROOT/scripts/secrets.sh"
REQUIRED_VARS=(
  "TF_VAR_github_token"
  "TF_VAR_vault_token"
  "TF_VAR_keycloak_admin_password"
  "TF_VAR_github_registry_token"
  "TF_VAR_cloudflare_api_token"
)

MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
  VAL="${!var}"
  if [ -z "$VAL" ] || \
     [ "$VAL" == "YOUR_GITHUB_TOKEN" ] || \
     [ "$VAL" == "YOUR_VAULT_TOKEN" ] || \
     [ "$VAL" == "YOUR_KEYCLOAK_ADMIN_PASSWORD" ] || \
     [ "$VAL" == "YOUR_GITHUB_REGISTRY_TOKEN" ] || \
     [ "$VAL" == "YOUR_CLOUDFLARE_API_TOKEN" ]; then
    MISSING_VARS+=("$var")
  fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
  echo "❌ Error: The following required environment variables are missing or still have placeholder values:"
  for var in "${MISSING_VARS[@]}"; do
    echo "   - $var"
  done
  echo ""
  echo "💡 Please edit the script header or export these variables in your shell before running."
  exit 1
fi

echo "🔍 Scanning S3 bucket ($BUCKET) for Terraform states using profile [$AWS_PROFILE]..."

# Retrieve the list of state keys and verify command success
STATE_FILES=$(aws s3api list-objects-v2 \
    --bucket "$BUCKET" \
    --prefix "$PREFIX" \
    --query "Contents[?ends_with(Key, '.tfstate')].Key" \
    --output text 2>/tmp/s3_error.log)

if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to list S3 bucket contents."
    cat /tmp/s3_error.log
    exit 1
fi

if [ -z "$STATE_FILES" ] || [ "$STATE_FILES" == "None" ]; then
    echo "✅ No state files found under prefix '$PREFIX'."
    exit 0
fi

# Arrays to classify states for ordered destruction
gitops_states=()
bootstrap_states=()

echo "📝 Analyzing states and extracting variables..."
for key in $STATE_FILES; do
    aws s3 cp "s3://$BUCKET/$key" /tmp/temp.tfstate --quiet
    if [ $? -ne 0 ]; then
        continue
    fi

    IS_GITOPS=$(jq 'contains({"resources": [{"type": "github_repository"}]})' /tmp/temp.tfstate)
    IS_BOOTSTRAP=$(jq 'contains({"resources": [{"type": "keycloak_group"}]})' /tmp/temp.tfstate)

    if [[ "$IS_GITOPS" == "true" ]]; then
        gitops_states+=("$key")
        echo "   -> Classified as GitOps: $key"
    elif [[ "$IS_BOOTSTRAP" == "true" ]]; then
        bootstrap_states+=("$key")
        echo "   -> Classified as Bootstrap: $key"
    else
        echo "   -> Skipped (empty or unknown state): $key"
    fi
done

# Function to run the terraform destroy command with extracted variables
destroy_state() {
    local key=$1
    local template_dir=$2
    local template_type=$3

    # Download the state file again locally to extract variables
    aws s3 cp "s3://$BUCKET/$key" /tmp/temp.tfstate --quiet

    # Save the root-level credentials to prevent unsetting them
    local tmp_github_token="$TF_VAR_github_token"
    local tmp_vault_token="$TF_VAR_vault_token"
    local tmp_keycloak_pwd="$TF_VAR_keycloak_admin_password"
    local tmp_registry_token="$TF_VAR_github_registry_token"
    local tmp_cf_token="$TF_VAR_cloudflare_api_token"

    # Reset metadata variables from the previous run
    unset TF_VAR_app_name
    unset TF_VAR_project_name
    unset TF_VAR_github_owner
    unset TF_VAR_template_repo_name
    unset TF_VAR_cloudflare_account_id
    unset TF_VAR_cloudflare_zone_id
    unset TF_VAR_app_type

    # Restore root-level credentials
    export TF_VAR_github_token="$tmp_github_token"
    export TF_VAR_vault_token="$tmp_vault_token"
    export TF_VAR_keycloak_admin_password="$tmp_keycloak_pwd"
    export TF_VAR_github_registry_token="$tmp_registry_token"
    export TF_VAR_cloudflare_api_token="$tmp_cf_token"

    if [ "$template_type" == "gitops" ]; then
        # 1. Extract app_name and project_name safely matching from the end of the Vault KV path
        VAULT_PATH=$(jq -r '.resources[] | select(.type == "vault_kv_secret_v2" and .name == "app_secrets") | .instances[0].attributes.path // empty' /tmp/temp.tfstate)

        if [ -n "$VAULT_PATH" ] && [ "$VAULT_PATH" != "null" ]; then
            APP_NAME=$(echo "$VAULT_PATH" | awk -F'/' '{print $NF}')
            PROJECT_NAME=$(echo "$VAULT_PATH" | awk -F'/' '{print $(NF-1)}')
        else
            # Fallback parsing from namespace metadata
            NS_NAME=$(jq -r '.resources[] | select(.type == "kubernetes_namespace_v1" and .name == "app_ns") | .instances[0].attributes.metadata[0].name // empty' /tmp/temp.tfstate)
            PROJECT_NAME=$(echo "$NS_NAME" | cut -d'-' -f1)
            APP_NAME=$(echo "$NS_NAME" | cut -d'-' -f2-)
        fi

        # Bulletproof fallback parsing directly from the S3 Key if the state variables are empty
        if [ -z "$APP_NAME" ] || [ "$APP_NAME" == "null" ]; then
            PROJECT_NAME=$(echo "$key" | awk -F'/' '{print $(NF-2)}')
            APP_NAME=$(echo "$key" | awk -F'/' '{print $(NF-1)}')
        fi

        # 2. Extract github_owner from repository URL
        GITHUB_OWNER=$(jq -r '.resources[] | select(.type == "github_repository" and .name == "app") | .instances[0].attributes.html_url // empty' /tmp/temp.tfstate | awk -F'/' '{print $4}')
        if [ -z "$GITHUB_OWNER" ] || [ "$GITHUB_OWNER" == "null" ]; then
            GITHUB_OWNER="3-Istor"
        fi

        # 3. Extract cloudflare_account_id
        CLOUDFLARE_ACCOUNT_ID=$(jq -r '.resources[] | select(.type == "cloudflare_zero_trust_tunnel_cloudflared" and .name == "app_tunnel") | .instances[0].attributes.account_id // empty' /tmp/temp.tfstate)

        # 4. Extract cloudflare_zone_id
        CLOUDFLARE_ZONE_ID=$(jq -r '.resources[] | select(.type == "cloudflare_dns_record" and .name == "app_cname") | .instances[0].attributes.zone_id // empty' /tmp/temp.tfstate)

        # 5. Extract app_type dynamically
        IS_FULLSTACK=$(jq -r '[.resources[] | select(.type == "kubernetes_manifest" and .name == "argocd_application") | .instances[].index_key] | contains(["frontend"])' /tmp/temp.tfstate)
        if [ "$IS_FULLSTACK" == "true" ]; then
            APP_TYPE="fullstack"
        else
            APP_TYPE="static"
        fi

        # Export variables
        export TF_VAR_app_name="$APP_NAME"
        export TF_VAR_project_name="$PROJECT_NAME"
        export TF_VAR_github_owner="$GITHUB_OWNER"
        export TF_VAR_template_repo_name="dummy"
        export TF_VAR_cloudflare_account_id="$CLOUDFLARE_ACCOUNT_ID"
        export TF_VAR_cloudflare_zone_id="$CLOUDFLARE_ZONE_ID"
        export TF_VAR_app_type="$APP_TYPE"

        echo "----------------------------------------"
        echo "🔥 Destroying GitOps App: $APP_NAME (Project: $PROJECT_NAME) [Type: $APP_TYPE]"

    elif [ "$template_type" == "bootstrap" ]; then
        # Extract project_name from keycloak group
        GROUP_NAME=$(jq -r '.resources[] | select(.type == "keycloak_group" and .name == "project_members") | .instances[0].attributes.name // empty' /tmp/temp.tfstate)
        PROJECT_NAME=$(echo "$GROUP_NAME" | sed 's/^project-//' | sed 's/-members$//')

        # Fallback to S3 key if empty
        if [ -z "$PROJECT_NAME" ] || [ "$PROJECT_NAME" == "null" ]; then
            PROJECT_NAME=$(echo "$key" | awk -F'/' '{print $(NF-1)}')
        fi

        export TF_VAR_project_name="$PROJECT_NAME"

        echo "----------------------------------------"
        echo "🔥 Destroying Bootstrap Project: $PROJECT_NAME [S3 Key: $key]"
    fi

    pushd "$template_dir" > /dev/null

    rm -rf .terraform .terraform.lock.hcl

    terraform init -upgrade -input=false \
        -backend-config="bucket=$BUCKET" \
        -backend-config="key=$key" \
        -backend-config="region=$REGION" \
        -backend-config="encrypt=true" > /dev/null

    if [ $? -eq 0 ]; then
        # 1. Strip kubernetes_manifest instances from the state to bypass plugin errors
        for res in $(terraform state list 2>/dev/null | grep 'kubernetes_manifest' || true); do
            echo "   -> Removing $res from state..."
            terraform state rm "$res" >/dev/null
        done

        # 2. Temporarily scrub kubernetes_manifest blocks from the local .tf file
        #    so the Provider doesn't try to validate the CRD with the API Server
        if [ -f main.tf ]; then
            cp main.tf main.tf.bak
            awk '
            BEGIN { skip=0; brace_count=0 }
            /resource "kubernetes_manifest"/ { skip=1 }
            skip==1 {
                s = $0
                open = gsub(/\{/, "{", s)
                close = gsub(/\}/, "}", s)
                brace_count += (open - close)
                if (brace_count == 0) skip=0
                next
            }
            { print $0 }
            ' main.tf.bak > main.tf
        fi

        # 3. Destroy what is left WITH state refresh
        terraform destroy -auto-approve -input=false

        # 4. Safely restore the original .tf files so future executions remain completely untouched
        if [ -f main.tf.bak ]; then
            mv main.tf.bak main.tf
        fi
    else
        echo "❌ Failed to initialize backend for: $key"
    fi

    popd > /dev/null
}

# 1. Destroy GitOps Applications first
if [ ${#gitops_states[@]} -gt 0 ]; then
    echo "========================================"
    echo "🚀 Phase 1: Destroying GitOps Applications"
    echo "========================================"
    for key in "${gitops_states[@]}"; do
        destroy_state "$key" "$REPO_ROOT/templates/k3s-gitops-app" "gitops"
    done
fi

# 2. Destroy Project Bootstraps second
if [ ${#bootstrap_states[@]} -gt 0 ]; then
    echo "========================================"
    echo "🚀 Phase 2: Destroying Project Bootstraps"
    echo "========================================"
    for key in "${bootstrap_states[@]}"; do
        destroy_state "$key" "$REPO_ROOT/templates/k3s-project-bootstrap" "bootstrap"
    done
fi

# Clean local temporary state and variables
rm -f /tmp/temp.tfstate /tmp/s3_error.log
unset TF_VAR_app_name
unset TF_VAR_project_name
unset TF_VAR_github_owner
unset TF_VAR_template_repo_name
unset TF_VAR_cloudflare_account_id
unset TF_VAR_cloudflare_zone_id
unset TF_VAR_app_type
unset TF_VAR_github_token
unset TF_VAR_vault_token
unset TF_VAR_keycloak_admin_password
unset TF_VAR_github_registry_token
unset TF_VAR_cloudflare_api_token

echo "----------------------------------------"
echo "🎉 Cleanup completed!"
