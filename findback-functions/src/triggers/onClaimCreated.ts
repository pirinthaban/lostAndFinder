import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Triggered when a claim is created
 * - Notifies item owner
 * - Generates handover code
 */
export const onClaimCreated = functions.firestore
    .document('claims/{claimId}')
    .onCreate(async (snapshot, context) => {
        const claim = snapshot.data();
        const claimId = context.params.claimId;

        console.log(`📋 New claim created: ${claimId}`);

        try {
            const db = admin.firestore();

            // Get item details
            const itemDoc = await db.collection('items').doc(claim.itemId).get();
            const item = itemDoc.data();

            if (!item) {
                console.error(`❌ Item ${claim.itemId} not found`);
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

            console.log(`✅ Claim processed: ${claimId}`);
            return { success: true };
        } catch (error) {
            console.error('❌ Error processing claim:', error);
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

    const claimantName = claimant.name || claimant.email?.split('@')[0] || 'Someone';

    if (!owner || !owner.fcmToken) {
        console.log(`📭 No FCM token for user ${ownerId}`);
        // Still save to Firestore for in-app notification
        await db.collection('notifications').add({
            userId: ownerId,
            title: '📋 New Claim Request',
            body: `${claimantName} is claiming your ${item.category}`,
            type: 'claim',
            data: {
                claimId: claim.id,
                itemId: item.id,
            },
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
    }

    try {
        await admin.messaging().send({
            token: owner.fcmToken,
            notification: {
                title: '📋 New Claim Request',
                body: `${claimantName} is claiming your ${item.category}`,
            },
            data: {
                type: 'claim',
                claimId: claim.id || '',
                itemId: item.id || '',
            },
            android: {
                priority: 'high',
                notification: {
                    channelId: 'claim_channel',
                    icon: '@mipmap/ic_launcher',
                    color: '#F59E0B',
                },
            },
        });

        // Save notification to Firestore
        await db.collection('notifications').add({
            userId: ownerId,
            title: '📋 New Claim Request',
            body: `${claimantName} is claiming your ${item.category}`,
            type: 'claim',
            data: {
                claimId: claim.id,
                itemId: item.id,
            },
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`✅ Claim notification sent to ${ownerId}`);
    } catch (error) {
        console.error(`❌ Error sending claim notification:`, error);
    }
}

/**
 * Generate 6-digit handover code
 */
function generateHandoverCode(): string {
    return Math.floor(100000 + Math.random() * 900000).toString();
}
