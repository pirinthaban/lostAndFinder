import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Triggered when a claim is updated
 * Updates reputation when claim is completed
 */
export const updateReputation = functions.firestore
    .document('claims/{claimId}')
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();

        // If claim completed successfully
        if (before.status !== 'completed' && after.status === 'completed') {
            const db = admin.firestore();

            console.log(`🏆 Claim ${context.params.claimId} completed!`);

            try {
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
                if (ownerData && ownerData.itemsPosted > 0) {
                    const successRate = (ownerData.itemsReturned / ownerData.itemsPosted) * 100;
                    await ownerRef.update({ successRate });
                }

                console.log(`✅ Reputation updated for claim ${context.params.claimId}`);
            } catch (error) {
                console.error('❌ Error updating reputation:', error);
            }
        }

        return null;
    });
