# Cloudflare Pages Setup Guide

This guide explains how to deploy the MkDocs website to Cloudflare Pages.

## Prerequisites

- A Cloudflare account (free tier works)
- GitHub repository access (already configured)
- Custom domain (optional, e.g., `<xyz>.itsecurity.network`)

## Step 1: Connect GitHub Repository to Cloudflare Pages

1. Log in to your [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Navigate to **Pages** in the left sidebar
3. Click **Create a project**
4. Select **Connect to Git**
5. Authorize Cloudflare to access your GitHub account if prompted
6. Select the repository: `samerfarida/secure-bash-macos-ebook`

## Step 2: Configure Build Settings

In the **Set up builds and deployments** section, configure:

### Framework Preset
- Select: **MkDocs** (Cloudflare will auto-detect this)

### Build Configuration
- **Production branch**: `main`
- **Build command**: `pip install -r requirements.txt && python3 scripts/update_mkdocs_nav.py && mkdocs build`
  - This command automatically updates the navigation structure from your file structure before building
  - New chapters are automatically included without manual `mkdocs.yml` updates
- **Build output directory**: `site`
- **Root directory**: `/` (leave as default)

### Environment Variables
Click **Environment variables (advanced)** and add:

| Variable Name | Value | Environment |
|--------------|-------|-------------|
| `PYTHON_VERSION` | `3.7` | Production, Preview, Branch Deploy |

**Note**: You can use Python 3.7 or higher. Cloudflare Pages supports Python 3.7, 3.8, 3.9, 3.10, 3.11, 3.12.

## Step 3: Deploy

1. Click **Save and Deploy**
2. Cloudflare will start the first build
3. The build process will:
   - Install Python dependencies from `requirements.txt`
   - Run `mkdocs build` to generate the static site
   - Deploy the `site/` directory contents

## Step 4: Access Your Site

After deployment completes:

- **Default URL**: `https://<project-name>.pages.dev`
- You'll receive a unique subdomain automatically
- The site will be live and accessible immediately

## Step 5: Configure Custom Domain (Optional)

To use your custom domain (e.g., `<xyz>.itsecurity.network`):

1. In your Cloudflare Pages project, go to **Custom domains**
2. Click **Set up a custom domain**
3. Enter your domain: `<xyz>.itsecurity.network`
4. Follow Cloudflare's DNS configuration instructions:
   - Add a CNAME record pointing to your Pages project
   - Or use Cloudflare's automatic DNS configuration if your domain is already on Cloudflare
5. SSL certificate will be automatically provisioned (may take a few minutes)

### DNS Configuration Example

If your domain is managed elsewhere:

```
Type: CNAME
Name: <xyz> (or @ for root domain)
Target: <project-name>.pages.dev
```

If your domain is on Cloudflare:

- Cloudflare will automatically configure DNS
- SSL will be provisioned automatically

## Automatic Deployments

Cloudflare Pages automatically:

- **Builds on every push** to the `main` branch (production)
- **Creates preview deployments** for pull requests
- **Redeploys** when you merge PRs to main

## Monitoring Builds

- View build logs in the Cloudflare Pages dashboard
- Each deployment shows:
  - Build status (success/failure)
  - Build duration
  - Deployment URL
  - Commit hash and message

## Troubleshooting

### Build Fails

1. Check build logs in Cloudflare dashboard
2. Common issues:
   - **Python version mismatch**: Ensure `PYTHON_VERSION` is set correctly
   - **Missing dependencies**: Verify `requirements.txt` is up to date
   - **YAML syntax errors**: Check `mkdocs.yml` for syntax issues (run `python3 scripts/update_mkdocs_nav.py` locally to regenerate)
   - **Missing files**: Ensure all markdown files referenced in `mkdocs.yml` exist
   - **Navigation script fails**: The `update_mkdocs_nav.py` script runs automatically during build. If it fails, check that all markdown files have valid H1 headings

### Site Not Updating

- Wait a few minutes for DNS propagation (if using custom domain)
- Clear browser cache
- Check that the latest commit was pushed to `main` branch
- Verify build succeeded in Cloudflare dashboard

### Custom Domain Issues

- Verify DNS records are correct (CNAME pointing to Pages project)
- Wait for SSL certificate provisioning (can take up to 24 hours, usually much faster)
- Check domain status in Cloudflare Pages dashboard

## Local Testing Before Deployment

Before pushing to GitHub, test locally:

```bash
# Activate virtual environment (if using one)
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Build the site
mkdocs build

# Serve locally to preview
mkdocs serve
```

Visit `http://localhost:8000` to preview your site.

## Additional Resources

- [Cloudflare Pages Documentation](https://developers.cloudflare.com/pages/)
- [MkDocs Documentation](https://www.mkdocs.org/)
- [MkDocs Material Theme](https://squidfunk.github.io/mkdocs-material/)

## Notes

- The `site/` directory is build output and is automatically ignored by git (see `.gitignore`)
- Cloudflare Pages builds are independent of the PDF/EPUB/HTML generation workflow
- Both workflows (website and ebook formats) can coexist without conflicts
- Builds typically take 1-3 minutes depending on site size

