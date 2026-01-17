# Security Configuration for Cloudflare Tunnel

This document provides instructions on how to secure the public endpoints exposed by your Cloudflare Tunnel. It covers two critical aspects:
1.  Enforcing End-to-End Encryption (HTTPS).
2.  Restricting access to authorized users with Cloudflare Access.

---

## 1. Enforcing End-to-End Encryption (HTTPS)

Your Cloudflare Tunnel encrypts the connection between your Kubernetes cluster and Cloudflare's network. You also need to ensure the connection from a user's browser to Cloudflare is encrypted. For maximum security, your domain should be configured to use **Full (Strict)** SSL/TLS mode.

Here’s how to check and configure it:

1.  **Log in** to your Cloudflare dashboard.
2.  **Select your domain** (`thetvf.org`).
3.  Navigate to **SSL/TLS** in the left-hand sidebar.
4.  Click on the **Overview** tab.
5.  You will see several SSL/TLS encryption modes. Select **Full (Strict)**.

**What does "Full (Strict)" mean?**
- **Browser to Cloudflare:** The connection is encrypted via standard, publicly trusted SSL certificates that Cloudflare provides and manages.
- **Cloudflare to Origin (Your Tunnel):** The connection is also required to be encrypted. The Cloudflare Tunnel protocol handles this automatically and securely.

By setting this mode, you ensure there is no unencrypted traffic at any point.

---

## 2. Restricting Access with Cloudflare Access

By default, once you expose an endpoint like `n8n.thetvf.org`, it is accessible to anyone on the public internet. You should protect it using **Cloudflare Access**, which is part of Cloudflare's Zero Trust platform. This will place a login page in front of your application.

Here’s how to set up a policy for your `n8n` instance:

1.  **Navigate to the Zero Trust Dashboard:**
    *   From the main Cloudflare dashboard, click the **"Zero Trust"** link in the left-hand sidebar. (This may open in a new tab).

2.  **Add an Application:**
    *   In the Zero Trust dashboard, navigate to **Access -> Applications** in the left-hand sidebar.
    *   Click the **"Add an application"** button.
    *   Choose the **"Self-hosted"** application type.

3.  **Configure the Application:**
    *   **Application name:** Enter a descriptive name, like `n8n`.
    *   **Application domain:**
        *   **Subdomain:** `n8n`
        *   **Domain:** `thetvf.org`
    *   Click **Next**.

4.  **Create an Access Policy:**
    *   This is where you define who is allowed to access the application.
    *   **Policy name:** Give the policy a name, like `Allow Admin`.
    *   **Action:** Set this to `Allow`.
    *   **Configure a rule:** This is the most important part. Create a rule to identify your authorized users. A common starting point is to use the `Emails` selector.
        *   **Selector:** `Emails`
        *   **Value:** Enter your own email address.
    *   You can add more rules to include other people, specific login methods, IP ranges, and more.
    *   Click **Next**.

5.  **Save the Application:**
    *   Review the configuration on the final page.
    *   Click the **"Add application"** button at the bottom.

**What Happens Now?**

Within a minute, if you (or anyone else) tries to visit `https://n8n.thetvf.org`, they will be stopped and presented with a Cloudflare Access login screen. Only the users you defined in your policy who successfully authenticate will be allowed to proceed to the `n8n` application.
