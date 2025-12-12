/**
 * Stripe Webhook Handler for Claude Sessions
 *
 * Automatically generates and emails license keys after purchase.
 *
 * Deploy to: Vercel, Netlify Functions, or any Node.js server
 *
 * Required Environment Variables:
 *   STRIPE_SECRET_KEY=sk_live_xxx
 *   STRIPE_WEBHOOK_SECRET=whsec_xxx
 *   SENDGRID_API_KEY=SG.xxx (or use another email provider)
 *   FROM_EMAIL=hello@claudesessions.com
 */

const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const crypto = require('crypto');

// Generate a unique license key
function generateLicenseKey() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let key = 'cs_';
    for (let i = 0; i < 24; i++) {
        key += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return key;
}

// Send email with license key (using SendGrid)
async function sendLicenseEmail(email, licenseKey) {
    // Option 1: SendGrid
    if (process.env.SENDGRID_API_KEY) {
        const sgMail = require('@sendgrid/mail');
        sgMail.setApiKey(process.env.SENDGRID_API_KEY);

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
            <p>- Claude Sessions<br><a href="https://claudesessions.com" style="color: #d97706;">claudesessions.com</a></p>
        </div>
    </div>
</body>
</html>
            `.trim(),
        });
        return true;
    }

    // Option 2: Log for manual sending (fallback)
    console.log('=== LICENSE KEY GENERATED ===');
    console.log('Email:', email);
    console.log('Key:', licenseKey);
    console.log('=============================');
    return true;
}

// Main webhook handler
module.exports = async (req, res) => {
    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
    }

    const sig = req.headers['stripe-signature'];
    let event;

    try {
        // Verify webhook signature
        event = stripe.webhooks.constructEvent(
            req.body,
            sig,
            process.env.STRIPE_WEBHOOK_SECRET
        );
    } catch (err) {
        console.error('Webhook signature verification failed:', err.message);
        return res.status(400).json({ error: `Webhook Error: ${err.message}` });
    }

    // Handle successful payment
    if (event.type === 'checkout.session.completed') {
        const session = event.data.object;

        // Get customer email
        const email = session.customer_details?.email || session.customer_email;

        if (!email) {
            console.error('No email found in session:', session.id);
            return res.status(400).json({ error: 'No email found' });
        }

        // Generate license key
        const licenseKey = generateLicenseKey();

        // Log the purchase (you might want to store this in a database)
        console.log('Purchase completed:', {
            sessionId: session.id,
            email: email,
            licenseKey: licenseKey,
            amount: session.amount_total / 100,
            timestamp: new Date().toISOString(),
        });

        // Send email with license key
        try {
            await sendLicenseEmail(email, licenseKey);
            console.log('License email sent to:', email);
        } catch (emailErr) {
            console.error('Failed to send email:', emailErr);
            // Don't fail the webhook - key is logged
        }
    }

    res.status(200).json({ received: true });
};

// For Express.js (if not using serverless)
module.exports.expressHandler = (app) => {
    app.post('/api/webhook',
        require('express').raw({ type: 'application/json' }),
        module.exports
    );
};
