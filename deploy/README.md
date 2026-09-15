# Zest production Docker scaffold

This is a reviewable deployment candidate. It is not a declaration that Zest is ready for public production use: backups, account recovery/deletion, email verification, and the public-host/tunnel decision remain pending.

## Architecture

- `zest-frontend` builds the Flutter web app and serves it with Nginx.
- Nginx proxies `/api/` to `zest-backend` over `zest-internal`.
- `zest-backend` runs the committed Drizzle migrations before it starts, connects to `zest-db`, and stores private photos in the `zest_photos` named volume.
- Only `zest-frontend` joins the external `adam-cloud` network. No service publishes a host port.
- The frontend must receive its public HTTPS API base during Docker build through the ignored production environment file. Native APK builds need the same value supplied manually as `--dart-define=ZEST_API_BASE_URL=...`.

## Local configuration

```sh
cd deploy
cp .env.example .env
chmod 600 .env
```

Edit `.env` locally. Never commit it. Its real public host, provider key, and database password are intentionally absent from this repository. Docker Compose loads this exact filename automatically for both build arguments and runtime service configuration.

Validate the Compose model without starting it:

```sh
docker compose config
```

Build and start the stack with the standard Compose command:

```sh
docker compose up -d --build
```

## Deployment prerequisites still requiring an explicit decision

1. Verify a tested backup and restore procedure for both `zest_postgres_data` and `zest_photos`.
2. Decide the public hostname and add its Cloudflare Tunnel ingress rule to `zest-frontend:80` on `adam-cloud`.
3. Build an APK with the same public HTTPS base URL; do not compile a provider key into the APK.
4. Review account enumeration, password-reset, email-verification, and account-deletion requirements before inviting any users beyond personal use.
