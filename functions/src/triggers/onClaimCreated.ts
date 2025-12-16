import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Triggered when a claim is created
 */
export const onClaimCreated = functions.firestore
  .document('claims/{claimId}')
  .onCreate(async (snapshot, context) => {
    const claim = snapshot.data();
    const claimId = context.params.claimId;

    console.log(`New claim created: ${claimId}`);

    try {
      const db = admin.firestore();

      // Get item details
      const itemDoc = await db.collection('items').doc(claim.itemId).get();
      const item = itemDoc.data();

      if (!item) {
        console.error(`Item ${claim.itemId} not found`);
        return null;
      }

      // Update item status
      await itemDoc.ref.update({
        status: 'claimed',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Notify item owner
      await sendClaimNotification(item.userId, claim, item);

      // Generate handover code
      const handoverCode = generateHandoverCode();
      await snapshot.ref.update({ handoverCode });

      return { success: true };
    } catch (error) {
      console.error('Error processing claim:', error);
      return { success: false, error: String(error) };
    }
  });

/**
 * Send notification to item owner about new claim
 */
async function sendClaimNotification(
  ownerId: string,
  claim: any,
  item: any
): Promise<void> {
  const db = admin.firestore();

  // Get claimant details
  const claimantDoc = await db.collection('users').doc(claim.claimantUserId).get();
  const claimant = claimantDoc.data();

  if (!claimant) return;

  // Get owner's FCM token
  const ownerDoc = await db.collection('users').doc(ownerId).get();
  const owner = ownerDoc.data();

  if (!owner || !owner.fcmToken) {
    console.log(`No FCM token for user ${ownerId}`);
    return;
  }

  const notification = {
    title: '📋 New Claim Request',
    body: `${claimant.displayName} is claiming your ${item.category}`,
    data: {
      type: 'claim',
      claimId: claim.id,
      itemId: item.id,
    },
  };

  try {
    await admin.messaging().send({
      token: owner.fcmToken,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: notification.data,
      android: {
        priority: 'high',
      },
    });

    // Save notification to Firestore
    await db.collection('notifications').add({
      userId: ownerId,
      ...notification,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Claim notification sent to ${ownerId}`);
  } catch (error) {
    console.error(`Error sending claim notification:`, error);
  }
}

/**
 * Generate 6-digit handover code
 */
function generateHandoverCode(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}
