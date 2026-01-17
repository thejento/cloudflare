# n8n Endpoint Configuration

This document outlines how the `n8n` service is exposed to the internet via the Cloudflare Tunnel.

## Configuration

The `n8n` instance is made public by adding an `ingress` rule to the `cloudflared` configuration. This is managed in the main `cloudflared` `ConfigMap`.

**File:** `tunel/manifests/02-configmap.yaml`

The following rule has been added:

```yaml
- hostname: n8n.thetvf.org
  service: http://n8n-service.n8n.svc:5878
```

This rule tells `cloudflared` to route any traffic received for `n8n.thetvf.org` to the internal Kubernetes service `n8n-service` in the `n8n` namespace on port `5878`.

## How to Add or Modify Endpoints (GitOps Workflow)

There is no bootstrap script for managing endpoints, as this is handled declaratively through GitOps and ArgoCD.

To expose a new service or modify an existing one:

1.  **Edit the ConfigMap:** Open the `tunel/manifests/02-configmap.yaml` file.
2.  **Add a New Rule:** Add a new item to the `ingress` list with the desired `hostname` and internal `service` URL.
3.  **Commit and Push:** Commit the changes to your git repository.
4.  **Sync ArgoCD:** ArgoCD will automatically detect the changes and update the `cloudflared` deployment with the new configuration. `cloudflared` will then automatically update the DNS records in Cloudflare for the new hostname.
