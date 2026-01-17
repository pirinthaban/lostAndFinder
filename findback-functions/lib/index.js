"use strict";
/**
 * FindBack Cloud Functions - Main Entry Point
 *
 * This file exports all Cloud Functions for Firebase deployment.
 * Each function is organized by category in separate modules.
 */
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
exports.createAuditLog = exports.recalculateMatches = exports.testFaceDetection = exports.deleteFaceData = exports.searchByFace = exports.processFaceData = exports.moderateItem = exports.updateReputation = exports.cleanupUserData = exports.generateMonthlyReport = exports.expireOldItems = exports.messageCreated = exports.claimCreated = exports.itemCreated = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
// Initialize Firebase Admin
admin.initializeApp();
// ============================================
// TRIGGERS - Firestore Document Events
// ============================================
// Item Created - AI Matching
const onItemCreated_1 = require("./triggers/onItemCreated");
exports.itemCreated = onItemCreated_1.onItemCreated;
// Claim Created - Process Claims
const onClaimCreated_1 = require("./triggers/onClaimCreated");
exports.claimCreated = onClaimCreated_1.onClaimCreated;
// ============================================
// NOTIFICATIONS - Push Notification Functions
// ============================================
// New Chat Message - Send Push Notification
const onNewMessage_1 = require("./notifications/onNewMessage");
exports.messageCreated = onNewMessage_1.onNewMessage;
// ============================================
// SCHEDULED - Cron Jobs
// ============================================
// Expire Old Items - Runs daily at midnight (Sri Lanka time)
const expireItems_1 = require("./scheduled/expireItems");
Object.defineProperty(exports, "expireOldItems", { enumerable: true, get: function () { return expireItems_1.expireOldItems; } });
// Monthly Analytics Report - Runs on 1st of each month
const analytics_1 = require("./scheduled/analytics");
Object.defineProperty(exports, "generateMonthlyReport", { enumerable: true, get: function () { return analytics_1.generateMonthlyReport; } });
// ============================================
// USER MANAGEMENT
// ============================================
// Clean up user data when account deleted (GDPR)
const onUserDeleted_1 = require("./triggers/onUserDeleted");
Object.defineProperty(exports, "cleanupUserData", { enumerable: true, get: function () { return onUserDeleted_1.cleanupUserData; } });
// Update reputation on successful claim
const onClaimUpdated_1 = require("./triggers/onClaimUpdated");
Object.defineProperty(exports, "updateReputation", { enumerable: true, get: function () { return onClaimUpdated_1.updateReputation; } });
// ============================================
// MODERATION
// ============================================
// Content moderation
const contentModeration_1 = require("./moderation/contentModeration");
Object.defineProperty(exports, "moderateItem", { enumerable: true, get: function () { return contentModeration_1.moderateItem; } });
// ============================================
// FACE RECOGNITION - Face-Based Item Search
// ============================================
// Face data processing on item creation
const faceRecognition_1 = require("./ai/faceRecognition");
Object.defineProperty(exports, "processFaceData", { enumerable: true, get: function () { return faceRecognition_1.processFaceData; } });
Object.defineProperty(exports, "searchByFace", { enumerable: true, get: function () { return faceRecognition_1.searchByFace; } });
Object.defineProperty(exports, "deleteFaceData", { enumerable: true, get: function () { return faceRecognition_1.deleteFaceData; } });
Object.defineProperty(exports, "testFaceDetection", { enumerable: true, get: function () { return faceRecognition_1.testFaceDetection; } });
// ============================================
// HTTP CALLABLE FUNCTIONS
// ============================================
/**
 * Admin-only function to recalculate matches for an item
 */
exports.recalculateMatches = functions.https.onCall(async (data, context) => {
    // Verify admin authentication
    if (!context.auth || !context.auth.token.admin) {
        throw new functions.https.HttpsError('permission-denied', 'Only admins can recalculate matches');
    }
    const { itemId } = data;
    // TODO: Implement match recalculation logic
    console.log(`Recalculating matches for item: ${itemId}`);
    return { success: true, itemId };
});
// ============================================
// AUDIT LOGGING
// ============================================
/**
 * Audit log for critical actions
 */
exports.createAuditLog = functions.firestore
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
//# sourceMappingURL=index.js.map