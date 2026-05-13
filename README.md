# My Dev Org

This is a Salesforce development project with automated CI/CD pipelines.

## Project Structure

- `src/` - Contains Apex classes and other Salesforce metadata
- `IlluminatedCloud/` - IDE configuration (excluded from git)
- `.github/workflows/` - GitHub Actions CI/CD workflows

## CI/CD Pipelines

This project includes automated GitHub Actions workflows:

- 🔄 **Continuous Integration** - Validates and tests on every push
- ✅ **PR Validation** - Automatically validates pull requests
- 🚀 **Automated Deployment** - Deploys to Salesforce on merge to main
- 🏭 **Production Pipeline** - Controlled production deployments

See [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md) for detailed setup instructions.

## Setup

1. Clone this repository
2. Configure GitHub Secrets for Salesforce authentication (see setup guide)
3. Configure your local Salesforce org connection
4. Deploy the metadata to your org

## Classes

- `ContactTriggerHandler` - Handles Contact trigger events
- `OrderProcessingService` - Service class for order processing

## Development Workflow

1. Create a feature branch from `develop`
2. Make your changes
3. Push your branch and create a pull request
4. GitHub Actions will automatically validate your changes
5. Once approved and merged, changes will be deployed automatically


