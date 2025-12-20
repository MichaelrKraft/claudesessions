# Claude Sessions Pro Tier Setup (Paused)

*Last updated: December 19, 2025*

This documents where we left off setting up the paid Pro tier. Resume these steps when ready to launch monetization.

---

## Current Status

### ✅ Completed
- [x] Static site deployed to Render (`https://claudesessions.onrender.com`)
- [x] GitHub repo pushed and connected
- [x] Stripe account exists
- [x] Stripe product created: "Claude Sessions Pro - 20 Credits" @ $19.00
- [x] Stripe payment link created
- [x] Webhook server code ready (`api/server.js`)

### ⏸️ Paused / Not Completed
- [ ] Render webhook web service (created but needs env vars)
- [ ] Stripe webhook endpoint configuration
- [ ] SendGrid email setup
- [ ] Environment variables in Render
- [ ] Landing page payment link integration

---

## Resume Steps

### Step 1: Verify Render Webhook Service
Your webhook service should exist at something like:
- `https://claudesessions-api.onrender.com`

If it was deleted, recreate:
1. Render → New → Web Service
2. Repo: `claudesessions`
3. Root Directory: `api`
4. Build Command: `npm install`
5. Start Command: `node server.js`
6. Instance Type: Free (or paid for no cold starts)

### Step 2: Configure Stripe Webhook
1. Go to https://dashboard.stripe.com/webhooks
2. Click **Add endpoint**
3. Endpoint URL: `https://YOUR-WEBHOOK.onrender.com/webhook`
4. Events: Select `checkout.session.completed`
5. Click **Add endpoint**
6. Click the endpoint → **Reveal signing secret**
7. Copy the `whsec_xxxx` value

### Step 3: Get Stripe API Key
1. Go to https://dashboard.stripe.com/apikeys
2. Copy the **Secret key** (starts with `sk_live_`)

### Step 4: Set Up SendGrid
1. Go to https://sendgrid.com → Sign up (free: 100 emails/day)
2. **Settings** → **Sender Authentication** → Verify `hello@claudesessions.com`
3. **Settings** → **API Keys** → Create key with "Mail Send" permission
4. Copy the `SG.xxxx` key

### Step 5: Add Environment Variables to Render
Go to your webhook service → **Environment** → Add:

| Variable | Value |
|----------|-------|
| `STRIPE_SECRET_KEY` | `sk_live_xxxx` |
| `STRIPE_WEBHOOK_SECRET` | `whsec_xxxx` |
| `SENDGRID_API_KEY` | `SG.xxxx` |
| `FROM_EMAIL` | `hello@claudesessions.com` |

Click **Save Changes** → Service will redeploy.

### Step 6: Update Landing Page with Payment Link
Edit `web/index.html` (and `web/landing.html`):

Find the Cloud Pro section and add your Stripe payment link:
```html
<a href="https://buy.stripe.com/YOUR_LINK_HERE" class="btn btn-primary">
    Buy 20 Credits - $19
</a>
```

Push changes:
```bash
cd ~/claudesessions
git add web/
git commit -m "Add Stripe payment link"
git push
```

### Step 7: Test the Full Flow
1. Use Stripe **Test mode** first
2. Make a test purchase with card `4242 4242 4242 4242`
3. Check Render logs for license key generation
4. Verify email received
5. Test: `sessions activate <license-key>`
6. Test: `sessions credits`
7. Switch to Live mode when ready

---

## Stripe Resources
- Dashboard: https://dashboard.stripe.com
- Payment Link: (save your link here when created)
- Product ID: (save here)
- Webhook endpoint: (save URL here)

## Render Resources
- Static Site: https://claudesessions.onrender.com
- Webhook Service: https://YOUR-NAME.onrender.com

---

## Notes
- Render free tier has cold starts (~30 sec) - Stripe retries failed webhooks so this is fine
- Consider upgrading to paid Render ($7/mo) for instant response if volume increases
- SendGrid free tier = 100 emails/day, upgrade if needed
