# Lost & Found Community App - Deployment Guide

## Prerequisites

### Required Tools
```bash
# Flutter SDK
flutter --version  # Should be 3.16.0 or higher

# Firebase CLI
npm install -g firebase-tools
firebase --version  # Should be 12.0.0 or higher

# Node.js
node --version  # Should be 18.0.0 or higher

# Android Studio (for Android builds)
# Xcode (for iOS builds - macOS only)
```

### Firebase Project Setup

1. **Create Firebase Project**
```bash
# Login to Firebase
firebase login

# Create new project
firebase projects:create lost-found-lk

# Select project
firebase use lost-found-lk
```

2. **Enable Firebase Services**

Go to Firebase Console (https://console.firebase.google.com/):

- **Authentication**
  - Enable Phone authentication
  - Enable Email/Password authentication
  - Enable Google Sign-In
  - Add SHA-1 fingerprint for Android

- **Firestore Database**
  - Create database in production mode
  - Select region: asia-south1 (Mumbai)

- **Cloud Storage**
  - Create default bucket
  - Set up CORS configuration

- **Cloud Functions**
  - Upgrade to Blaze plan (pay-as-you-go)

- **Cloud Messaging (FCM)**
  - Enable FCM
  - Add server key

- **Analytics & Crashlytics**
  - Enable Firebase Analytics
  - Enable Crashlytics

3. **Configure Firebase for Flutter**

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase
flutterfire configure
```

This will:
- Create `firebase_options.dart`
- Configure Android app
- Configure iOS app

## Environment Configuration

### 1. Create Environment Files

Create `.env` file in project root:
```env
# Firebase
FIREBASE_PROJECT_ID=lost-found-lk
FIREBASE_API_KEY=your_api_key
FIREBASE_APP_ID=your_app_id

# Cloudinary
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret

# Google Maps
GOOGLE_MAPS_API_KEY=your_maps_key

# App Config
APP_ENV=production
APP_VERSION=1.0.0
```

### 2. Cloudinary Setup

1. Sign up at https://cloudinary.com
2. Get Cloud Name, API Key, API Secret
3. Create upload preset: `lost_found_uploads`
4. Configure transformations:
   - Auto blur: `e_blur_faces,e_pixelate_faces`
   - Auto optimize: `f_auto,q_auto`

### 3. Google Maps API

1. Go to Google Cloud Console
2. Enable Maps SDK for Android
3. Enable Maps SDK for iOS
4. Enable Geocoding API
5. Enable Places API
6. Create API key with restrictions

## Firebase Security Rules Deployment

```bash
# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Storage rules
firebase deploy --only storage:rules

# Deploy Firestore indexes
firebase deploy --only firestore:indexes
```

## Cloud Functions Deployment

```bash
# Navigate to functions directory
cd functions

# Install dependencies
npm install

# Build TypeScript
npm run build

# Deploy functions
firebase deploy --only functions

# Or deploy specific function
firebase deploy --only functions:itemCreated
```

## Flutter App Build

### Android Build

1. **Update Build Configuration**

Edit `android/app/build.gradle`:
```gradle
android {
    defaultConfig {
        applicationId "com.lostandfound.app"
        minSdkVersion 21
        targetSdkVersion 33
        versionCode 1
        versionName "1.0.0"
    }

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

2. **Create Keystore**
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

3. **Add Google Maps Key**

Edit `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
```

4. **Build APK**
```bash
flutter build apk --release
```

5. **Build App Bundle (for Play Store)**
```bash
flutter build appbundle --release
```

### iOS Build (macOS only)

1. **Configure Xcode Project**
```bash
cd ios
pod install
open Runner.xcworkspace
```

2. **Update Info.plist**
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show nearby lost and found items</string>

<key>NSCameraUsageDescription</key>
<string>We need camera access to take photos of items</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to select images</string>
```

3. **Build for iOS**
```bash
flutter build ios --release
```

## Google Play Store Deployment

### 1. Prepare Store Listing

- **App Name**: Lost & Found - Find Your Belongings
- **Short Description**: AI-powered community platform to reunite people with lost items in Sri Lanka
- **Full Description**: See `docs/PLAY_STORE_DESCRIPTION.md`
- **Screenshots**: 1080x1920 (at least 2)
- **Feature Graphic**: 1024x500
- **App Icon**: 512x512

### 2. Upload Build

1. Go to Google Play Console
2. Create new application
3. Upload app bundle (`.aab` file)
4. Fill in store listing details
5. Set pricing (Free)
6. Select countries (Start with Sri Lanka)
7. Submit for review

### 3. Content Rating

Complete content rating questionnaire:
- Target audience: Everyone
- Contains ads: No (initially)
- In-app purchases: Yes (Premium features)

## Apple App Store Deployment

### 1. App Store Connect Setup

1. Create App in App Store Connect
2. Bundle ID: com.lostandfound.app
3. SKU: lost-found-app-001
4. Fill in app information

### 2. Upload Build

```bash
# Archive app in Xcode
# Product > Archive

# Upload to App Store Connect
# Window > Organizer > Upload to App Store
```

### 3. Submit for Review

1. Add screenshots (1242x2688 for iPhone Pro Max)
2. Write description
3. Select categories
4. Set pricing
5. Submit for review

## Post-Deployment Configuration

### 1. Firebase Analytics

Enable screen tracking:
```dart
FirebaseAnalytics.instance.logScreenView(
  screenName: 'home_screen',
  screenClass: 'HomeScreen',
);
```

### 2. Crashlytics

```dart
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
```

### 3. Performance Monitoring

```dart
final trace = FirebasePerformance.instance.newTrace('item_load');
await trace.start();
// ... load item
await trace.stop();
```

### 4. Remote Config

Set up remote config parameters:
- `min_app_version`: "1.0.0"
- `maintenance_mode`: false
- `feature_ai_matching`: true
- `max_image_upload`: 5

## Monitoring & Maintenance

### Check App Health

```bash
# View Cloud Functions logs
firebase functions:log

# Monitor Firestore usage
firebase projects:list

# Check Storage usage
gsutil du -sh gs://lost-found-lk.appspot.com
```

### Performance Optimization

1. **Database**
   - Monitor query performance in Firebase Console
   - Add indexes for slow queries
   - Enable offline persistence

2. **Images**
   - Use Cloudinary CDN
   - Implement lazy loading
   - Cache images locally

3. **Functions**
   - Monitor execution time
   - Optimize cold starts
   - Use appropriate memory allocation

## Backup & Disaster Recovery

### Automated Backups

```bash
# Schedule daily Firestore backups
gcloud firestore export gs://lost-found-lk-backups
```

### Restore from Backup

```bash
gcloud firestore import gs://lost-found-lk-backups/[BACKUP_FOLDER]
```

## Scaling Strategy

### Phase 1: 0-10K Users
- Firebase Spark Plan (Free tier)
- Single region deployment
- Basic monitoring

### Phase 2: 10K-100K Users
- Upgrade to Blaze Plan
- Enable CDN
- Add read replicas
- Implement caching

### Phase 3: 100K+ Users
- Multi-region deployment
- Dedicated AI inference servers
- Load balancing
- Advanced analytics

## Security Checklist

- [ ] API keys restricted by app signature
- [ ] Firestore rules deployed
- [ ] Storage rules deployed
- [ ] Rate limiting enabled
- [ ] SSL/TLS certificates configured
- [ ] User data encryption enabled
- [ ] Regular security audits scheduled

## Support & Maintenance

### Monitor These Metrics

- Daily Active Users (DAU)
- Items posted per day
- Successful matches per day
- App crash rate
- API response time
- User retention rate

### Regular Tasks

- Weekly: Review crash reports
- Monthly: Update dependencies
- Quarterly: Security audit
- Yearly: Major version update

## Troubleshooting

### Common Issues

**Build fails:**
```bash
flutter clean
flutter pub get
flutter build apk
```

**Firebase not initialized:**
- Check `firebase_options.dart` is present
- Verify `google-services.json` (Android) or `GoogleService-Info.plist` (iOS)

**Push notifications not working:**
- Verify FCM server key
- Check device token registration
- Test with Firebase Console

## Cost Estimation

### Monthly Operating Costs (10K users)

- Firebase (Blaze Plan): $50-100
- Cloudinary: $50
- Google Maps API: $100
- Total: ~$200/month

### Revenue Projections

- Premium subscriptions: $150-300/month
- Institutional: $200-400/month
- Break-even: 3-6 months

---

**Deployment Date**: [Add date]
**Version**: 1.0.0
**Deployed By**: [Your name]
