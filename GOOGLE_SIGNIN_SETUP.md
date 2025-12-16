# Google Sign-In Setup Instructions

## Download Google Logo

1. Download the official Google logo from: https://developers.google.com/identity/branding-guidelines
2. Save as `google_logo.png` in `assets/images/` folder
3. Or use this direct link: https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg

## Configure Google Sign-In

### Android Setup (SHA-1 Certificate)

1. Get your SHA-1 fingerprint:
```bash
cd android
./gradlew signingReport
```

2. Copy the SHA-1 from the output

3. Add to Firebase Console:
   - Go to: https://console.firebase.google.com/project/lost-found-lk/settings/general
   - Under "Your apps" → Android app
   - Add SHA-1 certificate fingerprint
   - Download new `google-services.json`
   - Replace `android/app/google-services.json`

### Web Setup

Already configured automatically!

### Enable Email/Password in Firebase

1. Go to: https://console.firebase.google.com/project/lost-found-lk/authentication/providers
2. Click "Add new provider"
3. Select "Email/Password"
4. Toggle "Enable"
5. Click "Save"

### Enable Google Sign-In in Firebase

1. Go to: https://console.firebase.google.com/project/lost-found-lk/authentication/providers
2. Click "Add new provider"
3. Select "Google"
4. Toggle "Enable"
5. Set support email
6. Click "Save"

## Test Phone Numbers (Free - No SMS Cost)

Add these in Firebase Console for free testing:

```
+94771234567 → 123456
+94777777777 → 111111  
+94778888888 → 222222
+94779999999 → 333333
+94112345678 → 999999
```

These work instantly without waiting for SMS!
