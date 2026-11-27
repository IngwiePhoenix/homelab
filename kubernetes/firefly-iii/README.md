# Firefly III

Firefly III is exposed at `https://firefly.birb.it` and protected by the existing
VoidAuth ForwardAuth middleware.

## Bootstrap secret

Before enabling the Flux Kustomization, set both values in
`firefly-iii-env.sops.yaml`:

- `APP_KEY`: a Laravel-compatible 32-byte encryption key. Generate it with
  `printf 'base64:%s' "$(openssl rand -base64 32 | tr -d '\n')"`.
- `STATIC_CRON_TOKEN`: a distinct random token. Generate it with
  `openssl rand -hex 16`.

Encrypt the manifest in place:

```sh
sops -e -i kubernetes/firefly-iii/firefly-iii-env.sops.yaml
```

The root `.gitignore` excludes the corresponding plaintext filename
`firefly-iii-env.yaml`.

The scheduled task calls Firefly III's static cron endpoint daily at 03:00
Europe/Berlin time.
