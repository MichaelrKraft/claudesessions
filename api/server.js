/**
 * Claude Sessions Webhook Server
 *
 * Deploy to Render as a Web Service
 *
 * Environment Variables needed in Render:
 *   STRIPE_SECRET_KEY=sk_live_xxx
 *   STRIPE_WEBHOOK_SECRET=whsec_xxx
 *   SENDGRID_API_KEY=SG.xxx (optional)
 *   FROM_EMAIL=hello@claudesessions.com (optional)
 *   PORT=10000 (Render sets this automatically)
 */

const express = require('express');
const crypto = require('crypto');

const app = express();
const PORT = process.env.PORT || 3000;

// Initialize Stripe
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

// Generate a unique license key
function generateLicenseKey() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let key = 'cs_';
    for (let i = 0; i < 24; i++) {
        key += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return key;
}

// Send email with license key
async function sendLicenseEmail(email, licenseKey) {
    // Using SendGrid
    if (process.env.SENDGRID_API_KEY) {
        const sgMail = require('@sendgrid/mail');
        sgMail.setApiKey(process.env.SENDGRID_API_KEY);

        try {
            await sgMail.send({
                to: email,
                from: process.env.FROM_EMAIL || 'hello@claudesessions.com',
                subject: 'Your Claude Sessions License Key',
                text: `
Thank you for purchasing Claude Sessions credits!

Your License Key: ${licenseKey}

To activate, run this command in your terminal:

    sessions activate ${licenseKey}

You now have 20 session restores. Use them anytime with:

    sessions continue <session-name>

Questions? Reply to this email.

- Claude Sessions
https://claudesessions.com
                `.trim(),
                html: `
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0a0a0f; color: #ffffff; padding: 40px; }
        .container { max-width: 500px; margin: 0 auto; }
        .logo { font-size: 24px; font-weight: bold; margin-bottom: 30px; }
        .logo span { color: #d97706; }
        .key-box { background: #1a1a24; border: 1px solid #2a2a3a; border-radius: 8px; padding: 20px; margin: 20px 0; }
        .key { font-family: monospace; font-size: 18px; color: #d97706; word-break: break-all; }
        .command { background: #12121a; padding: 15px; border-radius: 6px; font-family: monospace; color: #22c55e; margin: 15px 0; }
        .footer { margin-top: 30px; color: #a0a0b0; font-size: 14px; }
        a { color: #d97706; }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">claude<span>sessions</span></div>

        <p>Thank you for purchasing Claude Sessions credits!</p>

        <div class="key-box">
            <p style="margin: 0 0 10px 0; color: #a0a0b0; font-size: 14px;">Your License Key:</p>
            <div class="key">${licenseKey}</div>
        </div>

        <p>To activate, run this command in your terminal:</p>
        <div class="command">sessions activate ${licenseKey}</div>

        <p>You now have <strong>20 session restores</strong>. Use them anytime with:</p>
        <div class="command">sessions continue &lt;session-name&gt;</div>

        <div class="footer">
            <p>Questions? Reply to this email.</p>
            <p>- Claude Sessions<br><a href="https://claudesessions.com">claudesessions.com</a></p>
        </div>
    </div>
</body>
</html>
                `.trim(),
            });
            console.log('Email sent successfully to:', email);
            return true;
        } catch (err) {
            console.error('SendGrid error:', err);
            return false;
        }
    }

    // Fallback: just log the key
    console.log('=== LICENSE KEY GENERATED ===');
    console.log('Email:', email);
    console.log('Key:', licenseKey);
    console.log('Activation command: sessions activate ' + licenseKey);
    console.log('=============================');
    return true;
}

// Health check endpoint
app.get('/', (req, res) => {
    res.json({
        status: 'ok',
        service: 'Claude Sessions Webhook',
        timestamp: new Date().toISOString()
    });
});

app.get('/health', (req, res) => {
    res.json({ status: 'healthy' });
});

// Stripe webhook endpoint - MUST use raw body
app.post('/webhook', express.raw({ type: 'application/json' }), async (req, res) => {
    const sig = req.headers['stripe-signature'];
    let event;

    try {
        event = stripe.webhooks.constructEvent(
            req.body,
            sig,
            process.env.STRIPE_WEBHOOK_SECRET
        );
    } catch (err) {
        console.error('Webhook signature verification failed:', err.message);
        return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    // Handle the checkout.session.completed event
    if (event.type === 'checkout.session.completed') {
        const session = event.data.object;
        const email = session.customer_details?.email || session.customer_email;

        if (!email) {
            console.error('No email found in checkout session');
            return res.status(400).json({ error: 'No email found' });
        }

        // Generate license key
        const licenseKey = generateLicenseKey();

        // Log the purchase
        console.log('=== PURCHASE COMPLETED ===');
        console.log('Session ID:', session.id);
        console.log('Email:', email);
        console.log('License Key:', licenseKey);
        console.log('Amount:', (session.amount_total / 100).toFixed(2));
        console.log('Time:', new Date().toISOString());
        console.log('==========================');

        // Send email
        await sendLicenseEmail(email, licenseKey);
    }

    res.json({ received: true });
});

// Start server
app.listen(PORT, () => {
    console.log(`Claude Sessions Webhook Server running on port ${PORT}`);
    console.log('Endpoints:');
    console.log('  GET  /        - Health check');
    console.log('  GET  /health  - Health check');
    console.log('  POST /webhook - Stripe webhook');
});
