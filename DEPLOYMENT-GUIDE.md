# Claude Sessions Deployment Guide (Render)

Complete step-by-step guide to deploy Claude Sessions to production using Render.

---

## Step 1: Push to GitHub

```bash
cd ~/claudesessions
git push origin master
```

If you haven't set up the remote yet:
```bash
git remote add origin https://github.com/MichaelrKraft/claudesessions.git
git push -u origin master
```

---

## Step 2: Deploy Landing Page to Render (Static Site)

1. Go to https://dashboard.render.com
2. Click **New** → **Static Site**
3. Connect your GitHub repo `claudesessions`
4. Configure:
   - **Name:** `claudesessions`
   - **Branch:** `master`
   - **Root Directory:** `web`
   - **Build Command:** (leave empty)
   - **Publish Directory:** `.`
5. Click **Create Static Site**
6. Once deployed, go to **Settings** → **Custom Domains**
7. Add `claudesessions.com`
8. Follow DNS instructions (add CNAME to `claudesessions.onrender.com`)

Your landing page will be at: `https://claudesessions.onrender.com`

---

## Step 3: Host the Install Script

The install script needs to be accessible at `https://claudesessions.com/install.sh`

```bash
# Copy install script to web directory
cp ~/claudesessions/install.sh ~/claudesessions/web/install.sh
git add web/install.sh
git commit -m "Add install script to web directory"
git push
```

Render will auto-deploy. Verify it works:
```bash
curl -fsSL https://claudesessions.onrender.com/install.sh
```

---

## Step 4: Deploy Webhook Server to Render (Web Service)

The webhook server handles Stripe payments and sends license keys.

### 4.1 Create Render Account
1. Go to https://render.com
2. Sign up with GitHub

### 4.2 Create Web Service
1. Click **New** → **Web Service**
2. Connect your GitHub repo
3. Configure:
   - **Name:** `claudesessions-webhook`
   - **Region:** Oregon (US West) or closest to you
   - **Branch:** `master`
   - **Root Directory:** `api`
   - **Runtime:** Node
   - **Build Command:** `npm install`
   - **Start Command:** `node server.js`
   - **Instance Type:** Free

### 4.3 Add Environment Variables
Click **Environment** and add:

| Key | Value |
|-----|-------|
| `STRIPE_SECRET_KEY` | `sk_live_xxxx` (from Stripe Dashboard) |
| `STRIPE_WEBHOOK_SECRET` | `whsec_xxxx` (created in Step 5) |
| `SENDGRID_API_KEY` | `SG.xxxx` (from Step 6) |
| `FROM_EMAIL` | `hello@claudesessions.com` |

### 4.4 Deploy
Click **Create Web Service**

Note your Render URL: `https://claudesessions-webhook.onrender.com`

---

## Step 5: Configure Stripe

### 5.1 Create Stripe Account
1. Go to https://dashboard.stripe.com
2. Sign up or log in

### 5.2 Create Product
1. Go to **Products** → **Add Product**
2. Configure:
   - **Name:** Claude Sessions Pro - 20 Credits
   - **Price:** $19.00 (one-time)
   - **Description:** 20 session restore credits for Claude Sessions
3. Save and note the **Price ID** (starts with `price_`)

### 5.3 Create Payment Link
1. Go to **Payment Links** → **Create payment link**
2. Select your product
3. Configure:
   - **Collect email:** Yes (required)
   - **After payment:** Don't show confirmation page (or custom thank you)
4. Create and copy the payment link
5. Update your landing page "Buy Credits" button with this link

### 5.4 Set Up Webhook
1. Go to **Developers** → **Webhooks**
2. Click **Add endpoint**
3. Configure:
   - **Endpoint URL:** `https://claudesessions-webhook.onrender.com/webhook`
   - **Events to send:** Select `checkout.session.completed`
4. Click **Add endpoint**
5. Click on the endpoint → **Reveal** signing secret
6. Copy the `whsec_xxxx` value
7. Add this to Render environment variables as `STRIPE_WEBHOOK_SECRET`

### 5.5 Get API Keys
1. Go to **Developers** → **API keys**
2. Copy the **Secret key** (starts with `sk_live_`)
3. Add to Render as `STRIPE_SECRET_KEY`

---

## Step 6: Set Up SendGrid (Email Delivery)

