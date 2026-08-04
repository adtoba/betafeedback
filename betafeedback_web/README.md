# BetaFeedback Web

Marketing site and invite / open-in-app pages for [BetaFeedback](https://betafeedback.com),
built with [Next.js](https://nextjs.org). The product experience is **mobile-first** —
there is no web developer dashboard login.

## Pages

| Route | Description |
|-------|-------------|
| `/` | Marketing landing page |
| `/join/[code]` | Invite landing (open app / get early access) |
| `/open/projects/[id]` | Deep-link bridge for email CTAs |
| `/app/*` | Redirects to home or `/open/...` (legacy dashboard removed) |

## Development

1. Copy env and point at your backend:

   ```bash
   cp .env.example .env.local
   ```

2. Start the Go API (`betafeedback_backend`, default port 8080).

3. Run the site:

   ```bash
   npm install
   npm run dev
   ```

   - Marketing: [http://localhost:3000](http://localhost:3000)
   - Open bridge example: [http://localhost:3000/open/projects/demo](http://localhost:3000/open/projects/demo)

`/v1/*` requests are proxied to `API_URL` via Next.js rewrites (used by the join page).

## Deep links

Email and notification CTAs use:

`https://betafeedback.com/open/projects/{id}`

When the app is installed and Universal/App Links are verified, that URL opens
the Flutter app. Otherwise the open page offers a custom-scheme button
(`betafeedback://projects/{id}`) and store / early-access badges.

Association files live in `public/.well-known/`:

- `apple-app-site-association`
- `assetlinks.json` (update the SHA-256 fingerprint for your Play signing key)

## Production (Vercel)

1. Import this directory as a Vercel project.
2. Set **Environment variable** `API_URL` to your production API (e.g. `https://api.betafeedback.com`).
3. Deploy. Point your domain (e.g. `betafeedback.com`) at Vercel.

The backend (`betafeedback_backend`) serves only the API.

## Scripts

- `npm run dev` — development server
- `npm run build` — production build
- `npm run start` — serve production build
- `npm run lint` — ESLint
