# How to Publish to GitHub (FREE)

## Step 1: Create GitHub Account
1. Go to [github.com](https://github.com)
2. Sign up for free account
3. Verify your email

## Step 2: Create New Repository
1. Click "+" → "New repository"
2. Repository name: `lostAndFinder`
3. Description: "Lost & Found Community App for Sri Lanka"
4. Choose: **Public** (free) or Private (requires payment for Actions)
5. ✅ Don't check "Initialize with README" (we already have one)
6. Click "Create repository"

## Step 3: Prepare Your Local Project

```powershell
# Navigate to your project
cd d:\lostAndFinder

# Initialize Git (if not already)
git init

# Add all files
git add .

# First commit
git commit -m "Initial commit: Lost & Found App v1.0.0"

# Add GitHub as remote
git remote add origin https://github.com/pirinthaban/lostAndFinder.git

# Push to GitHub
git branch -M main
git push -u origin main
```

## Step 4: Verify Upload
1. Go to your GitHub repository
2. You should see all files uploaded
3. Check that `.gitignore` is working (no `key.properties`, `.env`, etc.)

## Step 5: Protect Sensitive Data
Before pushing, verify these files are NOT uploaded:
- ❌ `key.properties`
- ❌ `.env`
- ❌ `google-services.json`
- ❌ `*.keystore` / `*.jks`
- ✅ `.env.example` (this is OK)
- ✅ `firebase_options.dart` (placeholder values only)

## Step 6: Add Repository Details

### Edit README.md
Replace these placeholders in `README.md`:
- `YOUR_USERNAME` → Your GitHub username
- `your.email@example.com` → Your email (optional)

### Create Repository Topics
In GitHub repo settings, add topics:
- `flutter`
- `firebase`
- `lost-and-found`
- `sri-lanka`
- `mobile-app`
- `open-source`

### Add Repository Description
"🔍 Open-source Lost & Found community app for Sri Lanka with AI-powered matching, offline support, and trust-driven ecosystem"

## Step 7: Enable GitHub Actions (CI/CD)
1. Go to repository → Actions tab
2. GitHub Actions should auto-detect Flutter
3. Our workflow (`.github/workflows/flutter-ci.yml`) will run automatically on push

## Step 8: Create Releases
When ready to release:

```powershell
# Tag your version
git tag v1.0.0

# Push tag
git push origin v1.0.0
```

Then on GitHub:
1. Go to Releases → "Create a new release"
2. Choose tag: `v1.0.0`
3. Title: "v1.0.0 - Initial Release"
4. Description: Copy from `CHANGELOG.md`
5. Upload APK/AAB files (optional)

## Step 9: Share Your Project
Add to your repository:
- ✅ Good README with screenshots
- ✅ LICENSE file (MIT)
- ✅ CONTRIBUTING.md
- ✅ GitHub Issues enabled
- ✅ GitHub Discussions enabled (Settings → Features)

## Continuous Development

### Daily Workflow
```powershell
# Make changes to code
# ...

# Check status
git status

# Add changes
git add .

# Commit with clear message
git commit -m "Add: feature description"

# Push to GitHub
git push
```

### Branch Strategy (Optional)
```powershell
# Create feature branch
git checkout -b feature/new-feature

# Work on feature
# ...

# Push feature branch
git push -u origin feature/new-feature

# Create Pull Request on GitHub
# Merge after review
```

## Free Hosting Options

### 1. GitHub Pages (Web Version)
```powershell
# Build for web
flutter build web --base-href "/lostAndFinder/"

# Push to gh-pages branch
git checkout --orphan gh-pages
git reset --hard
cp -r build/web/* .
git add .
git commit -m "Deploy to GitHub Pages"
git push origin gh-pages --force

# Enable in Settings → Pages → Source: gh-pages
```
Your app will be at: `https://pirinthaban.github.io/lostAndFinder/`

### 2. Firebase Hosting (Recommended)
```powershell
# Build
flutter build web

# Deploy (free 10GB/month)
firebase deploy --only hosting
```

### 3. Netlify (Alternative)
1. Connect GitHub repo to Netlify
2. Build command: `flutter build web`
3. Publish directory: `build/web`
4. Deploy automatically on push

## Cost: $0 💰
Everything above is **completely FREE**:
- ✅ GitHub (public repos)
- ✅ GitHub Actions (2000 minutes/month free)
- ✅ Firebase Spark Plan (Hosting + Auth + Firestore limits)
- ✅ GitHub Pages
- ✅ Netlify free tier

## Need Help?
- Read: [GitHub Docs](https://docs.github.com)
- Ask: Open an issue or discussion
- Watch: [Flutter + GitHub tutorial](https://www.youtube.com/results?search_query=flutter+github+tutorial)

## Security Checklist Before Pushing
- [ ] No passwords in code
- [ ] No API keys committed
- [ ] `.gitignore` includes `.env`, `key.properties`
- [ ] `firebase_options.dart` has placeholder values only
- [ ] No `google-services.json` uploaded
- [ ] No keystore files (`.jks`, `.keystore`)
- [ ] All secrets in `.env.example` are fake examples

---

**You're ready to share your project with the world! 🚀**
