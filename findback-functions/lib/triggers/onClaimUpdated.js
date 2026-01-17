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
exports.updateReputation = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
/**
 * Triggered when a claim is updated
 * Updates reputation when claim is completed
 */
exports.updateReputation = functions.firestore
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
        }
        catch (error) {
            console.error('❌ Error updating reputation:', error);
        }
    }
    return null;
});
//# sourceMappingURL=onClaimUpdated.js.map