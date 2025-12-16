# Database Schema & ER Diagram

## Entity-Relationship Diagram (ASCII Format)

```
┌──────────────────────┐
│       USERS          │
│──────────────────────│
│ PK: userId (string)  │
│──────────────────────│
│ email                │
│ phone                │
│ displayName          │
│ photoURL             │
│ role                 │
│ reputation           │
│ itemsPosted          │
│ itemsReturned        │
│ successRate          │
│ location             │
│ district             │
│ verifiedPolice       │
│ createdAt            │
│ lastActive           │
│ fcmToken             │
└──────────────────────┘
         │ 1
         │
         │ posts
         │
         ▼ *
┌──────────────────────┐
│       ITEMS          │
│──────────────────────│
│ PK: itemId (string)  │
│──────────────────────│
│ type                 │
│ category             │
│ title                │
│ description          │
│ images[]             │
│ blurredImages[]      │
│ location             │
│ locationName         │
│ district             │
│ radius               │
│ geohash              │
│ FK: userId           │────────┐
│ userName             │        │ owns
│ userPhone            │        │
│ status               │        │
│ urgency              │        │
│ matchCount           │        │
│ viewCount            │        │
│ reportCount          │        │
│ features{}           │        │
│ embedding[]          │        │
│ createdAt            │        │
│ updatedAt            │        │
│ expiresAt            │        │
└──────────────────────┘        │
         │ 1                    │
         │                      │ 1
         │                      │
         │ matched with         │
         │                      │
         ▼ *                    │
┌──────────────────────┐        │
│      MATCHES         │        │
│──────────────────────│        │
│ PK: matchId (string) │        │
│──────────────────────│        │
│ FK: lostItemId       │────────┤
│ FK: foundItemId      │────────┤
│ confidenceScore      │        │
│ imageSimilarity      │        │
│ textSimilarity       │        │
│ locationProximity    │        │
│ timeDifference       │        │
│ matchedBy            │        │
│ status               │        │
│ createdAt            │        │
│ notificationSent     │        │
└──────────────────────┘        │
                                │
                                │
┌──────────────────────┐        │
│       CLAIMS         │        │
│──────────────────────│        │
│ PK: claimId (string) │        │
│──────────────────────│        │
│ FK: itemId           │────────┘
│ FK: claimantUserId   │────────┐
│ FK: itemOwnerId      │────────┤
│ status               │        │
│ proofDocuments[]     │        │
│ proofAnswers{}       │        │
│ verificationQuestions│        │
│ FK: verifiedBy       │────────┤
│ verificationNotes    │        │
│ meetupLocation       │        │
│ meetupTime           │        │
│ handoverConfirmed    │        │
│ handoverCode         │        │
│ createdAt            │        │
│ completedAt          │        │
└──────────────────────┘        │
         │ 1                    │
         │                      │ 1
         │ has                  │
         │                      │
         ▼ 0..1                 │
┌──────────────────────┐        │
│ POLICE_VERIFICATIONS │        │
│──────────────────────│        │
│ PK: verificationId   │        │
│──────────────────────│        │
│ FK: itemId           │        │
│ FK: claimId          │        │
│ FK: officerId        │────────┘
│ stationName          │
│ caseNumber           │
│ verificationStatus   │
│ officerNotes         │
│ documents[]          │
│ createdAt            │
│ verifiedAt           │
└──────────────────────┘


┌──────────────────────┐
│       CHATS          │
│──────────────────────│
│ PK: chatId (string)  │
│──────────────────────│
│ FK: itemId           │────────┐
│ participants[]       │        │ about
│ participantNames{}   │        │
│ lastMessage          │        │
│ lastMessageTime      │        │
│ unreadCount{}        │        │
│ createdAt            │        │
│ archived             │        │
└──────────────────────┘        │
         │ 1                    │
         │                      │
         │ contains             │
         │                      │
         ▼ *                    │
┌──────────────────────┐        │
│      MESSAGES        │        │
│──────────────────────│        │
│ PK: messageId (str)  │        │
│──────────────────────│        │
│ FK: chatId           │        │
│ FK: senderId         │────────┤
│ text (encrypted)     │        │
│ type                 │        │
│ mediaUrl             │        │
│ readBy[]             │        │
│ createdAt            │        │
│ deleted              │        │
└──────────────────────┘        │
                                │
                                │
┌──────────────────────┐        │
│       REPORTS        │        │
│──────────────────────│        │
│ PK: reportId (str)   │        │
│──────────────────────│        │
│ FK: reporterUserId   │────────┤
│ FK: reportedUserId   │────────┤
│ FK: itemId           │────────┘
│ reason               │
│ description          │
│ evidence[]           │
│ status               │
│ FK: reviewedBy       │
│ actionTaken          │
│ createdAt            │
│ resolvedAt           │
└──────────────────────┘


┌──────────────────────┐
│    NOTIFICATIONS     │
│──────────────────────│
│ PK: notificationId   │
│──────────────────────│
│ FK: userId           │────────┐
│ type                 │        │ receives
│ title                │        │
│ body                 │        │
│ data{}               │        │
│ read                 │        │
│ actionUrl            │        │
│ createdAt            │        │
└──────────────────────┘        │
                                │
                                │
┌──────────────────────┐        │
│     AUDIT_LOGS       │        │
│──────────────────────│        │
│ PK: logId (string)   │        │
│──────────────────────│        │
│ FK: userId           │────────┘
│ action               │
│ entityType           │
│ entityId             │
│ changes{}            │
│ ipAddress            │
│ deviceInfo{}         │
│ timestamp            │
└──────────────────────┘
```

