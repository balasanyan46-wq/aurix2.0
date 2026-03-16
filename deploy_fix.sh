#!/bin/bash

# AURIX 2.0 - Deploy Rendering Fix
# This script commits and pushes the z-index fixes to GitHub Pages

set -e  # Exit on error

echo "🚀 AURIX 2.0 - Deploying Rendering Fix"
echo "======================================"
echo ""

# Navigate to gh-pages worktree
cd "$(dirname "$0")/.gh-pages-worktree"

echo "📁 Current directory: $(pwd)"
echo ""

# Check git status
echo "📊 Checking git status..."
git status --short
echo ""

# Confirm changes
echo "📝 Files to be committed:"
echo "  - aurix_fx.css (z-index fixes)"
echo "  - index.html (loading screen timeout)"
echo ""

read -p "❓ Do you want to commit and push these changes? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled."
    exit 1
fi

echo ""
echo "✅ Proceeding with deployment..."
echo ""

# Stage changes
echo "📦 Staging changes..."
git add aurix_fx.css index.html

# Commit
echo "💾 Creating commit..."
git commit -m "Fix: Ensure Flutter content renders above FX layers

- Add z-index rules to force flt-glass-pane above background effects
- Add timeout fallback for loading screen removal
- Fixes issue where content was hidden behind CSS overlays

Technical details:
- flt-glass-pane now has z-index: 100 (was auto/5)
- Loading screen has explicit z-index: 9999
- Added 15s timeout fallback for flutter-first-frame event
- Applied to both deployed and source files

Expected result: Page content now visible, background effects behind"

# Push to GitHub Pages
echo "🌐 Pushing to GitHub Pages..."
git push origin gh-pages

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Next steps:"
echo "  1. Wait 2-3 minutes for GitHub Pages to update"
echo "  2. Visit: https://balasanyan46-wq.github.io/aurix2.0/"
echo "  3. Hard refresh: Ctrl+Shift+R (Windows) or Cmd+Shift+R (Mac)"
echo "  4. Verify content is visible"
echo ""
echo "📖 For detailed testing instructions, see:"
echo "  - TESTING_INSTRUCTIONS.md"
echo "  - FIX_SUMMARY.md"
echo ""
echo "🎉 Done!"
