# 🚀 Publishing FindBack to GitHub Pages - Quick Guide

## ✅ Completed Steps

1. ✅ **Package name updated** to `com.findback.app`
2. ✅ **GitHub Pages website created** with legal documents
3. ✅ **App icon configured**
4. ✅ **App name changed** to "FindBack"

---

## 📋 Next Steps to Publish

### Step 1: Create Signing Keystore (5 minutes)

Open PowerShell in project root and run:

```powershell
keytool -genkey -v -keystore android\app\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**You'll be asked:**
- Keystore password: (choose a strong password, save it!)
- Key password: (same or different, save it!)
- Name, Organization, City, State, Country: (fill in your details)

**⚠️ SAVE THIS INFO SECURELY:**
```
Keystore Password: _________________
Key Password: _________________
Keystore Location: android/app/upload-keystore.jks
Key Alias: upload
```

### Step 2: Configure App Signing

Create file: `android/key.properties` (this file will be gitignored)

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

Update `android/app/build.gradle.kts` to use the keystore (I'll do this for you).

### Step 3: Build Signed APK

```powershell
flutter build apk --release
```

The signed APK will be at: `build\app\outputs\flutter-apk\app-release.apk`

### Step 4: Enable GitHub Pages

1. Go to GitHub repository settings
2. Navigate to **Pages** section
3. Source: **Deploy from a branch**
4. Branch: **main** or **master**
5. Folder: **/ (root)** or **/docs**
6. Click **Save**

Your site will be live at: `https://pirinthaban.github.io/FindBack/`

### Step 5: Create GitHub Release

1. Go to your GitHub repository
2. Click **Releases** → **Create a new release**
3. Tag version: `v1.0.0`
4. Release title: `FindBack v1.0.0 - Initial Release`
5. Description:
```markdown
# FindBack v1.0.0 - Lost & Found Community App

## 🎉 First Public Release

**What's FindBack?**
A free, open-source Lost & Found community app for Sri Lanka with AI-powered matching, secure messaging, and privacy-first design.

## 📥 Download

Download the APK below and install on your Android device (Android 5.0+)

## ✨ Features
- 📸 Post lost/found items with photos
- 🤖 AI-powered automatic matching
- 💬 Secure encrypted chat
- 🔒 Privacy protection (auto-blur sensitive data)
- 📍 Location-based search
- ✅ Ownership verification system

## 📱 Requirements
- Android 5.0 (Lollipop) or higher
- Internet connection
- Phone number for verification

## 🔗 Links
- 🌐 Website: https://pirinthaban.github.io/FindBack/
- 📖 Privacy Policy: https://pirinthaban.github.io/FindBack/privacy-policy.html
- 📜 Terms: https://pirinthaban.github.io/FindBack/terms-and-conditions.html
- 🐛 Issues: https://github.com/pirinthaban/FindBack/issues

## ⚠️ Note
This is an early release. Please report bugs and provide feedback!
```

6. **Upload APK**: Drag `app-release.apk` to the release assets
7. Click **Publish release**

### Step 6: Update README Links

Update your README.md to include:
- Link to GitHub Pages website
- Link to latest release for APK download
- Privacy Policy and Terms URLs

---

## 🎯 Publishing to Google Play Store (Optional)

If you want to publish on Play Store later:

1. **Create Google Play Developer Account** ($25 one-time fee)
2. **Prepare Store Listing:**
   - App name: FindBack
   - Short description: "Lost & Found community app"
   - Full description: (see PLAY_STORE_DESCRIPTION.md)
   - Screenshots: 2-8 phone screenshots
   - Feature graphic: 1024x500px
   - App icon: 512x512px
3. **Upload AAB** (not APK):
   ```powershell
   flutter build appbundle --release
   ```
4. **Set up content rating** (everyone)
5. **Fill privacy policy URL**: https://pirinthaban.github.io/FindBack/privacy-policy.html
6. **Submit for review** (takes 1-7 days)

---

## 📊 Quick Checklist

- [ ] Create keystore
- [ ] Configure signing
- [ ] Build signed APK
- [ ] Enable GitHub Pages (docs folder)
- [ ] Create GitHub Release with APK
- [ ] Test APK installation
- [ ] Update README with links
- [ ] Announce on social media 🎉

---

## 🔗 Your URLs After Publishing

- **Website**: https://pirinthaban.github.io/FindBack/
- **Privacy Policy**: https://pirinthaban.github.io/FindBack/privacy-policy.html
- **Terms**: https://pirinthaban.github.io/FindBack/terms-and-conditions.html
- **Download**: https://github.com/pirinthaban/FindBack/releases/latest

---

## 🆘 Need Help?

If you encounter issues:
1. Check [Flutter deployment docs](https://docs.flutter.dev/deployment/android)
2. Open an issue on GitHub
3. Review PUBLISH_CHECKLIST.md for detailed steps

---

**Ready to publish?** Run the keystore command above and let me know when done!
