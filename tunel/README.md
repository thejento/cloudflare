# Cloudflared Tunnel Deployment with ArgoCD and Vault

This document outlines the procedure to deploy a Cloudflared tunnel in a Kubernetes cluster using ArgoCD for GitOps-driven deployment and HashiCorp Vault for secret management.

## Prerequisites

*   A running Kubernetes cluster.
*   `kubectl` installed and configured to connect to your cluster.
*   ArgoCD installed in the cluster.
*   HashiCorp Vault installed in the cluster with the Kubernetes auth method enabled.
*   A Cloudflare account and a domain.

## Directory Structure

```
.
├── argocd
│   └── application.yaml
├── manifests
│   ├── 00-namespace.yaml
│   ├── 01-service-account.yaml
│   ├── 02-configmap.yaml
│   └── 03-deployment.yaml
├── vault
│   ├── policy.hcl
│   └── role.json
└── README.md
```

## Deployment Steps

### 1. Vault Configuration

Before deploying the tunnel, you need to configure Vault to securely store the Cloudflare tunnel credentials.

#### 1.1. Create the Tunnel

First, create a tunnel and get the credentials.

1.  Install `cloudflared` on your local machine.
2.  Login to Cloudflare:
    ```sh
    cloudflared tunnel login
    ```
3.  Create the tunnel:
    ```sh
    cloudflared tunnel create public-home-lab
    ```
    This will create a `tunnel-credentials.json` file in your `~/.cloudflared` directory. The output will also contain the tunnel ID.

#### 1.2. Store Credentials in Vault

Next, store the contents of the `tunnel-credentials.json` file in Vault.

```sh
# The secret will be stored as a key-value pair.
# The key is 'credentials.json' and the value is the content of the file.
kubectl exec -it -n vault <VAULT_POD_NAME> -- /bin/sh -c "vault kv put systemfoundation/cloudflare/public-home-lab credentials.json=@-" < ~/.cloudflared/<TUNNEL_ID>.json
```

#### 1.3. Apply Vault Policy and Role

Now, apply the policy and role to allow the `cloudflared` service account to access the secret.

1.  **Create the Policy:**
    ```sh
    kubectl exec -it -n vault <VAULT_POD_NAME> -- /bin/sh -c "vault policy write cloudflare-public-home-lab -" < ./vault/policy.hcl
    ```

2.  **Create the Role:**
    ```sh
    kubectl exec -i -n vault <VAULT_POD_NAME> -- /bin/sh -c "vault write auth/kubernetes/role/cloudflare-public-home-lab -< ./vault/role.json"
    ```

### 2. ArgoCD Deployment

Once Vault is configured, you can deploy the `cloudflared` tunnel using ArgoCD.

1.  **Commit and Push:**
    Commit all the files in this repository to your Git repository and push the changes.

2.  **Apply the ArgoCD Application:**
    Apply the `application.yaml` manifest to your cluster:
    ```sh
    kubectl apply -f ./argocd/application.yaml
    ```

ArgoCD will now sync the repository and deploy the `cloudflared` tunnel to the `cloudflare` namespace. The Vault injector will automatically inject the tunnel credentials into the `cloudflared` pod.

### 3. Verify the Deployment

You can verify the deployment by checking the logs of the `cloudflared` pod:

```sh
kubectl logs -n cloudflare -l app=cloudflared-public-home-lab -f
```

You should see messages indicating that the tunnel is connected.
