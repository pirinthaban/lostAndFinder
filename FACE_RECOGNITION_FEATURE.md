# 👤 Face Recognition Feature - Implementation Guide

## Overview

The **Face-Based Item Search** feature allows users to upload a photo containing a person's face and search for items in the database that contain photos of the same person. This is particularly useful for:

- Finding missing persons
- Reuniting lost belongings with owners based on photos
- Identifying items that contain photos of specific individuals

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    FACE-BASED ITEM SEARCH                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐        │
│  │   Item       │     │   Cloud      │     │   Faces      │        │
│  │   Upload     │────▶│   Function   │────▶│   Collection │        │
│  │              │     │   (Vision)   │     │   (Firestore)│        │
│  └──────────────┘     └──────────────┘     └──────────────┘        │
│                                                    │                 │
│  ┌──────────────┐     ┌──────────────┐            │                 │
│  │   Face       │     │   Search     │            ▼                 │
│  │   Search     │────▶│   Function   │────▶ Compare Vectors        │
│  │   Query      │     │              │            │                 │
│  └──────────────┘     └──────────────┘            │                 │
│                                                    ▼                 │
│                                             Return Matches           │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 📁 Files Created/Modified

### New Files

| File | Purpose |
|------|---------|
| `findback-functions/src/ai/faceRecognition.ts` | Cloud Functions for face detection, embedding extraction, and search |
| `lib/core/services/face_search_service.dart` | Flutter service for face-based item search |
| `lib/features/items/presentation/screens/face_search_screen.dart` | Flutter UI for face search |
| `findback-webapp/face-search.js` | Web app JavaScript module for face search |
| `FACE_RECOGNITION_FEATURE.md` | This documentation file |

### Modified Files

| File | Changes |
|------|---------|
| `findback-functions/src/index.ts` | Added exports for face recognition functions |
| `findback-functions/package.json` | Added `@google-cloud/vision` dependency |
| `findback-webapp/index.html` | Added face search button and script |
| `findback-webapp/app.css` | Added face search styles |

---

## 🚀 Cloud Functions

### 1. `processFaceData`

**Trigger:** `items/{itemId}` onCreate

Automatically processes uploaded images when an item is created:
- Detects faces using Google Cloud Vision API
- Extracts face landmarks and generates face vectors
- Stores face data in the `faces` collection
- Updates item with `hasFaces` and `faceCount` fields

### 2. `searchByFace`

**Type:** HTTP Callable Function

Searches for items containing similar faces:

```javascript
const result = await firebase.functions().httpsCallable('searchByFace')({
    imageUrl: 'https://...', // URL of image to search
    threshold: 60,           // Minimum similarity (0-100)
    limit: 20,               // Maximum results
    category: 'Documents',   // Optional filter
    district: 'Colombo'      // Optional filter
});
```

### 3. `deleteFaceData`

**Trigger:** `items/{itemId}` onDelete

Cleans up face data when an item is deleted.

### 4. `testFaceDetection`

**Type:** HTTP Request

Test endpoint for face detection:

```
GET /testFaceDetection?imageUrl=https://...
```

---

## 📊 Database Schema

### Faces Collection

```javascript
{
    faceId: "uuid-string",
    itemId: "item-document-id",
    userId: "user-who-posted-item",
    imageUrl: "https://storage.../image.jpg",
    boundingBox: {
        x: 120,
        y: 80,
        width: 200,
        height: 250
    },
    landmarks: [
        { type: "LEFT_EYE", x: 150, y: 120 },
        { type: "RIGHT_EYE", x: 190, y: 118 },
        // ... more landmarks
    ],
    emotions: {
        joy: "LIKELY",
        sorrow: "VERY_UNLIKELY",
        anger: "VERY_UNLIKELY",
        surprise: "UNLIKELY"
    },
    angles: {
        roll: 2.5,
        pan: -5.2,
        tilt: 3.1
    },
    confidence: 0.98,
    faceVector: [0.12, -0.34, 0.56, ...], // Numerical face descriptor
    createdAt: Timestamp
}
```

### Items Collection (Updated Fields)

```javascript
{
    // ... existing fields
    hasFaces: true,
    faceCount: 2
}
```

---

## 🔧 Setup Instructions

### 1. Install Dependencies

```bash
cd findback-functions
npm install @google-cloud/vision
```

### 2. Enable Google Cloud Vision API

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your Firebase project
3. Enable the **Cloud Vision API**
4. Ensure billing is enabled

### 3. Deploy Cloud Functions

```bash
cd findback-functions
npm run build
firebase deploy --only functions
```

### 4. Test the Feature

```bash
# Test face detection
curl "https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/testFaceDetection?imageUrl=https://example.com/photo.jpg"
```

---

## 📱 Flutter Integration

### Using the Face Search Screen

