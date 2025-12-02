#!/bin/bash
# Build script for Cloudflare Pages
# Fetches full git history (needed for git-revision-date-localized plugin)
# and runs the complete mkdocs build process

set -e

echo "🚀 Starting build process..."

# Step 1: Fetch full git history for git-revision-date-localized plugin
# This is needed because Cloudflare Pages does shallow clones by default
echo "📥 Fetching full git history..."
if [ -f .git/shallow ]; then
    echo "   Detected shallow clone, fetching full history..."
    git fetch --unshallow || git fetch --all --unshallow || true
else
    echo "   Not a shallow clone, fetching all branches..."
    git fetch --all || true
fi

# Ensure we have all tags
git fetch --tags || true
echo "   ✓ Git history fetch complete."

# Step 2: Install dependencies
echo "📦 Installing dependencies..."
pip install -r requirements.txt
echo "   ✓ Dependencies installed."

# Step 3: Update navigation
echo "🗺️  Updating navigation..."
python3 scripts/update_mkdocs_nav.py
echo "   ✓ Navigation updated."

# Step 4: Build mkdocs site
echo "🏗️  Building mkdocs site..."
mkdocs build
echo "   ✓ Build complete!"

echo "✨ All done! Site ready for deployment."

