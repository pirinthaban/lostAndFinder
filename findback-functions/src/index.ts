/**
 * FindBack Cloud Functions - Main Entry Point
 * 
 * This file exports all Cloud Functions for Firebase deployment.
 * Each function is organized by category in separate modules.
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin
admin.initializeApp();

// ============================================
// TRIGGERS - Firestore Document Events
// ============================================

// Item Created - AI Matching
import { onItemCreated } from './triggers/onItemCreated';
export const itemCreated = onItemCreated;

// Claim Created - Process Claims
import { onClaimCreated } from './triggers/onClaimCreated';
export const claimCreated = onClaimCreated;

// ============================================
// NOTIFICATIONS - Push Notification Functions
// ============================================

// New Chat Message - Send Push Notification
import { onNewMessage } from './notifications/onNewMessage';
export const messageCreated = onNewMessage;

// ============================================
// SCHEDULED - Cron Jobs
// ============================================

// Expire Old Items - Runs daily at midnight (Sri Lanka time)
import { expireOldItems } from './scheduled/expireItems';
export { expireOldItems };

// Monthly Analytics Report - Runs on 1st of each month
import { generateMonthlyReport } from './scheduled/analytics';
export { generateMonthlyReport };

// ============================================
// USER MANAGEMENT
// ============================================

// Clean up user data when account deleted (GDPR)
import { cleanupUserData } from './triggers/onUserDeleted';
export { cleanupUserData };

// Update reputation on successful claim
import { updateReputation } from './triggers/onClaimUpdated';
export { updateReputation };

// ============================================
// MODERATION
// ============================================

// Content moderation
import { moderateItem } from './moderation/contentModeration';
export { moderateItem };

// ============================================
// FACE RECOGNITION - Face-Based Item Search
// ============================================

// Face data processing on item creation
import { processFaceData, searchByFace, deleteFaceData, testFaceDetection } from './ai/faceRecognition';
export { processFaceData, searchByFace, deleteFaceData, testFaceDetection };

// ============================================
// HTTP CALLABLE FUNCTIONS
// ============================================

/**
 * Admin-only function to recalculate matches for an item
 */
export const recalculateMatches = functions.https.onCall(async (data, context) => {
    // Verify admin authentication
    if (!context.auth || !context.auth.token.admin) {
        throw new functions.https.HttpsError(
            'permission-denied',
            'Only admins can recalculate matches'
        );
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
export const createAuditLog = functions.firestore
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
