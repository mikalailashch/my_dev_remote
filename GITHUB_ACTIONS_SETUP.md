# GitHub Actions CI/CD Setup Guide

This project uses GitHub Actions for automated build and deployment to Salesforce.

## Workflows

### 1. Main CI/CD Pipeline (`deploy.yml`)
- **Triggers:** Push to `main` or `develop` branches, pull requests, manual dispatch
- **Actions:**
  - Installs Salesforce CLI
  - Authenticates to Salesforce
  - Runs Apex tests
  - Validates deployment on PRs
  - Deploys to org on push to main/develop

### 2. PR Validation (`pr-validation.yml`)
- **Triggers:** Pull requests to `main` or `develop`
- **Actions:**
  - Code scanning with PMD
  - Validation deployment (check-only)
  - Runs Apex tests
  - Comments on PR with results

### 3. Production Deployment (`production-deploy.yml`)
- **Triggers:** Release published, manual dispatch
- **Actions:**
  - Creates metadata backup
  - Deploys to production
  - Runs all tests
  - Verifies deployment status

## Setup Instructions

### Step 1: Generate Salesforce Auth URL

For each environment (sandbox, production), you need to generate an auth URL:

```bash
# Authenticate to your Salesforce org
sf org login web --alias myorg --set-default

# Generate the auth URL
sf org display --target-org myorg --verbose
```

Copy the "Sfdx Auth Url" value from the output.

### Step 2: Add GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add the following secrets:

1. **SALESFORCE_AUTH_URL** - Auth URL for your default org
2. **SALESFORCE_SANDBOX_AUTH_URL** - Auth URL for sandbox
3. **SALESFORCE_PROD_AUTH_URL** - Auth URL for production

#### How to add secrets:
1. Click "New repository secret"
2. Name: `SALESFORCE_AUTH_URL`
3. Value: Paste your Sfdx Auth URL
4. Click "Add secret"
5. Repeat for other environments

### Step 3: Configure Environments (Optional)

For production deployments, set up a protected environment:

1. Go to Settings → Environments
2. Create new environment named `production`
3. Add protection rules:
   - Required reviewers
   - Wait timer
   - Deployment branches (only `main`)

### Step 4: Test the Workflow

1. Make a change to your code
2. Create a pull request
3. Watch the PR validation workflow run
4. Merge the PR to trigger deployment

## Manual Deployment

You can manually trigger deployments:

1. Go to Actions tab
2. Select "Salesforce CI/CD" or "Production Deployment"
3. Click "Run workflow"
4. Select branch and environment
5. Click "Run workflow"

## Workflow Features

### Automatic Validation
- ✅ Runs Apex tests before deployment
- ✅ Validates metadata syntax
- ✅ Code coverage checks
- ✅ PMD static analysis

### Safe Deployment
- ✅ Dry-run validation on pull requests
- ✅ Test execution before production deployment
- ✅ Rollback capability with backup
- ✅ Manual approval for production (with environment protection)

### Monitoring
- ✅ Detailed logs for each step
- ✅ Deployment status notifications
- ✅ PR comments with validation results

## Troubleshooting

### Authentication Fails
- Verify the SFDX Auth URL is correct
- Make sure the Connected App is not expired
- Check if IP restrictions are preventing access

### Tests Fail
- Review the test results in the workflow logs
- Run tests locally: `sf apex run test --test-level RunLocalTests`
- Fix failing tests before redeploying

### Deployment Times Out
- Increase the `--wait` parameter in the workflow
- Default is 30 minutes, can increase to 60+

## Best Practices

1. **Always validate on PR** - Never merge without green checks
2. **Use environments** - Protect production with required reviews
3. **Monitor deployments** - Check workflow runs regularly
4. **Keep secrets secure** - Never commit auth URLs to code
5. **Test locally first** - Run `sf project deploy start --dry-run` before pushing

## Additional Resources

- [Salesforce CLI Documentation](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/)

