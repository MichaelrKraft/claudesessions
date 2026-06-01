# Deploying Coder1 Memory (Pro Tier) — Runbook

This is the end-to-end deployment runbook for shipping the Coder1 Memory Pro tier:
landing page, Stripe checkout, license key webhook, license email delivery, and
the `coder1-mem activate` flow.

> **Note:** Some of this overlaps with [PRO-TIER-SETUP.md](./PRO-TIER-SETUP.md),
> which is a paused checkpoint document. This runbook is the canonical
> step-by-step. When in doubt, follow this file.

---

## 1. Prerequisites

You will need accounts on these services. Set them up first, in this order:

1. **Render account** — https://render.com (free tier works to start, $7/mo
   "Starter" plan recommended for no cold starts on the webhook).
2. **Stripe account** — https://dashboard.stripe.com (Standard account; no
   business verification needed for test mode).
3. **SendGrid account** — https://sendgrid.com (free tier = 100 emails/day,
   enough for early launch).
4. **DNS access for claudesession.com** — wherever you registered the domain
   (Namecheap, Cloudflare, GoDaddy, etc). You will add CNAME, MX, and TXT
   records.
5. **GitHub repo** for this codebase — `MichaelrKraft/claudesessions` should
   already be live. The render.yaml blueprint requires the repo to be on
   GitHub (Render reads it from there).

Also confirm locally:

- `git remote -v` shows the GitHub origin.
- `api/server.js` exists and `api/package.json` lists `express`, `stripe`,
  `@sendgrid/mail`.
- `render.yaml` exists at the repo root.

---

## 2. Render deployment (Blueprint)

### 2.1 Connect the repo

1. Go to https://dashboard.render.com.
2. Click **New +** (top right) → **Blueprint**.
3. Click **Connect a repository** → select `MichaelrKraft/claudesessions`.
   Authorize Render to read the repo if prompted.
4. Render will auto-detect `render.yaml` at the repo root. Confirm the
   preview shows a single service: `claudesessions-webhook`.
5. Click **Apply**.

### 2.2 Service creation

Render now creates the service. The first deploy will **fail** because the
four secret env vars aren't set yet — that's expected.

You should see a service named `claudesessions-webhook` in your dashboard.

### 2.3 Set environment variables

1. Click the service name → **Environment** tab in the left sidebar.
2. For each of these four keys, click the value field and paste in the
   real secret. (You will get the actual values in sections 3, 4, and 5.)

   | Key                     | Source            |
   |-------------------------|-------------------|
   | `STRIPE_SECRET_KEY`     | Stripe dashboard  |
   | `STRIPE_WEBHOOK_SECRET` | Stripe dashboard  |
   | `SENDGRID_API_KEY`      | SendGrid dashboard|
   | `FROM_EMAIL`            | You choose — e.g. `hello@claudesession.com` |

3. `NODE_ENV` is already set to `production` by render.yaml — do not change.
4. Click **Save Changes**. Render redeploys automatically.

### 2.4 Note your webhook URL

After deploy succeeds (~2 minutes), copy the public URL Render assigns:

```
https://claudesessions-webhook-XXXX.onrender.com
```

The webhook endpoint is this URL **plus `/webhook`**:

```
https://claudesessions-webhook-XXXX.onrender.com/webhook
```

You'll paste this into Stripe in section 3.

### 2.5 Health check

In a terminal:

```bash
curl https://claudesessions-webhook-XXXX.onrender.com/health
# Expected: {"status":"healthy"}
```

If you get 404 or 502, check the **Logs** tab on Render — most likely a
missing env var or a build failure.

---

## 3. Stripe webhook configuration

### 3.1 Get the Stripe secret key

1. Go to https://dashboard.stripe.com/apikeys.
2. **Start in Test mode** (toggle top right). You will switch to Live in
   section 8.
3. Reveal and copy the **Secret key** (starts with `sk_test_...`).
4. Paste into Render → `STRIPE_SECRET_KEY` env var.
5. Save. Render redeploys.

### 3.2 Create the webhook endpoint

1. Go to https://dashboard.stripe.com/webhooks.
2. Click **Add endpoint** (top right).
3. **Endpoint URL**: paste your Render URL + `/webhook`. Example:
   ```
   https://claudesessions-webhook-XXXX.onrender.com/webhook
   ```