## Relationships Summary

| Relationship | Cardinality | Description |
|--------------|-------------|-------------|
| User → Items | 1:N | A user can post multiple items |
| Item → Matches | 1:N | An item can have multiple matches |
| Item → Claims | 1:N | An item can have multiple claims |
| Claim → Police Verification | 1:1 | A claim can have one police verification |
| User → Claims | 1:N | A user can make multiple claims |
| Item → Chat | 1:N | An item can have multiple chats |
| Chat → Messages | 1:N | A chat contains multiple messages |
| User → Messages | 1:N | A user sends multiple messages |
| User → Reports | 1:N | A user can create multiple reports |
| User → Notifications | 1:N | A user receives multiple notifications |
| User → Audit Logs | 1:N | A user has multiple audit logs |

## Data Models (Dart/Flutter)

### User Model
```dart
class User {
  final String id;
  final String email;
  final String phone;
  final String displayName;
  final String? photoURL;
  final UserRole role;
  final int reputation;
  final int itemsPosted;
  final int itemsReturned;
  final double successRate;
  final GeoPoint? location;
  final String? district;
  final bool verifiedPolice;
  final DateTime createdAt;
  final DateTime lastActive;
  final String? fcmToken;
}

enum UserRole {
  citizen,
  police,
  universityAdmin,
  admin,
}
```

### Item Model
```dart
class Item {
  final String id;
  final ItemType type;
  final ItemCategory category;
  final String title;
  final String description;
  final List<String> images;
  final List<String>? blurredImages;
  final GeoPoint location;
  final String locationName;
  final String district;
  final double radius;
  final String geohash;
  final String userId;
  final String userName;
  final String? userPhone;
  final ItemStatus status;
  final UrgencyLevel urgency;
  final int matchCount;
  final int viewCount;
  final int reportCount;
  final Map<String, dynamic>? features;
  final List<double>? embedding;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt;
}

enum ItemType { lost, found }

enum ItemCategory {
  nic,
  passport,
  phone,
  wallet,
  bag,
  keys,
  documents,
  other,
}

enum ItemStatus {
  active,
  claimed,
  verified,
  closed,
  expired,
}

enum UrgencyLevel {
  low,
  medium,
  high,
  emergency,
}
```

### Match Model
```dart
class Match {
  final String id;
  final String lostItemId;
  final String foundItemId;
  final double confidenceScore;
  final double imageSimilarity;
  final double textSimilarity;
  final double locationProximity;
  final int timeDifference;
  final MatchedBy matchedBy;
  final MatchStatus status;
  final DateTime createdAt;
  final bool notificationSent;
}

enum MatchedBy { ai, manual }

enum MatchStatus {
  pending,
  viewed,
  claimed,
  dismissed,
}
```

### Claim Model
```dart
class Claim {
  final String id;
  final String itemId;
  final String claimantUserId;
  final String itemOwnerId;
  final ClaimStatus status;
  final List<String>? proofDocuments;
  final Map<String, dynamic>? proofAnswers;
  final List<Map<String, dynamic>>? verificationQuestions;
  final String? verifiedBy;
  final String? verificationNotes;
  final GeoPoint? meetupLocation;
  final DateTime? meetupTime;
  final bool handoverConfirmed;
  final String? handoverCode;
  final DateTime createdAt;
  final DateTime? completedAt;
}

enum ClaimStatus {
  pending,
  underReview,
  verified,
  rejected,
  completed,
}
```

