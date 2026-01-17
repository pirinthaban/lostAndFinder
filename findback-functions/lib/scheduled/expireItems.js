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
exports.expireOldItems = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
/**
 * Scheduled function to expire old items
 * Runs daily at midnight (Sri Lanka time)
 */
exports.expireOldItems = functions.pubsub
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
        const userNotifications = new Map();
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
    }
    catch (error) {
        console.error('❌ Error expiring items:', error);
        return null;
    }
});
//# sourceMappingURL=expireItems.js.map