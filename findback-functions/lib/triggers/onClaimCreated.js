"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onClaimCreated = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
/**
 * Triggered when a claim is created
 * - Notifies item owner
 * - Generates handover code
 */
exports.onClaimCreated = functions.firestore
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
    }
    catch (error) {
        console.error('❌ Error processing claim:', error);
        return { success: false, error: String(error) };
    }
});
/**
 * Send notification to item owner about new claim
 */
async function sendClaimNotification(ownerId, claim, item) {
    var _a;
    const db = admin.firestore();
    // Get claimant details
    const claimantDoc = await db.collection('users').doc(claim.claimantUserId).get();
    const claimant = claimantDoc.data();
    if (!claimant)
        return;
    // Get owner's FCM token
    const ownerDoc = await db.collection('users').doc(ownerId).get();
    const owner = ownerDoc.data();
    const claimantName = claimant.name || ((_a = claimant.email) === null || _a === void 0 ? void 0 : _a.split('@')[0]) || 'Someone';
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
    }
    catch (error) {
        console.error(`❌ Error sending claim notification:`, error);
    }
}
/**
 * Generate 6-digit handover code
 */
function generateHandoverCode() {
    return Math.floor(100000 + Math.random() * 900000).toString();
}
//# sourceMappingURL=onClaimCreated.js.map