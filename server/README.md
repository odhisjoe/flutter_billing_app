# POS M-Pesa STK Push Proxy

Stateless Node.js server that proxies M-Pesa Daraja API calls. M-Pesa credentials stay server-side — never exposed to the mobile app.

## Deploy to Render

1. Push `server/` directory to GitHub

2. In Render dashboard: **New + Web Service**
   - Connect repo
   - Root Directory: `server`
   - Build Command: `npm install`
   - Start Command: `npm start`
   - Plan: **Free** (sleeps when idle)

3. Add environment variables in Render dashboard:

| Variable | Value | Notes |
|---|---|---|
| `MPESA_ENV` | `sandbox` or `production` | sandbox for testing |
| `MPESA_CONSUMER_KEY` | From Daraja portal | |
| `MPESA_CONSUMER_SECRET` | From Daraja portal | |
| `MPESA_PASSKEY` | From Daraja portal | |
| `MPESA_SHORTCODE` | `174379` (sandbox) | |
| `SERVER_URL` | `https://your-app.onrender.com` | Used for callback |

4. Deploy — server is live at `https://your-app.onrender.com`

## API Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/health` | Health check + config status |
| `POST` | `/api/mpesa/stk-push` | Initiate STK Push to phone |
| `POST` | `/api/mpesa/callback` | Safaricom callback (no auth) |
| `GET` | `/api/mpesa/status/:id` | Poll payment status |
| `POST` | `/api/mpesa/config` | Check server config |

## Local Dev

```bash
cd server
npm install
export MPESA_CONSUMER_KEY=your_key
export MPESA_CONSUMER_SECRET=your_secret
export MPESA_PASSKEY=your_passkey
export MPESA_SHORTCODE=174379
export SERVER_URL=http://localhost:3000
npm start
```

## Security

- M-Pesa credentials are set via environment variables only
- App sends STK Push via server proxy — never sees Daraja credentials
- Callbacks are stored in-memory (resets on restart)
- For production, add Firebase Admin SDK or PostgreSQL for callback persistence