4. **Description**: `claudesessions license key delivery`
5. **Events to send**: click **Select events**, search for and check:
   - `checkout.session.completed`
6. Click **Add endpoint**.

### 3.3 Copy the webhook signing secret

1. On the newly created endpoint page, find the **Signing secret** section.
2. Click **Reveal**.
3. Copy the value (starts with `whsec_...`).
4. Paste into Render → `STRIPE_WEBHOOK_SECRET` env var.
5. Save. Render redeploys.

> **Why this matters:** the webhook server verifies every incoming Stripe
> request against this secret. Without it, the server rejects all requests
> with a 400 error.

---

## 4. Stripe product creation

### 4.1 Pro plan — $15/month

1. Go to https://dashboard.stripe.com/products.
2. Click **Add product**.
3. **Name**: `Coder1 Memory — Pro`
4. **Description**: `Personal context-aware memory for Claude Code. Pro tier.`
5. **Pricing model**: Recurring
6. **Price**: `$15.00 USD`
7. **Billing period**: Monthly
8. Click **Save product**.
9. On the product page, find the **Pricing** section and copy the **Price ID**
   (starts with `price_...`). Save it — the landing page Buy button needs it.

### 4.2 Team plan — $49/month

Repeat the steps above with:

- **Name**: `Coder1 Memory — Team`
- **Description**: `Coder1 Memory for engineering teams. Team tier.`
- **Price**: `$49.00 USD / month`

Save the Team Price ID alongside the Pro Price ID.

### 4.3 (Optional) Create Stripe payment links

For the simplest landing-page integration, generate a Stripe-hosted Payment Link
for each product:

1. Product page → **... menu** → **Create payment link**.
2. Confirm the price.
3. Copy the `https://buy.stripe.com/...` URL.

The landing page Buy buttons can point directly at these URLs — no checkout
session API call needed.

---

## 5. SendGrid setup

### 5.1 Create account

1. Sign up at https://signup.sendgrid.com.
2. Verify your email.

### 5.2 Single sender verification

This is the email address all license emails will be sent FROM.

1. Settings → **Sender Authentication** → **Single Sender Verification**.
2. Click **Create New Sender**.
3. Fill in:
   - **From Name**: `Coder1 Memory`
   - **From Email**: `hello@claudesession.com` (must match `FROM_EMAIL` env var)
   - **Reply To**: same as From Email
   - Address fields: your business address
4. Click **Create**.
5. SendGrid sends a verification email to that address. Open it, click the
   verification link.
6. The sender now shows ✓ Verified.

> **Cannot receive mail at hello@claudesession.com?** Use a personal address
> you control for verification (`yourname@gmail.com`), then change FROM_EMAIL
> to match. Domain authentication (next step) lets you switch to the branded
> address later without re-verifying.

### 5.3 Create API key

1. Settings → **API Keys** → **Create API Key**.
2. **Name**: `claudesessions-webhook-prod`.
3. **API Key Permissions**: **Restricted Access** → enable only **Mail Send**
   (full access). Leave everything else off.
4. Click **Create & View**.
5. Copy the key (starts with `SG.`). **You will not see it again.**
6. Paste into Render → `SENDGRID_API_KEY` env var.
7. Set `FROM_EMAIL` in Render to match the verified sender exactly.
8. Save. Render redeploys.

---

## 6. DNS for claudesession.com

### 6.1 Landing page hosting

Decide where the marketing site (claudesession.com landing page) is hosted.
Options:

- **Vercel** — connect the repo containing the landing page HTML, add a
  custom domain `claudesession.com`, Vercel issues an SSL cert automatically.
- **Render Static Site** — already in use per PRO-TIER-SETUP.md.
- **Netlify** — same flow as Vercel.

For whichever you choose, add the platform's prescribed records at your
domain registrar. Typically:

- **Root domain `claudesession.com`** → `A` record pointing to the
  platform's IP (Vercel: `76.76.21.21`).
- **`www.claudesession.com`** → `CNAME` to `cname.vercel-dns.com` (or
  equivalent for your host).

### 6.2 SendGrid domain authentication (SPF / DKIM)

