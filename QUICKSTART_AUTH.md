# Quick Start: Setting Up Salesforce Auth for GitHub Actions

## The Problem You're Seeing

If you see this error:
```
Error (INVALID_SFDX_AUTH_URL): Invalid SFDX authorization URL
```

It means the GitHub secret for Salesforce authentication is not configured yet.

## Quick Fix (5 minutes)

### Step 1: Get Your Auth URL

Run these commands in your terminal:

```bash
# Login to your Salesforce org (opens browser)
sf org login web --alias myorg --set-default

# Get the auth URL (copy this entire output)
sf org display --target-org myorg --verbose | grep "Sfdx Auth Url"
```

You should see something like:
```
Sfdx Auth Url    force://PlatformCLI::5Aep...LONG_STRING...@mycompany.my.salesforce.com
```

**Copy the entire URL starting with `force://`**

### Step 2: Add Secret to GitHub

1. Go to your GitHub repository
2. Click **Settings** (top menu)
3. Click **Secrets and variables** → **Actions** (left sidebar)
4. Click **New repository secret**
5. For the first secret:
   - Name: `SALESFORCE_AUTH_URL`
   - Value: Paste the auth URL you copied (the entire `force://...` string)
   - Click **Add secret**

### Step 3: Repeat for Other Environments (Optional)

If you want separate environments, repeat Step 1-2 for:
- **SALESFORCE_SANDBOX_AUTH_URL** (for sandbox org)
- **SALESFORCE_PROD_AUTH_URL** (for production org)

For each, login to that specific org first:
```bash
# For sandbox
sf org login web --alias sandbox --instance-url https://test.salesforce.com

# For production
sf org login web --alias production --instance-url https://login.salesforce.com
```

Then get the auth URL and add as a secret.

### Step 4: Test It

1. Push a change to your repository
2. Go to **Actions** tab
3. Watch the workflow run
4. It should now authenticate successfully! ✅

## Important Notes

⚠️ **Never commit the auth URL to your code!** Always use GitHub Secrets.

⚠️ **Auth URLs expire** when you refresh the Connected App. You'll need to regenerate them.

⚠️ **Format matters** - The URL must start with `force://` and follow this pattern:
```
force://<clientId>:<clientSecret>:<refreshToken>@<instanceUrl>
```

## Alternative: Use JWT Bearer Flow (More Secure)

For production, consider using JWT authentication instead:

1. Create a Connected App in Salesforce
2. Upload a certificate
3. Use `sf org login jwt` instead

See: https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_auth_jwt_flow.htm

## Still Having Issues?

### Check if secret is set correctly:
1. Go to Settings → Secrets → Actions
2. You should see your secret listed (value is hidden)
3. If wrong, delete and recreate it

### Check the auth URL format:
```bash
# Should show your org info
sf org display --target-org myorg
```

### Test locally first:
```bash
# Create test auth file
echo "YOUR_AUTH_URL_HERE" > test-auth.txt

# Try to authenticate
sf org login sfdx-url --sfdx-url-file test-auth.txt --alias test-org

# Clean up
rm test-auth.txt
```

## Need Help?

Check the full setup guide: [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md)

