# Privacy & Security Information Guide

**FindBack - Lost & Found Community App**  
**Last Updated: December 17, 2025**

---

## 🔐 Our Commitment to Your Privacy & Security

At FindBack, we understand that trust is paramount when handling lost and found items, especially sensitive documents like National Identity Cards (NICs), passports, and personal belongings. This guide explains how we protect your data and maintain your privacy.

---

## 📊 Data Collection & Usage

### What Information We Collect

#### **1. Account Information**
- **Phone Number** (Required for authentication)
- **Email Address** (Optional, for account recovery)
- **Display Name** (Your chosen username)
- **Profile Photo** (Optional)
- **Location/District** (To show nearby items)

#### **2. Item Information**
- **Photos** (Up to 5 images per item)
- **Description** (Item details)
- **Location Data** (Where item was lost/found)
- **Category** (NIC, Passport, Phone, Wallet, etc.)
- **Timestamps** (When item was posted)

#### **3. Communication Data**
- **In-app Messages** (Encrypted chats between users)
- **Claim Submissions** (Ownership verification documents)
- **Reports & Feedback**

#### **4. Usage Data**
- **Device Information** (Device type, OS version)
- **App Analytics** (Feature usage, crash reports)
- **IP Address** (For security and fraud prevention)

### How We Use Your Information

✅ **To Provide Services:**
- Match lost and found items using AI
- Enable communication between users
- Verify ownership claims
- Send notifications about matches

✅ **To Improve Experience:**
- Analyze app performance
- Fix bugs and crashes
- Develop new features
- Provide customer support

✅ **To Ensure Safety:**
- Prevent fraud and scams
- Detect suspicious activity
- Enforce community guidelines
- Comply with legal obligations

---

## 🛡️ Security Measures

### Data Encryption

#### **At Rest**
- All sensitive data is encrypted in Firebase Firestore
- User passwords are hashed (never stored in plain text)
- Phone numbers are hashed for privacy
- Personal documents are encrypted in Cloud Storage

#### **In Transit**
- All communications use HTTPS/TLS 1.3
- End-to-end encryption for in-app chats (AES-256)
- Secure API connections to Firebase

### Image Protection

#### **Automatic Blurring**
Our AI automatically detects and blurs:
- NIC numbers and personal identification codes
- Faces in photos (optional)
- Credit card numbers
- Sensitive document details

#### **Access Controls**
- Original high-resolution images visible only to poster
- Blurred versions shown to public searchers
- Proof documents visible only to claim participants

### Location Privacy

#### **Fuzzy Location**
- Exact GPS coordinates are NOT shared publicly
- We show approximate area (500m-1km radius)
- District-level information for broader searches
- Option to hide location entirely for sensitive items

### Account Security

#### **Multi-Factor Authentication**
- Phone OTP verification (required)
- Email verification (optional secondary)
- Biometric login (Face ID / Fingerprint)

#### **Session Management**
- 30-day session expiry
- Auto-logout on suspicious activity
- Device tracking and management
- Force logout from all devices option

---

## 🚫 What We DON'T Do

❌ **We Never:**
- Sell your personal data to third parties
- Share your phone number without permission
- Display exact GPS coordinates publicly
- Store unencrypted sensitive documents
- Use your data for advertising without consent
- Share data with police without legal warrant

---

## 👥 Data Sharing & Third Parties

### Who Can See Your Data

#### **1. Other Users**
**Can See:**
- Display name and profile photo
- Item descriptions and blurred images
- Approximate location (area, not exact address)
- Public reputation score

**Cannot See:**
- Phone number (until you choose to share in chat)
- Email address
- Exact GPS coordinates
- Personal verification documents

#### **2. Service Providers**
We use trusted third-party services:

