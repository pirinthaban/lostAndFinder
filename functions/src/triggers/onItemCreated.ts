import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Triggered when a new item is created
 * Initiates AI matching process
 */
export const onItemCreated = functions.firestore
  .document('items/{itemId}')
  .onCreate(async (snapshot, context) => {
    const item = snapshot.data();
    const itemId = context.params.itemId;

    console.log(`New item created: ${itemId}, type: ${item.type}`);

    try {
      // Find potential matches
      const matches = await findPotentialMatches(itemId, item);

      console.log(`Found ${matches.length} potential matches for ${itemId}`);

      // Save matches to Firestore
      const db = admin.firestore();
      const batch = db.batch();

      matches.forEach((match) => {
        const matchRef = db.collection('matches').doc();
        batch.set(matchRef, {
          ...match,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          notificationSent: false,
        });
      });

      await batch.commit();

      // Update item match count
      await snapshot.ref.update({
        matchCount: matches.length,
      });

      // Send notifications for high-confidence matches (>70%)
      const highConfidenceMatches = matches.filter((m) => m.confidenceScore > 70);
      
      for (const match of highConfidenceMatches) {
        await sendMatchNotificationToUser(match);
      }

      return { success: true, matchesFound: matches.length };
    } catch (error) {
      console.error('Error processing new item:', error);
      return { success: false, error: String(error) };
    }
  });

/**
 * Find potential matches for an item
 */
async function findPotentialMatches(itemId: string, item: any): Promise<any[]> {
  const db = admin.firestore();
  const matches: any[] = [];

  // Determine opposite type to search
  const searchType = item.type === 'lost' ? 'found' : 'lost';

  // Query items of opposite type in same category and district
  const potentialMatches = await db
    .collection('items')
    .where('type', '==', searchType)
    .where('category', '==', item.category)
    .where('district', '==', item.district)
    .where('status', '==', 'active')
    .limit(50)
    .get();

  for (const doc of potentialMatches.docs) {
    const potentialMatch = doc.data();
    const matchScore = calculateMatchScore(item, potentialMatch);

    if (matchScore.confidenceScore > 30) {
      matches.push({
        lostItemId: item.type === 'lost' ? itemId : doc.id,
        foundItemId: item.type === 'found' ? itemId : doc.id,
        ...matchScore,
        status: 'pending',
      });
    }
  }

  // Sort by confidence score
  matches.sort((a, b) => b.confidenceScore - a.confidenceScore);

  return matches.slice(0, 10); // Return top 10 matches
}

/**
 * Calculate match score between two items
 */
function calculateMatchScore(item1: any, item2: any): any {
  // Image similarity (placeholder - implement with TensorFlow)
  const imageSimilarity = calculateImageSimilarity(item1.images, item2.images);

  // Text similarity (simple word matching)
  const textSimilarity = calculateTextSimilarity(
    item1.description,
    item2.description
  );

  // Location proximity (km)
  const locationProximity = calculateLocationProximity(
    item1.location,
    item2.location
  );

  // Time difference (hours)
  const timeDifference = Math.abs(
    item1.createdAt.toMillis() - item2.createdAt.toMillis()
  ) / (1000 * 60 * 60);

  // Calculate confidence score (weighted average)
  const confidenceScore = Math.round(
    imageSimilarity * 0.4 +
    textSimilarity * 0.3 +
    (100 - Math.min(locationProximity * 2, 100)) * 0.2 +
    (100 - Math.min(timeDifference / 24 * 10, 100)) * 0.1
  );

  return {
    confidenceScore,
    imageSimilarity,
    textSimilarity,
    locationProximity,
    timeDifference: Math.round(timeDifference),
    matchedBy: 'ai',
  };
}

/**
 * Calculate image similarity (placeholder)
 * TODO: Implement with TensorFlow image embeddings
 */
function calculateImageSimilarity(images1: string[], images2: string[]): number {
  // Placeholder: return random score
  // In production, use image embeddings and cosine similarity
  return Math.random() * 50 + 30; // 30-80%
}

/**
 * Calculate text similarity using simple word matching
 */
function calculateTextSimilarity(text1: string, text2: string): number {
  const words1 = text1.toLowerCase().split(/\s+/);
  const words2 = text2.toLowerCase().split(/\s+/);

  const commonWords = words1.filter((word) => words2.includes(word));
  const similarity = (commonWords.length * 2) / (words1.length + words2.length);

  return Math.round(similarity * 100);
}

/**
 * Calculate distance between two geopoints (Haversine formula)
 */
function calculateLocationProximity(
  location1: admin.firestore.GeoPoint,
  location2: admin.firestore.GeoPoint
): number {
  const R = 6371; // Earth's radius in km

  const lat1 = (location1.latitude * Math.PI) / 180;
  const lat2 = (location2.latitude * Math.PI) / 180;
  const deltaLat = ((location2.latitude - location1.latitude) * Math.PI) / 180;
  const deltaLon = ((location2.longitude - location1.longitude) * Math.PI) / 180;

  const a =
    Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2) +
    Math.cos(lat1) *
      Math.cos(lat2) *
      Math.sin(deltaLon / 2) *
      Math.sin(deltaLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const distance = R * c;

  return Math.round(distance * 100) / 100; // km, rounded to 2 decimals
}

/**
 * Send match notification to user
 */
async function sendMatchNotificationToUser(match: any): Promise<void> {
  const db = admin.firestore();

  // Get lost item details
  const lostItemDoc = await db.collection('items').doc(match.lostItemId).get();
  const lostItem = lostItemDoc.data();

  // Get found item details
  const foundItemDoc = await db.collection('items').doc(match.foundItemId).get();
  const foundItem = foundItemDoc.data();

  if (!lostItem || !foundItem) return;

  // Notify lost item owner
  await sendNotification(lostItem.userId, {
    title: '🎉 Potential Match Found!',
    body: `We found a ${match.confidenceScore}% match for your lost ${lostItem.category}`,
    data: {
      type: 'match',
      matchId: match.id,
      itemId: match.lostItemId,
      confidenceScore: String(match.confidenceScore),
    },
  });

  // Notify found item owner
  await sendNotification(foundItem.userId, {
    title: '🎉 Potential Owner Found!',
    body: `We found a ${match.confidenceScore}% match for the ${foundItem.category} you found`,
    data: {
      type: 'match',
      matchId: match.id,
      itemId: match.foundItemId,
      confidenceScore: String(match.confidenceScore),
    },
  });
}

/**
 * Send push notification to user
 */
async function sendNotification(
  userId: string,
  notification: any
): Promise<void> {
  const db = admin.firestore();

  // Get user's FCM token
  const userDoc = await db.collection('users').doc(userId).get();
  const user = userDoc.data();

  if (!user || !user.fcmToken) {
    console.log(`No FCM token for user ${userId}`);
    return;
  }

  // Send FCM notification
  try {
    await admin.messaging().send({
      token: user.fcmToken,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: notification.data,
      android: {
        priority: 'high',
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    });

    // Save notification to Firestore
    await db.collection('notifications').add({
      userId,
      ...notification,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Notification sent to user ${userId}`);
  } catch (error) {
    console.error(`Error sending notification to ${userId}:`, error);
  }
}
