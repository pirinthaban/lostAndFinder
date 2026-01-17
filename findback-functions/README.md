# FindBack Cloud Functions

This folder contains all Firebase Cloud Functions for the FindBack Lost & Found app.

## 📁 Folder Structure

```
findback-functions/
├── src/
│   ├── index.ts              # Main entry point - exports all functions
│   ├── triggers/
│   │   ├── onItemCreated.ts  # AI matching when new item posted
│   │   ├── onClaimCreated.ts # Claim processing and notifications
│   │   └── onUserDeleted.ts  # GDPR compliance - cleanup user data
│   ├── notifications/
│   │   ├── onNewMessage.ts   # Push notifications for chat messages
│   │   └── matchNotifications.ts # Match found notifications
│   ├── moderation/
│   │   └── contentModeration.ts  # Content safety checks
│   ├── scheduled/
│   │   ├── expireItems.ts    # Daily cleanup of expired items
│   │   └── analytics.ts      # Monthly reports generation
│   └── utils/
│       ├── notifications.ts  # Notification helper functions
│       └── matching.ts       # AI matching utilities
├── package.json
├── tsconfig.json
└── README.md
```

## 🚀 Setup & Deployment

### Prerequisites
- Node.js 18+
- Firebase CLI (`npm install -g firebase-tools`)
- Firebase Blaze Plan (required for Cloud Functions)

### Installation

```bash
cd findback-functions
npm install
```

### Build

```bash
npm run build
```

### Deploy

```bash
# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:messageCreated
```

## 📋 Functions Overview

### Triggers

| Function | Trigger | Description |
|----------|---------|-------------|
| `itemCreated` | Firestore onCreate | AI matching when new item is posted |
| `claimCreated` | Firestore onCreate | Process claims and notify owners |
| `messageCreated` | Firestore onCreate | Send push notifications for chat |

### Scheduled

| Function | Schedule | Description |
|----------|----------|-------------|
| `expireOldItems` | Daily 00:00 | Mark expired items as inactive |
| `generateMonthlyReport` | Monthly 1st | Generate analytics reports |

### HTTP Callable

| Function | Auth Required | Description |
|----------|---------------|-------------|
| `recalculateMatches` | Admin only | Manually trigger AI matching |

## 🔐 Environment Variables

Set these in Firebase:

```bash
firebase functions:config:set gemini.key="YOUR_GEMINI_API_KEY"
```

## 💰 Cost Estimation (Blaze Plan)

| Resource | Free Tier | Typical Usage |
|----------|-----------|---------------|
| Invocations | 2M/month | ~10K/month for small app |
| Compute | 125K GB-s | ~5K GB-s/month |
| Outbound | 5GB/month | ~1GB/month |

**Estimated Cost: $0 for most small to medium apps**
