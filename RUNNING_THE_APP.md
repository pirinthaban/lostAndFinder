# Quick Start Guide - Running the Lost & Found App

## Prerequisites Installation

### Step 1: Install Flutter SDK

**For Windows:**

1. Download Flutter SDK:
   - Visit: https://docs.flutter.dev/get-started/install/windows
   - Download the latest stable release (Flutter SDK .zip)
   
2. Extract the zip file to a location (e.g., `C:\src\flutter`)

3. Add Flutter to PATH:
   ```powershell
   # Add to System Environment Variables
   # Path: C:\src\flutter\bin
   ```

4. Verify installation:
   ```powershell
   flutter doctor
   ```

### Step 2: Install Android Studio (for Android development)

1. Download from: https://developer.android.com/studio
2. Install with default settings
3. Open Android Studio
4. Go to: Settings → Plugins → Install "Flutter" and "Dart" plugins
5. Create or open Android Virtual Device (AVD)

### Step 3: Install Dependencies

```powershell
# Navigate to project directory
cd D:\lostAndFinder

# Get Flutter packages
flutter pub get

# Install Firebase Functions dependencies
cd functions
npm install
cd ..
```

### Step 4: Configure Firebase

**Important:** Before running, you need to set up Firebase:

1. Create a Firebase project at https://console.firebase.google.com
2. Add Android/iOS apps to your Firebase project
3. Download configuration files:
   - Android: `google-services.json` → Place in `android/app/`
   - iOS: `GoogleService-Info.plist` → Place in `ios/Runner/`

4. Run FlutterFire configuration:
   ```powershell
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

### Step 5: Run the Application

**Option A: Run on Android Emulator**
```powershell
# Start an emulator from Android Studio, then:
flutter run
```

**Option B: Run on Connected Device**
```powershell
# Connect Android device via USB with USB Debugging enabled
flutter devices  # Check connected devices
flutter run
```

**Option C: Run on Chrome (Web - for quick testing)**
```powershell
flutter run -d chrome
```

---

## Alternative: Quick Demo Mode (Without Flutter Installation)

If you want to quickly see what the app does without installing Flutter:

### View the Code Structure
```powershell
# Explore the project
tree /F lib
```

### Read the Documentation
- README.md - Complete overview
- PROJECT_SUMMARY.md - All features and deliverables
- docs/USER_MANUAL.md - How the app works
- docs/ACADEMIC_REPORT.md - Technical details

### View UI Screens
The implemented screens are in:
- `lib/features/authentication/presentation/screens/`
- `lib/features/home/presentation/screens/`
- `lib/features/items/presentation/screens/`

---

## Troubleshooting

### "Flutter not found"
- Ensure Flutter is in PATH
- Restart terminal/PowerShell
- Run: `flutter doctor` to diagnose

### "No devices found"
- Enable USB Debugging on Android device
- Start Android Emulator
- Try web: `flutter run -d chrome`

### "Dependencies error"
```powershell
flutter clean
flutter pub get
```

### "Firebase not configured"
- Create Firebase project
- Download config files
- Place in correct directories
- Run `flutterfire configure`

---

## What You Can Do Now (Without Running)

1. **Explore the Code**: See implementation in `lib/` folder
2. **Read Documentation**: Complete system explained in `docs/`
3. **Review Database**: See schema in `docs/DATABASE_SCHEMA.md`
4. **Check Functions**: Cloud Functions in `functions/src/`
5. **Academic Report**: Ready for submission in `docs/ACADEMIC_REPORT.md`

---

## Estimated Setup Time

- Flutter Installation: 15-30 minutes
- Android Studio Setup: 20-30 minutes
- Project Dependencies: 5-10 minutes
- Firebase Configuration: 10-15 minutes
- **Total: 50-85 minutes** (one-time setup)

Once set up, running the app takes just seconds!

---

## Need Help?

- Flutter docs: https://docs.flutter.dev
- Firebase setup: https://firebase.google.com/docs/flutter/setup
- Project issues: Check README.md

---

## Quick Command Reference

```powershell
# Check Flutter
flutter doctor

# Install dependencies
flutter pub get

# List devices
flutter devices

# Run app
flutter run

# Build APK
flutter build apk

# Hot reload (while running)
# Press 'r' in terminal

# Hot restart
# Press 'R' in terminal

# Quit
# Press 'q' in terminal
```
