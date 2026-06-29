# BetaFeedback Web

Marketing site and invite landing pages for [BetaFeedback](https://betafeedback.com), built with [Next.js](https://nextjs.org).

## Pages

| Route | Description |
|-------|-------------|
| `/` | Marketing landing page |
| `/join/[code]` | Invite landing page (fetches project info from the API) |

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

   Open [http://localhost:3000](http://localhost:3000).

`/v1/*` requests are proxied to `API_URL` via Next.js rewrites, so the join page works without CORS setup in local dev.

## Production (Vercel)

1. Import this directory as a Vercel project.
2. Set **Environment variable** `API_URL` to your production API (e.g. `https://api.betafeedback.com`).
3. Deploy. Point your domain (e.g. `betafeedback.com`) at Vercel.

The backend (`betafeedback_backend`) serves only the API — it no longer embeds the marketing site.

## Scripts

- `npm run dev` — development server
- `npm run build` — production build
- `npm run start` — serve production build
- `npm run lint` — ESLint