Sending from `hello@claudesession.com` requires SPF and DKIM records so
Gmail/Outlook don't mark emails as spam.

1. SendGrid → Settings → **Sender Authentication** → **Domain Authentication**.
2. Click **Get Started**.
3. **DNS host**: select yours (Cloudflare, GoDaddy, etc).
4. **Domain you send from**: `claudesession.com`.
5. Click **Next**.
6. SendGrid generates 3 CNAME records like:
   - `s1._domainkey.claudesession.com → s1.domainkey.uXXX.wlYYY.sendgrid.net`
   - `s2._domainkey.claudesession.com → s2.domainkey.uXXX.wlYYY.sendgrid.net`
   - `emYYY.claudesession.com → uXXX.wlYYY.sendgrid.net`
7. Add each as a CNAME record at your domain registrar. Set TTL to 1 hour
   (or registrar default).
8. Wait 10-30 minutes for DNS propagation.
9. Back in SendGrid, click **Verify**. All three should turn green.

### 6.3 MX records (only if you want to receive mail)

Only needed if you want emails replying to license delivery to land in an
inbox you control. If you're using Google Workspace or Fastmail, follow
their MX setup. If you just want one-way send, skip this.

---

## 7. Testing the flow (Stripe Test mode)

> Keep `STRIPE_SECRET_KEY` as the **test** key during this section.

### 7.1 Run a test checkout

1. Open your Stripe payment link (the `https://buy.stripe.com/test_...` URL
   created in section 4.3).
2. Use card number `4242 4242 4242 4242`, any future expiry, any 3-digit CVC,
   any zip.
3. Use your real email as the customer email so you receive the license email.
4. Click **Pay**.

### 7.2 Verify webhook received the event

1. Open Render → service → **Logs** tab.
2. You should see:
   ```
   === PURCHASE COMPLETED ===
   Email: you@example.com
   License Key: cs_XXXXXXXXXXXXXXXXXXXXXXXX
   Email sent successfully to: you@example.com
   ```
3. If you see `Webhook signature verification failed`, the
   `STRIPE_WEBHOOK_SECRET` env var is wrong — re-copy from Stripe.

### 7.3 Verify the email arrived

1. Check your inbox (and spam folder) for the license key email from
   `hello@claudesession.com`.
2. If it went to spam: SendGrid domain auth (section 6.2) is not yet
   verified. Wait for DNS, then re-test.

### 7.4 Test license activation

```bash
# Reload PATH if you haven't restarted your terminal since install
source ~/.zshrc

# Activate using the license key from the email
sessions activate cs_XXXXXXXXXXXXXXXXXXXXXXXX
# OR (same command, branded)
coder1-mem activate cs_XXXXXXXXXXXXXXXXXXXXXXXX

# Confirm credits
sessions credits
```

You should see credits increase by the bundle amount (20 for the current
Pro Tier credits product).

### 7.5 Verify Stripe webhook delivery dashboard

1. Stripe dashboard → Developers → **Webhooks** → click your endpoint.
2. The **Events** tab should show `checkout.session.completed` with
   HTTP status `200`.
3. If status is `4xx` or `5xx`, click into the event for the error detail.

---

## 8. Going live

After section 7 passes end-to-end, switch from Test to Live.

### 8.1 Switch Stripe to Live mode

1. Stripe dashboard → toggle **Test mode** OFF (top right).
2. https://dashboard.stripe.com/apikeys → copy the **Live secret key**
   (starts with `sk_live_...`).
3. Render → service → Environment → update `STRIPE_SECRET_KEY` to the
   live value.
4. Save. Render redeploys.

### 8.2 Create live webhook + signing secret

The test-mode webhook does NOT receive live events. Create a new one:

1. Stripe → Webhooks (in Live mode now) → **Add endpoint**.
2. Same URL as before: `https://claudesessions-webhook-XXXX.onrender.com/webhook`
3. Same event: `checkout.session.completed`.
4. Copy the new signing secret (different `whsec_...` from the test one).
5. Render → Environment → update `STRIPE_WEBHOOK_SECRET` with the live value.
6. Save. Render redeploys.

### 8.3 Recreate the products in Live mode

