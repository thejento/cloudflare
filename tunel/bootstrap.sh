#!/bin/bash

# This script automates the deployment of the Cloudflared tunnel.
# It assumes that 'cloudflared', 'kubectl' and 'jq' are installed and configured.

# --- Colors for output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# --- Script functions ---
info() {
    printf "${GREEN}[INFO] %s${NC}\n" "$1"
}

warn() {
    printf "${YELLOW}[WARNING] %s${NC}\n" "$1"
}

error() {
    printf "${RED}[ERROR] %s${NC}\n" "$1"
    exit 1
}

check_dep() {
    if ! command -v "$1" &> /dev/null; then
        error "$1 could not be found. Please install it before running this script."
    fi
}

# --- Check dependencies ---
check_dep "kubectl"
check_dep "cloudflared"
check_dep "jq"


# --- Main script ---

# 1. Cloudflare Login
info "Please run 'cloudflared tunnel login' in another terminal if you haven't already."
read -p "Press [Enter] to continue once you have logged in..."

# 2. Tunnel Configuration
TUNNEL_NAME="public-home-lab"
info "Checking for Cloudflare tunnel '$TUNNEL_NAME'..."

if ! cloudflared tunnel list | grep -q "$TUNNEL_NAME"; then
    info "Tunnel '$TUNNEL_NAME' not found. Creating it..."
    cloudflared tunnel create "$TUNNEL_NAME"
else
    info "Tunnel '$TUNNEL_NAME' already exists."
fi

TUNNEL_ID=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')
CREDS_FILE=$(find ~/.cloudflared/ -name "$TUNNEL_ID.json")

if [ -z "$CREDS_FILE" ]; then
    error "Could not find tunnel credentials file for tunnel ID $TUNNEL_ID."
fi
info "Found tunnel credentials at $CREDS_FILE"


# 3. Vault Configuration
info "Now, let's configure Vault."
read -p "Enter the namespace where Vault is running [default: vault]: " VAULT_NAMESPACE
VAULT_NAMESPACE=${VAULT_NAMESPACE:-vault}

VAULT_POD=$(kubectl get pods -n "$VAULT_NAMESPACE" -l "app.kubernetes.io/name=vault" -o jsonpath="{.items[0].metadata.name}")
if [ -z "$VAULT_POD" ]; then
    error "Could not find a Vault pod in namespace '$VAULT_NAMESPACE'. Please ensure Vault is running and the pod has the label 'app.kubernetes.io/name=vault'."
fi
info "Found Vault pod: $VAULT_POD"

info "Storing tunnel credentials in Vault..."
kubectl exec -it -n "$VAULT_NAMESPACE" "$VAULT_POD" -- /bin/sh -c "vault kv put systemfoundation/cloudflare/$TUNNEL_NAME credentials.json=@-" < "$CREDS_FILE"

info "Creating Vault policy..."
kubectl exec -it -n "$VAULT_NAMESPACE" "$VAULT_POD" -- /bin/sh -c "vault policy write cloudflare-$TUNNEL_NAME -" < ./vault/policy.hcl

info "Creating Vault role..."
# The role.json is a single line, so we can pass it as an argument
ROLE_JSON=$(cat ./vault/role.json | tr -d '\n' | tr -d ' ')
kubectl exec -it -n "$VAULT_NAMESPACE" "$VAULT_POD" -- /bin/sh -c "vault write auth/kubernetes/role/cloudflare-$TUNNEL_NAME -<<EOF
$ROLE_JSON
EOF"


# 4. ArgoCD Deployment
info "Applying ArgoCD application..."
kubectl apply -f ./argocd/application.yaml

info "Deployment initiated!"
info "ArgoCD will now sync the application and deploy the Cloudflared tunnel."
info "You can check the status in your ArgoCD UI or by running: kubectl get app -n argocd $TUNNEL_NAME -w"

printf "\n${GREEN}Bootstrap complete!${NC}\n"
