import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

// Import function modules
import { onItemCreated } from './triggers/onItemCreated';
import { processImageUpload } from './triggers/processImageUpload';
import { calculateMatchScore } from './ai/matchingEngine';
import { sendMatchNotification } from './notifications/matchNotifications';
import { onClaimCreated } from './triggers/onClaimCreated';
import { moderateContent } from './moderation/contentModeration';

// Export Cloud Functions

/**
 * Triggered when a new item is created
 * - Processes images
 * - Extracts features
 * - Runs AI matching
 * - Sends notifications for high-confidence matches
 */
export const itemCreated = onItemCreated;

/**
 * Processes uploaded images
 * - Auto-detects and blurs sensitive information (NIC numbers, faces)
 * - Generates thumbnails
 * - Extracts image embeddings for AI matching
 */
export const processImage = processImageUpload;

/**
 * Calculates match score between lost and found items
 * - Image similarity
 * - Text similarity
 * - Location proximity
 * - Time difference
 */
export const matchItems = calculateMatchScore;

/**
 * Sends push notifications for high-confidence matches
 */
export const notifyMatches = sendMatchNotification;

/**
 * Triggered when a claim is created
 * - Notifies item owner
 * - Starts verification workflow
 */
export const claimCreated = onClaimCreated;

/**
 * Moderates user-generated content
 * - Detects inappropriate content
 * - Flags potential spam/fraud
 */
export const moderateItem = moderateContent;

/**
 * Scheduled function to expire old items
 * Runs daily at midnight
 */
export const expireOldItems = functions.pubsub
  .schedule('0 0 * * *')
  .timeZone('Asia/Colombo')
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    
    const expiredItems = await db
      .collection('items')
      .where('expiresAt', '<=', now)
      .where('status', '==', 'active')
      .get();

    const batch = db.batch();
    expiredItems.docs.forEach((doc) => {
      batch.update(doc.ref, { status: 'expired' });
    });

    await batch.commit();
    
    console.log(`Expired ${expiredItems.size} items`);
    return null;
  });

/**
 * Updates user reputation score
 */
export const updateReputation = functions.firestore
  .document('claims/{claimId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // If claim completed successfully
    if (before.status !== 'completed' && after.status === 'completed') {
      const db = admin.firestore();
      
      // Update item owner reputation (item returned)
      const ownerRef = db.collection('users').doc(after.itemOwnerId);
      await ownerRef.update({
        itemsReturned: admin.firestore.FieldValue.increment(1),
        reputation: admin.firestore.FieldValue.increment(50),
      });

      // Update claimant reputation (successful claim)
      const claimantRef = db.collection('users').doc(after.claimantUserId);
      await claimantRef.update({
        reputation: admin.firestore.FieldValue.increment(30),
      });

      // Calculate success rate
      const ownerDoc = await ownerRef.get();
      const ownerData = ownerDoc.data();
      if (ownerData) {
        const successRate = (ownerData.itemsReturned / ownerData.itemsPosted) * 100;
        await ownerRef.update({ successRate });
      }
    }

    return null;
  });

/**
 * Audit log for critical actions
 */
export const createAuditLog = functions.firestore
  .document('{collection}/{documentId}')
  .onWrite(async (change, context) => {
    const collection = context.params.collection;
    
    // Only audit critical collections
    if (!['users', 'items', 'claims', 'police_verifications'].includes(collection)) {
      return null;
    }

    const db = admin.firestore();
    const auditLog = {
      collection,
      documentId: context.params.documentId,
      action: !change.before.exists ? 'create' : !change.after.exists ? 'delete' : 'update',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      before: change.before.data() || null,
      after: change.after.data() || null,
    };

    await db.collection('audit_logs').add(auditLog);
    return null;
  });

/**
 * Clean up deleted user data (GDPR compliance)
 */
export const cleanupUserData = functions.auth
  .user()
  .onDelete(async (user) => {
    const db = admin.firestore();
    const userId = user.uid;

    // Delete user document
    await db.collection('users').doc(userId).delete();

    // Delete user's items
    const items = await db.collection('items').where('userId', '==', userId).get();
    const batch = db.batch();
    items.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();

    // Delete user's messages
    const messages = await db.collection('messages').where('senderId', '==', userId).get();
    const messageBatch = db.batch();
    messages.docs.forEach((doc) => {
      messageBatch.delete(doc.ref);
    });

    await messageBatch.commit();

    console.log(`Cleaned up data for deleted user: ${userId}`);
    return null;
  });

/**
 * HTTP endpoint for manual match recalculation
 */
export const recalculateMatches = functions.https.onCall(async (data, context) => {
  // Verify admin authentication
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can recalculate matches'
    );
  }

  const { itemId } = data;
  
  // TODO: Implement match recalculation logic
  
  return { success: true, itemId };
});

/**
 * Generate monthly analytics report
 */
export const generateMonthlyReport = functions.pubsub
  .schedule('0 0 1 * *')
  .timeZone('Asia/Colombo')
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = new Date();
    const lastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const thisMonth = new Date(now.getFullYear(), now.getMonth(), 1);

    // Calculate statistics
    const itemsSnapshot = await db
      .collection('items')
      .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(lastMonth))
      .where('createdAt', '<', admin.firestore.Timestamp.fromDate(thisMonth))
      .get();

    const claimsSnapshot = await db
      .collection('claims')
      .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(lastMonth))
      .where('createdAt', '<', admin.firestore.Timestamp.fromDate(thisMonth))
      .get();

    const completedClaims = claimsSnapshot.docs.filter(
      (doc) => doc.data().status === 'completed'
    ).length;

    const report = {
      period: `${lastMonth.toISOString()} to ${thisMonth.toISOString()}`,
      totalItemsPosted: itemsSnapshot.size,
      totalClaims: claimsSnapshot.size,
      successfulReturns: completedClaims,
      successRate: claimsSnapshot.size > 0 
        ? (completedClaims / claimsSnapshot.size) * 100 
        : 0,
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('analytics_reports').add(report);
    
    console.log('Monthly report generated:', report);
    return null;
  });
