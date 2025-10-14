# GitHub Actions Setup Guide

This guide will help you set up GitHub Actions for automated testing and deployment of the MyBartenderAI backend.

## Prerequisites

1. Azure Function App already created (`func-mba-fresh`)
2. GitHub repository with push access
3. Azure account with permissions to download publish profile

## Setup Steps

### 1. Get Azure Publish Profile

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to your Function App: `func-mba-fresh`
3. In the Overview page, click **"Get publish profile"** in the top menu
4. Save the downloaded file (it's XML content)

### 2. Add GitHub Secret

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **"New repository secret"**
4. Name: `AZURE_FUNCTIONAPP_PUBLISH_PROFILE`
5. Value: Paste the entire contents of the publish profile XML
6. Click **"Add secret"**

### 3. Verify Workflows

The repository now has two workflows:

#### `.github/workflows/backend-test.yml`
- Runs on every pull request
- Runs tests and linting
- Ensures code quality before merge

#### `.github/workflows/backend-deploy.yml`
- Runs on push to main branch
- Only triggers when backend files change
- Builds on Windows (matching production)
- Deploys to Azure Functions

### 4. First Deployment

1. Make a small change to any file in `apps/backend/`
2. Commit and push to main branch
3. Go to GitHub → Actions tab
4. Watch the deployment workflow run

## Workflow Features

### Automatic Triggers
- **Test workflow**: Runs on all PRs affecting backend
- **Deploy workflow**: Runs on main branch pushes affecting backend
- **Manual trigger**: Use "Run workflow" button in Actions tab

### Build Optimization
- Uses Windows runner (matches Azure Functions environment)
- Caches npm dependencies for faster builds
- Only builds production dependencies for deployment

### Deployment Package
The workflow automatically:
1. Installs dependencies (Windows-compatible)
2. Compiles TypeScript
3. Creates proper function structure
4. Deploys to Azure

## Monitoring

### GitHub Actions
- Check workflow runs in the Actions tab
- Green checkmark = successful deployment
- Red X = failed (check logs)

### Azure Portal
- Function App → Deployment Center → Logs
- Application Insights → Live Metrics
- Function App → Functions → Monitor

## Troubleshooting

### Common Issues

1. **"Publish profile not found"**
   - Ensure secret name is exactly `AZURE_FUNCTIONAPP_PUBLISH_PROFILE`
   - Re-download and update the secret

2. **"Function app not found"**
   - Check `AZURE_FUNCTIONAPP_NAME` in workflow matches your app
   - Ensure publish profile is from the correct app

3. **"Build failed"**
   - Check Node.js version matches (currently 20.x)
   - Ensure all TypeScript compiles locally first

### Manual Deployment (Fallback)

If GitHub Actions fails, you can still deploy manually:

```powershell
cd apps/backend
npm install
npm run build
# Create deployment package
# ... (see previous deployment steps)
az functionapp deployment source config-zip -g rg-mba-prod -n func-mba-fresh --src deploy.zip
```

## Security Notes

- Publish profile contains deployment credentials
- Never commit it to the repository
- Rotate it periodically (re-download and update secret)
- Use environment-specific profiles for staging/production

## Next Steps

1. Set up branch protection rules
2. Add status checks requiring tests to pass
3. Consider adding staging environment
4. Add mobile app CI/CD workflow
