# Stripe Webhook Setup for Claude Sessions

This guide walks you through setting up automatic license key delivery after purchase.

## Overview

When a customer pays via Stripe:
1. Stripe sends a webhook to your server
2. Your server generates a license key (`cs_XXXX...`)
3. The key is emailed to the customer
4. Customer runs `sessions activate <key>` to add 20 credits

## Step 1: Get Your Stripe Secret Key

1. Go to: https://dashboard.stripe.com/apikeys
2. Copy your **Secret key** (starts with `sk_live_`)
3. Save it securely - you'll need it for environment variables

## Step 2: Create Webhook in Stripe

1. Go to: https://dashboard.stripe.com/webhooks
2. Click **Add endpoint**
3. Enter your webhook URL:
   - Vercel: `https://your-domain.vercel.app/api/webhook`
   - Netlify: `https://your-domain.netlify.app/.netlify/functions/webhook`
   - Custom: `https://claudesessions.com/api/webhook`
4. Select event: `checkout.session.completed`
5. Click **Add endpoint**
6. Copy the **Signing secret** (starts with `whsec_`)

## Step 3: Deploy the Webhook Handler

### Option A: Vercel (Recommended)

1. Create a new Vercel project or add to existing
2. Add the `api/webhook.js` file to your project
3. Set environment variables in Vercel Dashboard:
   ```
   STRIPE_SECRET_KEY=sk_live_xxx
   STRIPE_WEBHOOK_SECRET=whsec_xxx
   SENDGRID_API_KEY=SG.xxx (optional - for email)
   FROM_EMAIL=hello@claudesessions.com
   ```
4. Deploy!

### Option B: Netlify Functions

1. Create `netlify/functions/webhook.js`:
   ```javascript
   const handler = require('../../api/webhook.js');

   exports.handler = async (event, context) => {
     const req = {
       method: event.httpMethod,
       headers: event.headers,
       body: event.body,
     };
     const res = {
       status: (code) => ({
         json: (data) => ({
           statusCode: code,
           body: JSON.stringify(data),
         }),
       }),
     };
     return handler(req, res);
   };
   ```

2. Set environment variables in Netlify Dashboard
3. Deploy!

### Option C: Express.js Server

```javascript
const express = require('express');
const app = express();

// Important: Use raw body for Stripe webhook verification
app.post('/api/webhook',
  express.raw({ type: 'application/json' }),
  require('./api/webhook.js')
);

app.listen(3000);
```

## Step 4: Set Up Email Delivery (Optional but Recommended)

### Using SendGrid

1. Create account at https://sendgrid.com
2. Get API key from Settings → API Keys
3. Add to environment variables:
   ```
   SENDGRID_API_KEY=SG.xxx
   FROM_EMAIL=hello@claudesessions.com
   ```
4. Install package: `npm install @sendgrid/mail`

### Using Resend (Alternative)

```javascript
// In webhook.js, replace SendGrid code with:
const { Resend } = require('resend');
const resend = new Resend(process.env.RESEND_API_KEY);

await resend.emails.send({
  from: 'Claude Sessions <hello@claudesessions.com>',
  to: email,
  subject: 'Your Claude Sessions License Key',
  html: htmlContent,
});
```

### No Email Provider

If you don't set up an email provider, the webhook will:
1. Log the license key to console
2. You'll need to manually send it to customers

## Step 5: Test the Webhook

1. In Stripe Dashboard → Webhooks → Your endpoint
2. Click **Send test webhook**
3. Select `checkout.session.completed`
4. Click **Send**
5. Check your server logs for the generated license key

## Step 6: Update Payment Link Success URL

After webhook is working, update your Payment Link:
1. Go to: https://dashboard.stripe.com/payment-links
2. Edit your Claude Sessions Credits link
3. Change success URL to:
   ```
   https://claudesessions.com/buy.html?success=true
   ```

The customer will see a success page telling them to check their email.

## Troubleshooting

### Webhook signature verification failed
- Make sure you're using the correct `STRIPE_WEBHOOK_SECRET`
- Ensure the raw request body is passed (not parsed JSON)

### No email received
- Check server logs for errors
- Verify SendGrid API key is correct
- Check spam folder

### License key not working
- Verify key format is `cs_` followed by 24 characters
- Check `~/.claudesessions/credits.json` for stored credits

## Environment Variables Summary

```bash
# Required
STRIPE_SECRET_KEY=sk_live_xxx
STRIPE_WEBHOOK_SECRET=whsec_xxx

# Optional (for email delivery)
SENDGRID_API_KEY=SG.xxx
FROM_EMAIL=hello@claudesessions.com
```

## Security Notes

- Never expose your `STRIPE_SECRET_KEY` in frontend code
- Always verify webhook signatures
- Use HTTPS for your webhook endpoint
- Store license keys in a database for tracking (optional)
