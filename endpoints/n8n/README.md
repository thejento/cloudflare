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

## DNS Management

**Important Note:** While `cloudflared` is designed to automatically create CNAME DNS records, some local configurations may prevent this automation. If your subdomain is not appearing in the Cloudflare dashboard, you may need to create the CNAME record manually.

To manually create the CNAME record in your Cloudflare dashboard:

1.  **Log in** to your Cloudflare dashboard and select your domain (`thetvf.org`).
2.  Navigate to **DNS -> Records**.
3.  Click **"Add record"**.
4.  **Type:** Select `CNAME`.
5.  **Name:** Enter `n8n` (this is the subdomain portion of `n8n.thetvf.org`).
6.  **Target:** Enter the unique ID of your tunnel followed by `.cfargotunnel.com`. For this tunnel, the target is `2ecc84aa-47f3-45ba-a314-4698d7c1e898.cfargotunnel.com`.
7.  **Proxy status:** Ensure it is set to **"Proxied"** (orange cloud icon) for Cloudflare's security and performance features to apply.
8.  **TTL:** Leave as `Auto` or choose a suitable value.
9.  Click **"Save"**.

Once the CNAME record is created, `cloudflared` will be able to route traffic through the tunnel.

## How to Add or Modify Endpoints (GitOps Workflow)

There is no bootstrap script for managing endpoints, as this is handled declaratively through GitOps and ArgoCD.

To expose a new service or modify an existing one:

1.  **Edit the ConfigMap:** Open the `tunel/manifests/02-configmap.yaml` file.
2.  **Add a New Rule:** Add a new item to the `ingress` list with the desired `hostname` and internal `service` URL.
3.  **Commit and Push:** Commit the changes to your git repository.
4.  **Sync ArgoCD:** ArgoCD will automatically detect the changes and update the `cloudflared` deployment with the new configuration. `cloudflared` will attempt to automatically update the DNS records in Cloudflare for the new hostname. **If the record does not appear automatically in your Cloudflare dashboard, you may need to create the CNAME record manually as described in the "DNS Management" section.**