### 6.1 Create SendGrid Account
1. Go to https://sendgrid.com
2. Sign up (free tier: 100 emails/day)

### 6.2 Verify Sender
1. Go to **Settings** → **Sender Authentication**
2. Choose **Single Sender Verification** (easiest)
3. Add `hello@claudesessions.com`
4. Verify via email link

### 6.3 Create API Key
1. Go to **Settings** → **API Keys**
2. Click **Create API Key**
3. Name: `claudesessions-production`
4. Permissions: **Restricted Access** → Enable **Mail Send**
5. Create and copy the key (starts with `SG.`)
6. Add to Render as `SENDGRID_API_KEY`

### 6.4 (Optional) Domain Authentication
For better deliverability:
1. Go to **Settings** → **Sender Authentication** → **Domain Authentication**
2. Add `claudesessions.com`
3. Add the DNS records to Cloudflare

---

## Step 7: Update Landing Page with Payment Link

Edit `web/landing.html` and add your Stripe payment link:

```html
<!-- Find the "Get credits" or pricing section and add: -->
<a href="https://buy.stripe.com/YOUR_PAYMENT_LINK" class="btn btn-primary">
    Buy 20 Credits - $19
</a>
```

Commit and push:
```bash
git add web/landing.html
git commit -m "Add Stripe payment link"
git push
```

---

## Step 8: Test the Full Flow

### 8.1 Test Install Script
```bash
curl -fsSL https://claudesessions.com/install.sh | bash
```

### 8.2 Test Payment (Use Stripe Test Mode First)
1. In Stripe, toggle to **Test mode**
2. Create a test webhook endpoint
3. Make a test purchase with card `4242 4242 4242 4242`
4. Check Render logs for license key generation
5. Check email delivery

### 8.3 Switch to Live Mode
1. Toggle Stripe to **Live mode**
2. Update Render environment variables with live keys
3. Update webhook endpoint to live
4. Test with a real $1 product first if nervous

---

## Step 9: DNS Configuration

Add these DNS records at your domain registrar:

| Type | Name | Content |
|------|------|---------|
| CNAME | @ | `claudesessions.onrender.com` |
| CNAME | www | `claudesessions.onrender.com` |

**Note:** Some registrars don't allow CNAME on root (@). Use Render's instructions or consider using Cloudflare as a DNS proxy.

---

## Step 10: Final Verification Checklist

- [ ] `https://claudesessions.com` loads landing page
- [ ] `https://claudesessions.com/install.sh` returns install script
- [ ] Install script works: `curl -fsSL https://claudesessions.com/install.sh | bash`
- [ ] Stripe payment link works
- [ ] Webhook receives events (check Stripe dashboard)
- [ ] License key emails are delivered
- [ ] `sessions activate <key>` works
- [ ] `sessions credits` shows balance

---

## Troubleshooting

### Webhook not receiving events
- Check Render logs: `https://dashboard.render.com`
- Verify webhook URL in Stripe matches Render URL
- Check `STRIPE_WEBHOOK_SECRET` is correct

### Emails not sending
- Check SendGrid activity: **Activity** → **Email Activity**
- Verify sender is authenticated
- Check `SENDGRID_API_KEY` is correct
- Check spam folder

### Install script 404
- Ensure `install.sh` is in `web/` directory
- Check Cloudflare Pages deployment completed
- Clear Cloudflare cache if needed

### License key not working
- Check key format (should start with `cs_`)
- Verify credits library is installed: `~/.claudesessions/lib/credits.sh`
- Run `sessions reindex` to refresh database

---

## Cost Summary

| Service | Cost |
|---------|------|
| Render Static Site (landing) | Free |
| Render Web Service (webhook) | Free tier |
| Stripe | 2.9% + $0.30 per transaction |
| SendGrid | Free (100 emails/day) |
| Domain (claudesessions.com) | ~$12/year |

**Total monthly cost: $0** (plus Stripe fees on sales)

**Note:** Render free tier web services spin down after 15 min of inactivity. First request after spin-down takes ~30 seconds. This is fine for webhooks since Stripe retries failed deliveries.

---

## Support

- GitHub Issues: https://github.com/MichaelrKraft/claudesessions/issues
- Stripe Support: https://support.stripe.com
- Render Docs: https://render.com/docs
- SendGrid Docs: https://docs.sendgrid.com
