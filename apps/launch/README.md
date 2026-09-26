# PR Conductor launch companion

CONFIDENTIAL — PROPRIETARY until the launch surface is approved for publication.

This directory contains the Product Hunt launch landing page and a minimal Product Hunt OAuth 2.0 PKCE adapter.

## Why PKCE

PR Conductor uses a Product Hunt **Public** client. Public clients do not have a client secret and must send an S256 `code_challenge` during authorization and the matching `code_verifier` during token exchange.

The adapter deliberately does **not** use a Product Hunt developer token.

## Runtime configuration

Configure these values in Vercel Project Settings → Environment Variables:

- `PRODUCT_HUNT_CLIENT_ID` — Product Hunt application API key/client ID.
- `PRODUCT_HUNT_REDIRECT_URI` — exact callback URI registered in Product Hunt, for example `https://<deployment-domain>/api/producthunt/callback`.
- `PRODUCT_HUNT_SCOPES` — defaults to `public private`.
- `PRODUCT_HUNT_SESSION_SECRET` — random secret, minimum 32 characters, used to encrypt transient PKCE state and the user access-token cookie.

Never commit developer tokens, OAuth access tokens, or session secrets.

## Local development

```bash
cd apps/launch
cp .env.example .env.local
npm install
npm run dev
```

Then register this redirect URI in the Product Hunt application while testing:

```text
http://localhost:3000/api/producthunt/callback
```

For production, update the Product Hunt application to the exact Vercel callback URI before testing OAuth.

## OAuth flow

```text
GET /api/producthunt/connect
        ↓
generate verifier + state
        ↓
Product Hunt /v2/oauth/authorize
        ↓
GET /api/producthunt/callback
        ↓
verify state + verifier
        ↓
POST /v2/oauth/token
        ↓
encrypted HTTP-only access-token cookie
        ↓
GET /api/producthunt/me
        ↓
POST /v2/api/graphql
```

## Product Hunt API policy

The API is read-only by default. Product Hunt requires separate approval for third-party write access, and its API documentation says commercial use requires contacting Product Hunt. This launch companion therefore implements authenticated read/user-context access only.

## Deployment

Deploy `apps/launch` as the Vercel project root. After the first production deployment:

1. Set the production environment variables.
2. Set `PRODUCT_HUNT_REDIRECT_URI` to the production callback URL.
3. Update the Product Hunt application redirect URI to the same exact value.
4. Redeploy.
5. Visit `/api/health`, then use **Connect Product Hunt** on the home page.
