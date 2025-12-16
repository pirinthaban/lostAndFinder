# Firebase Setup Guide

This app requires Firebase for authentication, database, and storage. Follow these steps to set up your own Firebase project (100% FREE for development).

## Prerequisites
- Google Account
- Flutter SDK installed
- Node.js (for Firebase Functions, optional)

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"**
3. Enter project name: `lost-found-app` (or your choice)
4. Disable Google Analytics (optional for free tier)
5. Click **"Create project"**

## Step 2: Add Android App

1. In Firebase Console, click **Android icon**
2. **Android package name:** `com.lostandfound.app` (or change in `android/app/build.gradle.kts`)
3. Download `google-services.json`
4. Place in: `android/app/google-services.json`
5. Click **"Next"** → **"Continue to console"**

## Step 3: Add iOS App (Optional)

1. Click **iOS icon** in Firebase Console
2. **iOS bundle ID:** `com.lostandfound.app`
3. Download `GoogleService-Info.plist`
4. Place in: `ios/Runner/GoogleService-Info.plist`

## Step 4: Add Web App (Optional)

1. Click **Web icon** `</>`
2. Register app name
3. Copy the config object
4. You'll use this in Step 6

## Step 5: Enable Authentication

1. Go to **Authentication** → **Sign-in method**
2. Enable:
   - ✅ **Phone** (for OTP)
   - ✅ **Google** (optional)
   - ✅ **Email/Password** (optional)

3. For Phone Auth, you may need to verify your app with Google:
   - Add SHA-1 fingerprint (get with `keytool`)

## Step 6: Generate firebase_options.dart

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase
flutterfire configure --project=your-project-id
```

This creates `lib/firebase_options.dart` automatically with your keys.

## Step 7: Set Up Firestore Database

1. Go to **Firestore Database** → **Create database**
2. Start in **Test mode** (change rules later)
3. Choose location closest to your users

**Security Rules (for development):**
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Step 8: Set Up Cloud Storage

1. Go to **Storage** → **Get started**
2. Start in **Test mode**
3. Choose same location as Firestore

**Security Rules:**
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

## Step 9: Update Environment Variables

Copy `.env.example` to `.env` and fill in your Firebase values:

```bash
FIREBASE_API_KEY=AIza...
FIREBASE_APP_ID=1:123456...
FIREBASE_PROJECT_ID=lost-found-app
```

## Step 10: Test the App

```bash
flutter run -d chrome
```

You should now be able to:
- Navigate through onboarding
- Enter phone number (won't send SMS in test mode)
- Navigate to home screen

## Free Tier Limits

Firebase Spark (Free) Plan includes:
- ✅ **Authentication:** Unlimited users
- ✅ **Firestore:** 1GB storage, 50K reads/day, 20K writes/day
- ✅ **Cloud Storage:** 5GB storage, 1GB download/day
- ✅ **Hosting:** 10GB storage, 360MB/day transfer
- ❌ **Phone Auth:** Limited to test numbers only (upgrade to Blaze for production)

## Upgrade to Blaze (Pay-as-you-go)

For production with real phone OTP:
1. Go to **Settings** → **Usage and billing**
2. Click **Modify plan** → **Blaze (Pay as you go)**
3. Add credit card (you get $0.50/day free credit)
4. Phone Auth: $0.06 per verification (most expensive part)

**Cost Estimation:**
- 100 users/day login = $6/day = ~$180/month
- Consider using Email auth to save costs

## Troubleshooting

### "Default FirebaseApp is not initialized"
- Make sure `firebase_options.dart` exists
- Uncomment Firebase init in `lib/main.dart`

### "google-services.json not found"
- Download from Firebase Console
- Place in `android/app/` folder
- Run `flutter clean` and rebuild

### Phone Auth not working
- Enable Phone Auth in Firebase Console
- Add SHA-1 to Firebase (Android)
- For testing, add test phone numbers in Firebase Console

## Need Help?
- [Firebase Documentation](https://firebase.google.com/docs)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- Open an issue in this repository
