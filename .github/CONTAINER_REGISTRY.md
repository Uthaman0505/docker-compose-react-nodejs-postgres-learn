# GitHub Container Registry Setup

## 🔧 Automatic Configuration

The GitHub Actions workflow is already configured with proper authentication using `GITHUB_TOKEN`. No additional setup is required for basic functionality.

## 📦 Image Naming Convention

Your images will be automatically published to:
- **Server**: `ghcr.io/YOUR_USERNAME/YOUR_REPOSITORY/server:latest`
- **Client**: `ghcr.io/YOUR_USERNAME/YOUR_REPOSITORY/client:latest`

## 🏷️ Tagging Strategy

The workflow creates multiple tags automatically:

### Branch-based Tags
- `main` - Latest main branch build
- `develop` - Latest develop branch build  
- `feature-xyz` - Feature branch builds

### Pull Request Tags
- `pr-123` - Pull request #123 build

### Release Tags
- `v1.0.0` - Version tag builds
- `v2.1.3` - Semantic version releases

### Commit-based Tags
- `main-abc1234` - Specific commit builds
- `develop-xyz5678` - Commit tracking

## 🔐 Repository Settings

### Required Permissions
The workflow needs these permissions (already configured):
```yaml
permissions:
  contents: read      # Read repository code
  packages: write     # Push to GitHub Container Registry
  security-events: write  # Upload security scan results
```

### Package Visibility Settings

After your first build, configure package visibility:

1. Go to your repository on GitHub
2. Click **Packages** in the right sidebar  
3. Click on your package (server or client)
4. Go to **Package settings**
5. Choose visibility:
   - **Public**: Anyone can pull (recommended for open source)
   - **Private**: Only repository collaborators can pull

## 🚀 Usage Examples

### Pull Latest Development Images
```bash
docker pull ghcr.io/username/repository/server:latest
docker pull ghcr.io/username/repository/client:latest
```

### Pull Specific Version
```bash
docker pull ghcr.io/username/repository/server:v1.0.0
docker pull ghcr.io/username/repository/client:v1.0.0
```

### Pull Feature Branch
```bash
docker pull ghcr.io/username/repository/server:feature-auth
docker pull ghcr.io/username/repository/client:feature-auth
```

## 🔑 Authentication for Production Servers

### Create Personal Access Token
1. Go to: https://github.com/settings/tokens
2. Click **Generate new token (classic)**
3. Select scopes: `read:packages`
4. Copy the token

### Login on Production Server
```bash
docker login ghcr.io -u YOUR_GITHUB_USERNAME
# Enter your Personal Access Token when prompted
```

### Test Authentication
```bash
docker pull ghcr.io/username/repository/server:latest
```

## 🎯 Deployment Integration

### Production Docker Compose
Update `docker-compose.prod.yml` with your actual repository name:

```yaml
services:
  server:
    image: ghcr.io/YOUR_USERNAME/YOUR_REPOSITORY/server:latest
  client:
    image: ghcr.io/YOUR_USERNAME/YOUR_REPOSITORY/client:latest
```

### Automated Deployment
```bash
# Pull latest images and deploy
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

## 📊 Monitoring

### Check Build Status
- Go to **Actions** tab in your repository
- View workflow runs and build logs
- Monitor for build failures

### Manage Package Storage
- View storage usage in repository Packages section
- Delete old image versions to save space
- Set up automated cleanup policies

## 🛠️ Troubleshooting

### Common Issues

**Authentication Failed**
```bash
Error: denied: permission_denied
```
- Verify Personal Access Token has `read:packages` scope
- Check if package is public or if you're authenticated
- Ensure token hasn't expired

**Image Not Found**
```bash
Error: pull access denied for ghcr.io/username/repo/server
```
- Verify image name matches exactly (case-sensitive)
- Check if the build completed successfully
- Ensure you have access to the repository

**Build Failures**
- Check Actions tab for detailed error logs
- Verify Dockerfiles are valid
- Check if all required files are present in build context

### Debug Commands
```bash
# List available images
docker search ghcr.io/USERNAME/REPOSITORY

# Inspect image details  
docker inspect ghcr.io/username/repository/server:latest

# Check authentication status
docker system info | grep -i registry
```

## 🔄 Best Practices

1. **Use specific tags** for production deployments (not `latest`)
2. **Regular cleanup** of old image versions
3. **Monitor security** scan results from Trivy
4. **Test images** before deploying to production
5. **Document breaking changes** in release notes

## 📞 Support

If you encounter issues:
1. Check the GitHub Actions logs
2. Verify repository permissions
3. Test with a simple docker pull command
4. Check package visibility settings
