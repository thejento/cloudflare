#!/bin/bash

# This script automates the deployment of the Cloudflared tunnel.
# It assumes that 'cloudflared', 'kubectl', 'jq', and 'vault' are installed and configured.

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
check_dep "vault"


# --- Main script ---

# 1. Cloudflare Login
info "The next step is to log in with the 'cloudflared' CLI."
info "This will open a browser window and ask you to log in to your Cloudflare account."
warn "After logging in, you will be prompted to select one of your Cloudflare zones (domains)."
warn "Be sure to choose the zone where you plan to create public hostnames for your tunnel."
info "Please run 'cloudflared tunnel login' in another terminal, and then press Enter here to continue."
read -p "Press [Enter] to continue once you have logged in..."

# 2. Tunnel Configuration
TUNNEL_NAME="public-home-lab"
info "Checking for Cloudflare tunnel '$TUNNEL_NAME' நான"

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
info "Now, let's configure Vault using the public Ingress URL."

VAULT_HOST=$(kubectl get ingress vault -n vault -o jsonpath='{.spec.rules[0].host}')
if [ -z "$VAULT_HOST" ]; then
    error "Could not automatically determine the Vault Ingress host. Please check your Ingress configuration in the 'vault' namespace."
fi

export VAULT_ADDR="http://${VAULT_HOST}"
info "Found Vault URL. Setting VAULT_ADDR to: $VAULT_ADDR"

warn "You now need to authenticate with Vault."
warn "Please authenticate in another terminal (e.g., 'vault login <token>' or 'vault login -method=userpass')."
warn "The authenticated user MUST have permissions to create policies and roles."
read -p "Press [Enter] to continue once you have authenticated with Vault..."


info "Storing tunnel credentials in Vault..."
vault kv put "systemfoundation/cloudflare/$TUNNEL_NAME" "credentials.json=@$CREDS_FILE"

info "Creating Vault policy..."
vault policy write "cloudflare-$TUNNEL_NAME" ./vault/policy.hcl

info "Creating Vault role..."
vault write "auth/kubernetes/role/cloudflare-$TUNNEL_NAME" \
    bound_service_account_names="cloudflared-public-home-lab" \
    bound_service_account_namespaces="cloudflare" \
    policies="cloudflare-public-home-lab" \
    ttl="24h"


# 4. ArgoCD Deployment
info "Applying ArgoCD application..."
kubectl apply -f ./argocd/application.yaml

info "Deployment initiated!"
info "ArgoCD will now sync the application and deploy the Cloudflared tunnel."
info "You can check the status in your ArgoCD UI or by running: kubectl get app -n argocd $TUNNEL_NAME -w"

printf "\n${GREEN}Bootstrap complete!${NC}\n"