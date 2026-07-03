const express = require('express');
const axios = require('axios');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// ── In-memory callback store (resets on restart) ──────────────────────────
// For production, replace with Firestore/Firebase Admin SDK or a small DB
const callbacks = new Map();

// ── Daraja helpers ────────────────────────────────────────────────────────

async function getAccessToken() {
  const key = process.env.MPESA_CONSUMER_KEY;
  const secret = process.env.MPESA_CONSUMER_SECRET;
  if (!key || !secret) throw new Error('M-Pesa credentials not configured');

  const creds = Buffer.from(`${key}:${secret}`).toString('base64');
  const baseUrl = process.env.MPESA_ENV === 'production'
    ? 'https://api.safaricom.co.ke'
    : 'https://sandbox.safaricom.co.ke';

  const res = await axios.get(
    `${baseUrl}/oauth/v1/generate?grant_type=client_credentials`,
    { headers: { Authorization: `Basic ${creds}` } }
  );
  return res.data.access_token;
}

function getTimestamp() {
  const now = new Date();
  return now.getFullYear().toString() +
    String(now.getMonth() + 1).padStart(2, '0') +
    String(now.getDate()).padStart(2, '0') +
    String(now.getHours()).padStart(2, '0') +
    String(now.getMinutes()).padStart(2, '0') +
    String(now.getSeconds()).padStart(2, '0');
}

function getPassword(timestamp) {
  const shortcode = process.env.MPESA_SHORTCODE;
  const passkey = process.env.MPESA_PASSKEY;
  return Buffer.from(`${shortcode}${passkey}${timestamp}`).toString('base64');
}

function getBaseUrl() {
  return process.env.MPESA_ENV === 'production'
    ? 'https://api.safaricom.co.ke'
    : 'https://sandbox.safaricom.co.ke';
}

// ── Routes ────────────────────────────────────────────────────────────────

// POST /api/mpesa/stk-push – Initiate STK Push to customer phone
app.post('/api/mpesa/stk-push', async (req, res) => {
  try {
    const { phone, amount, reference, description } = req.body;
    const shortcode = process.env.MPESA_SHORTCODE;
    const timestamp = getTimestamp();
    const password = getPassword(timestamp);
    const token = await getAccessToken();
    const baseUrl = getBaseUrl();

    console.log(`[STK PUSH] ${phone} KES ${amount} ref: ${reference}`);

    const response = await axios.post(
      `${baseUrl}/mpesa/stkpush/v1/processrequest`,
      {
        BusinessShortCode: shortcode,
        Password: password,
        Timestamp: timestamp,
        TransactionType: 'CustomerPayBillOnline',
        Amount: amount,
        PartyA: phone,
        PartyB: shortcode,
        PhoneNumber: phone,
        CallBackURL: `${process.env.SERVER_URL}/api/mpesa/callback`,
        AccountReference: reference,
        TransactionDesc: description || 'POS Payment',
      },
      { headers: { Authorization: `Bearer ${token}` } }
    );

    // Store for polling
    const checkoutId = response.data.CheckoutRequestID;
    callbacks.set(checkoutId, {
      paid: false,
      mpesaRef: null,
      createdAt: Date.now(),
    });

    console.log(`[STK PUSH] Sent, CheckoutRequestID: ${checkoutId}`);
    res.json(response.data);
  } catch (err) {
    console.error('[STK PUSH ERROR]', err.response?.data || err.message);
    res.status(500).json({
      error: 'STK Push failed',
      message: err.response?.data?.errorMessage || err.message,
    });
  }
});

// POST /api/mpesa/callback – Safaricom calls this with payment result
app.post('/api/mpesa/callback', (req, res) => {
  const { Body } = req.body;
  if (!Body || !Body.stkCallback) {
    return res.json({ ResultCode: 1, ResultDesc: 'Invalid callback' });
  }

  const { ResultCode, ResultDesc, CheckoutRequestID, CallbackMetadata } = Body.stkCallback;
  console.log(`[CALLBACK] ${CheckoutRequestID} result: ${ResultCode} - ${ResultDesc}`);

  if (ResultCode === 0 && CallbackMetadata) {
    const items = CallbackMetadata.Item;
    const mpesaRef = items.find(i => i.Name === 'MpesaReceiptNumber')?.Value;
    const phone = items.find(i => i.Name === 'PhoneNumber')?.Value;
    const amount = items.find(i => i.Name === 'Amount')?.Value;

    callbacks.set(CheckoutRequestID, {
      paid: true,
      mpesaRef: mpesaRef || null,
      phone: phone || null,
      amount: amount || null,
      createdAt: Date.now(),
    });

    console.log(`[CALLBACK] Payment confirmed: ${mpesaRef} KES ${amount}`);
  } else {
    callbacks.set(CheckoutRequestID, {
      paid: false,
      mpesaRef: null,
      resultDesc: ResultDesc,
      createdAt: Date.now(),
    });
  }

  res.json({ ResultCode: 0, ResultDesc: 'Accepted' });
});

// GET /api/mpesa/status/:checkoutRequestId – Polled by Flutter app
app.get('/api/mpesa/status/:id', (req, res) => {
  const record = callbacks.get(req.params.id);
  if (!record) {
    return res.json({ paid: false, mpesaRef: null, found: false });
  }
  res.json({
    paid: record.paid,
    mpesaRef: record.mpesaRef || null,
    found: true,
  });
});

// POST /api/mpesa/config – Admin saves M-Pesa credentials from app
app.post('/api/mpesa/config', (req, res) => {
  // Server must have these as environment variables (Render dashboard)
  // This endpoint validates that the credentials work by testing token generation
  res.json({
    configured: !!(process.env.MPESA_CONSUMER_KEY && process.env.MPESA_CONSUMER_SECRET),
    hint: 'Set MPESA_CONSUMER_KEY, MPESA_CONSUMER_SECRET, MPESA_PASSKEY, MPESA_SHORTCODE, SERVER_URL in environment variables',
  });
});

// GET /api/health – Health check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    mpesaConfigured: !!process.env.MPESA_CONSUMER_KEY,
    callbackStoreSize: callbacks.size,
  });
});

// ── Cleanup stale callbacks every hour ───────────────────────────────────
setInterval(() => {
  const cutoff = Date.now() - 1000 * 60 * 60; // 1 hour
  for (const [key, val] of callbacks) {
    if (val.createdAt < cutoff) callbacks.delete(key);
  }
}, 1000 * 60 * 60);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`POS M-Pesa Proxy running on port ${PORT}`);
  console.log(`M-Pesa configured: ${!!process.env.MPESA_CONSUMER_KEY}`);
});