**Firebase (Google)**
- Purpose: Authentication, Database, Storage
- Data: Account info, items, messages
- Privacy: [Firebase Privacy Policy](https://firebase.google.com/support/privacy)

**Cloudinary**
- Purpose: Image hosting and processing
- Data: Uploaded images (with auto-blur)
- Privacy: [Cloudinary Privacy Policy](https://cloudinary.com/privacy)

**Google Maps**
- Purpose: Location services and geocoding
- Data: Location coordinates (approximate)
- Privacy: [Google Privacy Policy](https://policies.google.com/privacy)

#### **3. Legal Authorities**
We may disclose data when:
- Required by law (court order, subpoena)
- To prevent harm or criminal activity
- To protect our legal rights
- With user's explicit consent

---

## 🔒 Your Privacy Rights

### Access & Control

#### **View Your Data**
- Access all your posted items
- View your chat history
- Check your reputation score
- Download your data (coming soon)

#### **Edit Your Information**
- Update display name and photo
- Change phone number or email
- Modify item descriptions
- Delete old posts

#### **Delete Your Data**
- Delete individual items anytime
- Close claims and chats
- Request account deletion
  - All items marked as deleted
  - Personal data anonymized after 30 days
  - Required data retained for legal compliance (90 days)

### Data Retention Policy

| Data Type | Retention Period |
|-----------|------------------|
| Active items | Until user deletes or 90 days inactive |
| Closed items | 30 days after closure |
| Chat messages | Until both users delete conversation |
| Deleted accounts | 30 days (recovery period) |
| Audit logs | 2 years (security compliance) |
| Analytics data | Anonymized after 1 year |

---

## 🌍 International Data Transfers

- **Primary Server Location:** Asia-South1 (Mumbai, India)
- **Backup Regions:** Multi-region Firebase
- **GDPR Compliance:** Yes (for EU users)
- **Data Protection:** Standard Contractual Clauses (SCCs)

---

## 👶 Children's Privacy

- **Minimum Age:** 13 years old (16 in EU)
- **Parental Consent:** Required for users under 18
- **Special Protections:** No targeted advertising, enhanced privacy

If you believe a child has provided data without permission, contact us immediately.

---

## 🔔 Notifications & Marketing

### Push Notifications
You control notifications for:
- Match alerts (when items match)
- Chat messages
- Claim updates
- System announcements

**Opt-out:** Settings → Notifications → Disable categories

### Marketing Communications
- **Promotional emails:** Opt-in only
- **Feature updates:** App announcements (can disable)
- **Community news:** Optional subscription

---

## 🚨 Security Best Practices for Users

### Protect Your Account
✅ Use a strong password (if email login)  
✅ Enable biometric authentication  
✅ Don't share OTP codes  
✅ Verify users before sharing phone number  
✅ Report suspicious accounts immediately  

### Posting Items Safely
✅ Review photos before posting (check for private info)  
✅ Use approximate location, not exact address  
✅ Don't include full NIC/passport numbers in description  
✅ Verify claimants thoroughly before meetup  
✅ Meet in public places for item handover  

### Communication Safety
✅ Keep conversations in-app (for safety)  
✅ Don't send payment requests  
✅ Report scams and fake claims  
✅ Block abusive users  
✅ Trust your instincts  

---

## 📞 Report Security Issues

### Found a Vulnerability?
**Email:** security@findback.app *(coming soon)*  
**Response Time:** Within 24 hours  
**Bug Bounty:** We appreciate responsible disclosure  

### Report Abuse
- Use in-app "Report" button
- Contact support through app settings
- Email: support@findback.app *(coming soon)*

---

## 🔄 Updates to This Guide

We may update this guide to reflect:
- New features
- Legal requirements
- User feedback
- Security improvements

**Notification Method:**
- In-app announcement
- Email to registered users (if significant changes)

**Version History:**
- v1.0.0 - December 17, 2025 - Initial release

---

## 📚 Related Documents

- [Privacy Policy](PRIVACY_POLICY.md) - Full legal policy
- [Terms and Conditions](TERMS_AND_CONDITIONS.md) - Service agreement
- [Community Guidelines](docs/COMMUNITY_GUIDELINES.md) - Usage rules
- [Security Policy](SECURITY.md) - Vulnerability reporting

---

## ❓ Frequently Asked Questions

**Q: Can I use FindBack anonymously?**  
A: No, phone verification is required to prevent fraud and ensure accountability.

**Q: Who can see my phone number?**  
A: Only you, until you choose to share it in chat with specific users.

**Q: How long are deleted items kept?**  
A: 30 days in case of accidental deletion, then permanently removed.

**Q: Can police access my data?**  
A: Only with a valid legal warrant or court order.

**Q: Is my location tracked continuously?**  
A: No, location is only used when posting items or searching nearby.

**Q: What happens if I lose access to my phone number?**  
A: Contact support with verification details to recover your account.

**Q: Can I export my data?**  
A: Data export feature coming soon (GDPR compliance).

**Q: How is AI matching secure?**  
A: AI runs on encrypted data; only metadata is processed, not raw images.

---

## 📧 Contact Us

**Email:** privacy@findback.app *(coming soon)*  
**GitHub:** [github.com/pirinthaban/FindBack](https://github.com/pirinthaban/FindBack)  
**In-App Support:** Settings → Help & Support  

---

**FindBack - Helping you find what matters.**  
*Made with ❤️ for Sri Lanka and the world*

---

© 2025 FindBack. Open-source project under MIT License.  
This guide is for informational purposes and complements our Privacy Policy and Terms of Service.
