# Nametag

Nametag is available at [https://nametag.birb.it](https://nametag.birb.it). It uses the shared PostgreSQL instance and stores uploaded photos in the `local-bunker` PVC.

## VoidAuth OIDC setup

Create a confidential OIDC application in VoidAuth with:

- Issuer URL: `https://auth.birb.it/oidc` (confirm that this exactly matches the **OIDC Issuer Endpoint** shown under VoidAuth's OIDC Information)
- Redirect URI: `https://nametag.birb.it/api/auth/callback/oidc`
- Scopes: `openid email profile`
- Authorization Code flow with PKCE

VoidAuth users need a verified email address: Nametag rejects OIDC profiles that do not return `email_verified: true`.

## Required secret values

The `nametag-env.sops.yaml` Secret is intentionally present with blank values. Populate these entries before the first deployment:

- `NEXTAUTH_SECRET`: a random value of at least 32 characters (for example, generate one with `openssl rand -base64 32`)
- `CRON_SECRET`: a random value of at least 16 characters (for example, `openssl rand -base64 24`)
- `OIDC_CLIENT_ID` and `OIDC_CLIENT_SECRET`: the credentials generated for the VoidAuth application

After adding the values, encrypt the manifest with the repository's existing SOPS rules before committing it:

```sh
sops --encrypt --in-place kubernetes/nametag/nametag-env.sops.yaml
```

Password-based login is disabled; the application will not become ready until the required secrets and VoidAuth client credentials have been populated.

## Scheduled jobs

The CronJobs call Nametag's authenticated maintenance endpoints: reminders daily at 08:00, deleted-record cleanup daily at 03:00, CardDAV synchronization at 02:00/10:00/18:00, and geocoding every five minutes. Times use the Kubernetes CronJob controller's timezone.
