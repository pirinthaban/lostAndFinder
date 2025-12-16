# Installation & Setup Guide

## Quick Start (5 Minutes)

### 1. Install Flutter

```bash
# Visit https://flutter.dev/docs/get-started/install
# Follow instructions for your OS

# Verify installation
flutter doctor
```

### 2. Clone Repository

```bash
git clone https://github.com/yourusername/lost-and-finder.git
cd lost-and-finder
```

### 3. Install Dependencies

```bash
# Flutter dependencies
flutter pub get

# Firebase Functions dependencies
cd functions
npm install
cd ..
```

### 4. Firebase Setup

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Initialize project
firebase init

# Configure FlutterFire
flutterfire configure
```

### 5. Run App

```bash
# Run on connected device/emulator
flutter run

# Or for specific device
flutter devices
flutter run -d <device-id>
```

## Detailed Setup

See `docs/DEPLOYMENT_GUIDE.md` for comprehensive instructions.

## Project Structure

```
lost_and_finder/
├── lib/                  # Flutter app source
├── functions/            # Cloud Functions
├── docs/                 # Documentation
├── assets/              # Images, fonts
├── test/                # Tests
└── README.md
```

## Available Commands

```bash
# Run app
flutter run

# Build APK
flutter build apk

# Run tests
flutter test

# Deploy Cloud Functions
firebase deploy --only functions

# Deploy Firestore rules
firebase deploy --only firestore:rules
```

## Need Help?

- Read the full README.md
- Check docs/ folder
- Open an issue on GitHub
- Email: support@lostandfound.lk
