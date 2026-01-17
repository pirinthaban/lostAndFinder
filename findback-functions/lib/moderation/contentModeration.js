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
exports.moderateItem = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
/**
 * Content moderation for user-generated content
 * Checks for inappropriate content using keyword filtering
 */
exports.moderateItem = functions.firestore
    .document('items/{itemId}')
    .onCreate(async (snapshot, context) => {
    const item = snapshot.data();
    const itemId = context.params.itemId;
    console.log(`🔍 Moderating item: ${itemId}`);
    try {
        const moderationResult = await moderateContent({
            title: item.title,
            description: item.description,
        });
        if (!moderationResult.isAppropriate) {
            console.log(`⚠️ Item ${itemId} flagged for review:`, moderationResult.reasons);
            // Flag the item for manual review
            await snapshot.ref.update({
                moderationStatus: 'flagged',
                moderationReasons: moderationResult.reasons,
                moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            // Create moderation report
            await admin.firestore().collection('moderation_reports').add({
                itemId,
                userId: item.userId,
                type: 'auto_flagged',
                reasons: moderationResult.reasons,
                confidence: moderationResult.confidence,
                status: 'pending_review',
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        else {
            // Mark as approved
            await snapshot.ref.update({
                moderationStatus: 'approved',
                moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        return { success: true };
    }
    catch (error) {
        console.error('❌ Error moderating content:', error);
        return { success: false, error: String(error) };
    }
});
/**
 * Check content for inappropriate material
 */
async function moderateContent(content) {
    const reasons = [];
    let confidence = 0.95;
    const textToCheck = `${content.title} ${content.description}`.toLowerCase();
    // List of inappropriate keywords (basic implementation)
    const inappropriateKeywords = [
        'scam', 'fraud', 'fake', 'spam',
        // Add more keywords as needed
    ];
    // Check for inappropriate keywords
    for (const keyword of inappropriateKeywords) {
        if (textToCheck.includes(keyword)) {
            reasons.push(`Contains inappropriate keyword: ${keyword}`);
            confidence = 0.8;
        }
    }
    // Check for suspicious patterns
    if (/\d{3}[-.\s]?\d{3}[-.\s]?\d{4}/.test(textToCheck)) {
        // Phone number pattern - might be okay for contact, but flag for review
        reasons.push('Contains phone number');
        confidence = 0.7;
    }
    // Check for excessive caps (potential spam)
    const capsRatio = (textToCheck.match(/[A-Z]/g) || []).length / textToCheck.length;
    if (capsRatio > 0.5 && textToCheck.length > 20) {
        reasons.push('Excessive capitalization');
        confidence = 0.6;
    }
    // Check for repetitive characters (potential spam)
    if (/(.)\1{4,}/.test(textToCheck)) {
        reasons.push('Repetitive characters detected');
        confidence = 0.5;
    }
    return {
        isAppropriate: reasons.length === 0,
        confidence,
        reasons,
    };
}
//# sourceMappingURL=contentModeration.js.map