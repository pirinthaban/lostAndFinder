# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

If you discover a security vulnerability in this project, please report it privately:

### How to Report
1. **Email:** your.email@example.com (or use GitHub Security tab)
2. **Subject:** "Security Vulnerability in Lost & Found App"
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### What to Expect
- We will acknowledge your email within **48 hours**
- We will provide a detailed response within **7 days**
- We will work on a fix and release a patch
- You will be credited in the security advisory (if desired)

## Security Best Practices

### For Contributors
- Never commit API keys, passwords, or secrets
- Always use `.env` files for sensitive data (not tracked in Git)
- Use Firebase Security Rules to protect data
- Validate all user inputs
- Follow OWASP Mobile Security guidelines

### For Users/Deployers
- Keep Firebase API keys secure
- Enable Firebase App Check
- Use proper Firebase Security Rules (not test mode)
- Regularly update dependencies: `flutter pub upgrade`
- Enable 2FA on Firebase Console
- Review Cloud Functions for vulnerabilities

## Known Security Considerations

### Firebase Configuration
- `firebase_options.dart` contains Firebase config (not sensitive, but rate-limit APIs)
- Use Firebase App Check to prevent API abuse
- Restrict API keys in Google Cloud Console

### Authentication
- Phone OTP uses Firebase Authentication
- Rate limiting implemented to prevent spam
- Consider adding reCAPTCHA for web

### Data Privacy
- User data encrypted in transit (HTTPS)
- Sensitive fields (NIC numbers) should be blurred in images
- Implement proper Firestore Security Rules:
  ```javascript
  // Example: Users can only read/write their own data
  match /users/{userId} {
    allow read, write: if request.auth.uid == userId;
  }
  ```

### Image Upload
- Validate image size (max 5MB per image)
- Scan for malicious content
- Use Cloudinary moderation or Firebase Storage rules

## Dependency Security
We use:
- `flutter pub outdated` to check for updates
- GitHub Dependabot for automated security updates
- `dart analyze` for code quality

## Third-Party Services
This app integrates with:
- Firebase (Google) - [Security](https://firebase.google.com/support/privacy)
- Cloudinary (optional) - [Security](https://cloudinary.com/security)
- Google Maps API - [Security Best Practices](https://developers.google.com/maps/api-security-best-practices)

## Compliance
- GDPR: User data deletion available
- Children's Privacy: Not designed for users under 13
- Sri Lanka PDPA: Personal data protection compliance

## Security Updates
Security patches will be released as:
- Critical: Immediate patch (v1.0.1)
- High: Within 7 days
- Medium: Next minor release (v1.1.0)
- Low: Next major release (v2.0.0)

## Hall of Fame
Contributors who responsibly disclose vulnerabilities:
- (Your name here!)

---

Thank you for helping keep Lost & Found App secure! 🔒
