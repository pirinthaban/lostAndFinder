# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-12-16

### Added
- Initial release of Lost & Found Community App
- User authentication with phone OTP (Firebase)
- Post lost and found items
- Image upload functionality
- Location-based item discovery
- Item categories (NIC, Passport, Phone, Wallet, Bag, Keys, Documents, Other)
- User profiles with basic information
- Home feed with nearby items
- Navigation with go_router
- State management with Riverpod
- Splash screen and onboarding flow
- Police dashboard (initial)
- Chat system (basic structure)
- Claims workflow (structure)

### Planned for v1.1.0
- [ ] Real Firebase phone authentication (currently mock)
- [ ] Image similarity matching (AI)
- [ ] Push notifications for matches
- [ ] In-app chat messaging
- [ ] Claim verification flow
- [ ] User reputation system
- [ ] Multi-language support (Sinhala, Tamil)

### Planned for v2.0.0
- [ ] Offline-first architecture with Hive
- [ ] AI-powered auto-matching
- [ ] Video testimonials
- [ ] Advanced search filters
- [ ] Export reports (PDF)
- [ ] Dark mode

---

## Release Notes

### v1.0.0 - Initial Open Source Release
This is the first public release of the Lost & Found Community App. The app is in **alpha stage** and requires Firebase configuration to work in production.

**What works:**
- ✅ Navigation flow (splash → onboarding → phone verification → OTP → home)
- ✅ UI/UX for all major screens
- ✅ Basic state management structure
- ✅ Image picker integration
- ✅ Mock authentication flow

**What needs setup:**
- ⚠️ Firebase configuration (see FIREBASE_SETUP.md)
- ⚠️ Real phone authentication
- ⚠️ Database connectivity
- ⚠️ Image storage (Cloudinary or Firebase Storage)
- ⚠️ Google Maps API key

**Known Issues:**
- Firebase initialization commented out (needs real config)
- Mock OTP flow (not production ready)
- Placeholder screens for some features
- No real-time data sync yet
- Limited error handling

---

[1.0.0]: https://github.com/pirinthaban/FindBack/releases/tag/v1.0.0
