import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Clean up deleted user data (GDPR compliance)
 * Triggered when a user account is deleted
 */
export const cleanupUserData = functions.auth
    .user()
    .onDelete(async (user) => {
        const db = admin.firestore();
        const userId = user.uid;

        console.log(`🗑️ Cleaning up data for deleted user: ${userId}`);

        try {
            // Delete user document
            await db.collection('users').doc(userId).delete();

            // Delete user's items
            const items = await db.collection('items').where('userId', '==', userId).get();
            const itemBatch = db.batch();
            items.docs.forEach((doc) => {
                itemBatch.delete(doc.ref);
            });
            await itemBatch.commit();
            console.log(`  Deleted ${items.size} items`);

            // Delete user's chats (where user is participant)
            const chats = await db.collection('chats')
                .where('participants', 'array-contains', userId)
                .get();

            for (const chat of chats.docs) {
                // Delete messages in chat
                const messages = await chat.ref.collection('messages').get();
                const msgBatch = db.batch();
                messages.docs.forEach((msg) => {
                    msgBatch.delete(msg.ref);
                });
                await msgBatch.commit();

                // Delete chat document
                await chat.ref.delete();
            }
            console.log(`  Deleted ${chats.size} chats`);

            // Delete user's notifications
            const notifications = await db.collection('notifications')
                .where('userId', '==', userId)
                .get();
            const notifBatch = db.batch();
            notifications.docs.forEach((doc) => {
                notifBatch.delete(doc.ref);
            });
            await notifBatch.commit();
            console.log(`  Deleted ${notifications.size} notifications`);

            // Delete user's saved items
            const savedItems = await db.collection('users')
                .doc(userId)
                .collection('savedItems')
                .get();
            const savedBatch = db.batch();
            savedItems.docs.forEach((doc) => {
                savedBatch.delete(doc.ref);
            });
            await savedBatch.commit();
            console.log(`  Deleted ${savedItems.size} saved items`);

            // Delete user's matches
            const matches = await db.collection('matches')
                .where('userId', '==', userId)
                .get();
            const matchBatch = db.batch();
            matches.docs.forEach((doc) => {
                matchBatch.delete(doc.ref);
            });
            await matchBatch.commit();
            console.log(`  Deleted ${matches.size} matches`);

            console.log(`✅ Successfully cleaned up data for user: ${userId}`);
            return null;
        } catch (error) {
            console.error(`❌ Error cleaning up user data:`, error);
            return null;
        }
    });