```dart
import 'package:go_router/go_router.dart';

// Navigate to face search
context.push('/face-search');
```

### Add Route to Router

```dart
GoRoute(
  path: '/face-search',
  builder: (context, state) => const FaceSearchScreen(),
),
```

### Using the Service Directly

```dart
final faceSearchService = ref.read(faceSearchServiceProvider);

// Detect faces in an image
final faces = await faceSearchService.detectFaces(imageFile);

// Search for items with matching faces
final results = await faceSearchService.searchByFace(
  imageFile: imageFile,
  threshold: 60,
  limit: 20,
);

for (final result in results) {
  print('Found: ${result.title} (${result.similarity}% match)');
}
```

---

## 🌐 Web App Integration

### Opening Face Search Modal

```javascript
// Open the face search modal
FaceSearch.openFaceSearchModal();

// Or click the face search button in the header
```

### Programmatic Search

```javascript
// Process and search
await FaceSearch.processImage(file);
await FaceSearch.performSearch();

// Access results
console.log(FaceSearch.searchResults);
```

---

## 📊 Comprehensive Matching System

When an item is created, the system automatically compares it against all potential matches using **6 different scoring components**:

### Score Components & Weights

| Component | Weight | Description |
|-----------|--------|-------------|
| **📝 Text** | 20% | Description and title similarity using word matching |
| **📷 Image** | 30% | Visual similarity (colors + object labels) via Vision API |
| **📍 Location** | 15% | Geographical proximity (0km = 100%, 50km+ = 0%) |
| **⏱️ Time** | 10% | Time difference (0h = 100%, 240h+ = 0%) |
| **👤 Face** | 15% | Face vector matching for items with faces |
| **🤖 AI** | 10% | Semantic understanding via Gemini AI |

### Overall Score Calculation

```
Overall Score = (Text × 0.20) + (Image × 0.30) + (Location × 0.15) + 
                (Time × 0.10) + (Face × 0.15) + (AI × 0.10)
```

**Note:** If images or faces are not present, their weights are redistributed to other components.

---

## 🎯 Match Confidence Levels

| Similarity | Confidence | Color |
|------------|------------|-------|
| 90-100% | Very High | Green (#10B981) |
| 75-89% | High | Light Green (#22C55E) |
| 60-74% | Medium | Orange (#F59E0B) |
| 45-59% | Low | Red (#EF4444) |
| <45% | Very Low | Gray (#6B7280) |

---

## 🔐 Security Considerations

1. **Authentication Required**: Face search requires user authentication
2. **Privacy**: Face data is stored securely and only accessible to authorized users
3. **Rate Limiting**: Consider implementing rate limits on the search function
4. **Data Retention**: Face data is deleted when items are deleted (GDPR compliance)

---

## 📈 Performance Optimization

### Current Limits
- Maximum 500 faces scanned per search
- Items limited to 50 per query
- Threshold range: 30-95%

### Optimization Tips
1. Use Firestore indexes on `hasFaces` and `status` fields
2. Consider caching frequently searched face vectors
3. For large datasets, implement pagination

### Recommended Firestore Index

```json
{
  "collectionGroup": "items",
  "fieldPath": "status",
  "order": "ASCENDING"
},
{
  "collectionGroup": "items", 
  "fieldPath": "hasFaces",
  "order": "ASCENDING"
}
```

---

## 🔮 Future Enhancements

1. **Deep Learning Models**: Replace Vision API landmarks with dedicated face embedding models (FaceNet, VGGFace)
2. **Offline Search**: Cache face vectors locally for offline matching
3. **Real-time Updates**: WebSocket-based live search results
4. **Age Estimation**: Add approximate age detection
5. **Multi-face Search**: Search using multiple faces simultaneously

---

## 🐛 Troubleshooting

### "No faces detected"
- Ensure the image has clear, visible faces
- Check lighting and image quality
- Faces should be at least 15% of image size

### "Search returns no results"
- Try lowering the threshold (e.g., 50%)
- Ensure items with faces exist in the database
- Check if `hasFaces: true` items exist

### "Cloud function error"
- Verify Vision API is enabled
- Check Cloud Functions logs for details
- Ensure billing is enabled on the project

---

## 📚 API Reference

### Face Detection Response

```typescript
interface DetectedFace {
    faceIndex: number;
    boundingBox: BoundingBox;
    landmarks: Landmark[];
    emotions: Emotions;
    angles: Angles;
    confidence: number;
    faceVector: number[];
}
```

### Search Result

```typescript
interface FaceSearchResult {
    itemId: string;
    item: ItemData;
    faceData: FaceData;
    similarity: number;        // 0-100
    matchConfidence: string;   // 'Very High' | 'High' | 'Medium' | 'Low' | 'Very Low'
}
```

---

**Last Updated:** December 26, 2024
**Version:** 1.0.0
**Author:** FindBack Development Team
