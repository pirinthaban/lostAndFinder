import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Scheduled function to expire old items
 * Runs daily at midnight (Sri Lanka time)
 */
export const expireOldItems = functions.pubsub
    .schedule('0 0 * * *')
    .timeZone('Asia/Colombo')
    .onRun(async (context) => {
        const db = admin.firestore();
        const now = admin.firestore.Timestamp.now();

        console.log('🕐 Running daily item expiration check...');

        try {
            // Find items that have expired
            const expiredItems = await db
                .collection('items')
                .where('expiresAt', '<=', now)
                .where('status', '==', 'active')
                .get();

            if (expiredItems.empty) {
                console.log('No items to expire');
                return null;
            }

            const batch = db.batch();
            const userNotifications: Map<string, number> = new Map();

            expiredItems.docs.forEach((doc) => {
                batch.update(doc.ref, {
                    status: 'expired',
                    expiredAt: admin.firestore.FieldValue.serverTimestamp(),
                });

                // Track notifications to send
                const userId = doc.data().userId;
                userNotifications.set(userId, (userNotifications.get(userId) || 0) + 1);
            });

            await batch.commit();

            // Send notifications to users whose items expired
            for (const [userId, count] of userNotifications) {
                await db.collection('notifications').add({
                    userId,
                    title: '⏰ Items Expired',
                    body: `${count} of your posted items have expired. You can renew them from your profile.`,
                    type: 'item_expired',
                    read: false,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }

            console.log(`✅ Expired ${expiredItems.size} items`);
            return null;
        } catch (error) {
            console.error('❌ Error expiring items:', error);
            return null;
        }
    });
