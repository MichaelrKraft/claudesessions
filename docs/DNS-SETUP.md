# DNS Setup for claudesessions.com

This guide walks you through connecting your GoDaddy domain to your Render-hosted landing page.

## Step 1: Deploy to Render

1. Go to [render.com](https://render.com) and sign in
2. Click **New** → **Static Site**
3. Connect your GitHub repository: `michaelcraft/claudesessions`
4. Configure the site:
   - **Name**: `claudesessions`
   - **Branch**: `main`
   - **Root Directory**: `web`
   - **Build Command**: (leave empty for static HTML)
   - **Publish Directory**: `.`
5. Click **Create Static Site**
6. Wait for the initial deploy to complete
7. Note your Render URL (e.g., `claudesessions.onrender.com`)

## Step 2: Add Custom Domain in Render

1. In your Render dashboard, go to your static site
2. Click **Settings** → **Custom Domains**
3. Click **Add Custom Domain**
4. Enter: `claudesessions.com`
5. Render will show you the required DNS records:
   - **Type**: `A` or `CNAME`
   - **Value**: Render's IP or hostname

For apex domain (claudesessions.com), you'll typically see:
```
Type: A
Name: @
Value: 216.24.57.1  (or similar - use what Render shows)
```

For www subdomain:
```
Type: CNAME
Name: www
Value: claudesessions.onrender.com
```

## Step 3: Configure DNS in GoDaddy

1. Log in to [godaddy.com](https://godaddy.com)
2. Go to **My Products** → Find `claudesessions.com` → **DNS**
3. You'll see the DNS Management page

### Add the A Record (for root domain):

1. Click **Add** under Records
2. Configure:
   - **Type**: A
   - **Name**: `@`
   - **Value**: The IP address from Render (e.g., `216.24.57.1`)
   - **TTL**: 600 seconds (or 1 hour)
3. Click **Save**

### Add the CNAME Record (for www):

1. Click **Add** under Records
2. Configure:
   - **Type**: CNAME
   - **Name**: `www`
   - **Value**: `claudesessions.onrender.com`
   - **TTL**: 1 hour
3. Click **Save**

### Remove Conflicting Records (if any):

If GoDaddy has default "parked" records, remove:
- Any existing A records pointing to GoDaddy parking
- Any existing CNAME for www pointing elsewhere

## Step 4: Verify DNS Propagation

DNS changes can take 15 minutes to 48 hours to propagate globally.

### Quick Check Methods:

**Using dig (Terminal):**
```bash
dig claudesessions.com
dig www.claudesessions.com
```

**Using online tools:**
- [whatsmydns.net](https://www.whatsmydns.net)
- [dnschecker.org](https://dnschecker.org)

### Expected Results:

```
claudesessions.com      A     216.24.57.1
www.claudesessions.com  CNAME claudesessions.onrender.com
```

## Step 5: Verify SSL Certificate

Render automatically provisions SSL certificates via Let's Encrypt.

1. Go to your Render dashboard
2. Click on your static site
3. Go to **Settings** → **Custom Domains**
4. Wait for the SSL status to show **Certificate Issued** (green checkmark)

This may take a few minutes after DNS propagates.

## Step 6: Test Your Site

Once DNS propagates and SSL is issued:

1. Visit `https://claudesessions.com` - should show your landing page
2. Visit `https://www.claudesessions.com` - should redirect or show same page
3. Visit `http://claudesessions.com` - should redirect to HTTPS

## Troubleshooting

### "DNS records not found"
- Wait longer (up to 48 hours for full propagation)
- Verify you saved the records in GoDaddy
- Check for typos in the values

### "SSL certificate pending"
- DNS must propagate first
- Wait up to 24 hours
- Check Render dashboard for specific errors

### "Site not loading"
- Clear browser cache
- Try incognito/private window
- Verify Render deploy succeeded

### "Wrong site showing"
- Old DNS cache - wait or flush DNS:
  ```bash
  # macOS
  sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

  # Windows
  ipconfig /flushdns
  ```

## Quick Reference: Final DNS Records

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | @ | (Render's IP) | 1 hour |
| CNAME | www | claudesessions.onrender.com | 1 hour |

## Need Help?

- [Render Custom Domains Docs](https://render.com/docs/custom-domains)
- [GoDaddy DNS Help](https://www.godaddy.com/help/manage-dns-records-680)