## Indexing Strategy Details

### Users Collection
```yaml
Indexes:
  - Single Field: role (ASC)
  - Single Field: district (ASC)
  - Single Field: reputation (DESC)
  - Composite: [role ASC, reputation DESC]
  - Composite: [district ASC, reputation DESC]
  - Geospatial: location (for proximity queries)
```

### Items Collection
```yaml
Indexes:
  - Single Field: userId (ASC)
  - Single Field: type (ASC)
  - Single Field: category (ASC)
  - Single Field: status (ASC)
  - Single Field: district (ASC)
  - Single Field: geohash (ASC)
  - Composite: [status ASC, type ASC, createdAt DESC]
  - Composite: [status ASC, category ASC, createdAt DESC]
  - Composite: [status ASC, district ASC, createdAt DESC]
  - Composite: [status ASC, geohash ASC, createdAt DESC]
  - Composite: [userId ASC, status ASC, createdAt DESC]
  - Composite: [type ASC, category ASC, status ASC, createdAt DESC]
  - Geospatial: location (for radius queries)
```

### Matches Collection
```yaml
Indexes:
  - Single Field: lostItemId (ASC)
  - Single Field: foundItemId (ASC)
  - Single Field: confidenceScore (DESC)
  - Composite: [lostItemId ASC, confidenceScore DESC, status ASC]
  - Composite: [foundItemId ASC, confidenceScore DESC, status ASC]
  - Composite: [status ASC, confidenceScore DESC, createdAt DESC]
```

### Claims Collection
```yaml
Indexes:
  - Single Field: itemId (ASC)
  - Single Field: claimantUserId (ASC)
  - Single Field: itemOwnerId (ASC)
  - Composite: [itemId ASC, status ASC, createdAt DESC]
  - Composite: [claimantUserId ASC, status ASC, createdAt DESC]
  - Composite: [status ASC, createdAt DESC]
```

### Chats Collection
```yaml
Indexes:
  - Single Field: itemId (ASC)
  - Array Field: participants (contains)
  - Composite: [participants ARRAY_CONTAINS, lastMessageTime DESC]
  - Composite: [itemId ASC, lastMessageTime DESC]
```

### Messages Collection
```yaml
Indexes:
  - Single Field: chatId (ASC)
  - Single Field: senderId (ASC)
  - Composite: [chatId ASC, createdAt ASC]
  - Composite: [chatId ASC, deleted ASC, createdAt ASC]
```

## Query Optimization Examples

### Find Nearby Lost Items
```dart
// Using geohash for efficient location queries
final query = FirebaseFirestore.instance
    .collection('items')
    .where('status', isEqualTo: 'active')
    .where('type', isEqualTo: 'lost')
    .where('geohash', isGreaterThanOrEqualTo: lowerGeohash)
    .where('geohash', isLessThanOrEqualTo: upperGeohash)
    .orderBy('geohash')
    .orderBy('createdAt', descending: true)
    .limit(50);
```

### Get High-Confidence Matches
```dart
final query = FirebaseFirestore.instance
    .collection('matches')
    .where('lostItemId', isEqualTo: itemId)
    .where('confidenceScore', isGreaterThan: 70)
    .where('status', isEqualTo: 'pending')
    .orderBy('confidenceScore', descending: true)
    .limit(10);
```

### User's Active Items
```dart
final query = FirebaseFirestore.instance
    .collection('items')
    .where('userId', isEqualTo: currentUserId)
    .where('status', isEqualTo: 'active')
    .orderBy('createdAt', descending: true);
```

## Data Retention Policies

```yaml
Items:
  - Active: Keep forever
  - Closed/Expired: Archive after 90 days
  - Deleted: Soft delete, purge after 30 days

Messages:
  - Active chats: Keep forever
  - Archived chats: Keep for 1 year
  - Deleted messages: Purge immediately

Audit Logs:
  - Keep for 2 years
  - Archive to Cloud Storage after 6 months

Notifications:
  - Keep unread forever
  - Delete read after 90 days

Reports:
  - Keep resolved for 2 years
  - Keep active forever
```

## Backup Strategy

```yaml
Firestore:
  - Automated daily backups
  - 30-day retention
  - Export to Cloud Storage weekly

Storage:
  - Images replicated across regions
  - Lifecycle management: delete after item deletion + 90 days

User Data:
  - GDPR compliant export available
  - Complete deletion on user request
```
