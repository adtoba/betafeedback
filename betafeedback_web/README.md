# BetaFeedback Web

Marketing site, invite pages, and the **developer dashboard** for [BetaFeedback](https://betafeedback.com), built with [Next.js](https://nextjs.org).

## Pages

| Route | Description |
|-------|-------------|
| `/` | Marketing landing page |
| `/join/[code]` | Invite landing page (fetches project info from the API) |
| `/app/login` | Developer sign-in (email OTP) |
| `/app` | Project list (creators & developers) |
| `/app/projects/[id]` | Bug summary — checklist & detailed cards |

## Development

1. Copy env and point at your backend:

   ```bash
   cp .env.example .env.local
   ```

2. Start the Go API (`betafeedback_backend`, default port 8080).

   Ensure `OTP_DEBUG=true` in the backend `.env` during local dev so sign-in codes appear in the API response and login UI.

3. Run the site:

   ```bash
   npm install
   npm run dev
   ```

   - Marketing: [http://localhost:3000](http://localhost:3000)
   - Developer dashboard: [http://localhost:3000/app/login](http://localhost:3000/app/login)

`/v1/*` requests are proxied to `API_URL` via Next.js rewrites, so the join page and dashboard work without CORS setup in local dev.

## Developer dashboard

Sign in at `/app/login` with **Google** or **email OTP** (same accounts as mobile).

Set matching Google OAuth IDs on backend and web:

```bash
# betafeedback_backend/.env
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com

# betafeedback_web/.env.local
NEXT_PUBLIC_GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
```

Create a **Web application** OAuth client in [Google Cloud Console](https://console.cloud.google.com/apis/credentials). Add `http://localhost:3000` to authorized JavaScript origins for local dev.

Only projects where you are **creator** or **developer** appear on `/app`.

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
