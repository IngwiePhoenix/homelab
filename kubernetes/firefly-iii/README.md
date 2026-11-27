# Firefly III

Firefly III is exposed at `https://firefly.birb.it` and protected by the existing
VoidAuth ForwardAuth middleware.

## Bootstrap secret

Before enabling the Flux Kustomization, replace the empty `APP_KEY` and
`STATIC_CRON_TOKEN` values in `firefly-iii-env.sops.yaml`. Both values must
be 32 characters long. They should be distinct random strings; for example,
`openssl rand -hex 16` produces a 32-character value.

Encrypt the manifest in place:

```sh
sops -e -i kubernetes/firefly-iii/firefly-iii-env.sops.yaml
```

The root `.gitignore` excludes the corresponding plaintext filename
`firefly-iii-env.yaml`.

The scheduled task calls Firefly III's static cron endpoint daily at 03:00
Europe/Berlin time.