Stripe test products don't carry over to live. Repeat section 4 in Live
mode to create live Pro and Team products. Save the live Price IDs and
update the landing page Buy buttons.

### 8.4 Real-money smoke test

1. Use your own real card on the live Stripe payment link.
2. Verify the same flow as section 7.
3. After confirming: refund yourself via the Stripe dashboard
   (Payments → click the payment → **Refund**).

### 8.5 Final sanity check

```bash
# Health endpoint
curl https://claudesessions-webhook-XXXX.onrender.com/health

# Stripe → Webhooks → Recent deliveries shows your test as 200 OK
# SendGrid → Activity Feed shows the license email delivered (not bounced/blocked)
```

---

## 9. Rollback plan

If something goes wrong after going live and you need to stop accepting
new purchases:

### 9.1 Fastest: disable the Stripe webhook

1. Stripe → Webhooks → click your live endpoint.
2. Click **Disable**.

   Effect: Stripe still accepts payments, but no license keys are generated.
   You will need to manually issue keys to anyone who paid during the
   outage. **Use only briefly.**

### 9.2 Better: take down the payment link

1. Stripe → Payment Links → click your live link.
2. Click **Deactivate link** (top right).

   Effect: anyone hitting the link sees "This link is no longer active."
   No charges, no support burden.

### 9.3 Server-level rollback

If the issue is in `api/server.js` and you need to revert code:

1. Render → service → **Manual Deploy** → **Deploy specific commit**.
2. Select the last known-good commit.
3. Click **Deploy**.

### 9.4 Take the webhook service offline

Last resort:

1. Render → service → **Settings** → scroll to **Suspend Service** → confirm.
2. Re-enable when fixed.

### 9.5 Refund affected customers

1. Stripe → Payments → filter by date range of the outage.
2. Click each → **Refund** → **Refund full payment**.
3. Email each customer an apology + a manually generated license key
   (run `bin/generate-license.sh` locally, or use the helper at
   `api/webhook.js` directly).

---

## Reference: env var matrix

| Env var                 | Set where     | Format / example                    |
|-------------------------|---------------|-------------------------------------|
| `STRIPE_SECRET_KEY`     | Render        | `sk_live_...` (or `sk_test_...`)    |
| `STRIPE_WEBHOOK_SECRET` | Render        | `whsec_...`                         |
| `SENDGRID_API_KEY`      | Render        | `SG....`                            |
| `FROM_EMAIL`            | Render        | `hello@claudesession.com`           |
| `NODE_ENV`              | render.yaml   | `production` (already set)          |
| `PORT`                  | Render        | auto-injected, do not set manually  |

## Reference: URL matrix

| What                | Where it lives                                          |
|---------------------|---------------------------------------------------------|
| Landing page        | `https://claudesession.com` (Vercel/Netlify/Render)     |
| Webhook API         | `https://claudesessions-webhook-XXXX.onrender.com`      |
| Health check        | `<webhook URL>/health`                                  |
| Stripe webhook      | `<webhook URL>/webhook`                                 |
| Stripe dashboard    | `https://dashboard.stripe.com`                          |
| SendGrid dashboard  | `https://app.sendgrid.com`                              |
| Render dashboard    | `https://dashboard.render.com`                          |

## Reference: order of operations checklist

- [ ] Render service created via Blueprint (section 2.1-2.2)
- [ ] STRIPE_SECRET_KEY (test) set in Render (section 3.1)
- [ ] Stripe test webhook endpoint created (section 3.2)
- [ ] STRIPE_WEBHOOK_SECRET set in Render (section 3.3)
- [ ] Stripe Pro + Team products created (section 4)
- [ ] SendGrid sender verified (section 5.2)
- [ ] SENDGRID_API_KEY + FROM_EMAIL set in Render (section 5.3)
- [ ] DNS records added for claudesession.com landing page (section 6.1)
- [ ] SendGrid CNAME records added + verified (section 6.2)
- [ ] End-to-end test passes (section 7)
- [ ] Switched to live keys (section 8)
- [ ] Real-money smoke test refunded (section 8.4)

---

*Last updated: 2026-05-31. If you hit a snag the runbook doesn't cover,
note the step number, the error message, and what you tried — that's the
unit of debugging info needed to fix it.*
