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
exports.generateMonthlyReport = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
/**
 * Generate monthly analytics report
 * Runs on 1st of each month at midnight (Sri Lanka time)
 */
exports.generateMonthlyReport = functions.pubsub
    .schedule('0 0 1 * *')
    .timeZone('Asia/Colombo')
    .onRun(async (context) => {
    const db = admin.firestore();
    const now = new Date();
    const lastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const thisMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    console.log('📊 Generating monthly analytics report...');
    try {
        // Calculate items statistics
        const itemsSnapshot = await db
            .collection('items')
            .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(lastMonth))
            .where('createdAt', '<', admin.firestore.Timestamp.fromDate(thisMonth))
            .get();
        const lostItems = itemsSnapshot.docs.filter(doc => doc.data().type === 'lost').length;
        const foundItems = itemsSnapshot.docs.filter(doc => doc.data().type === 'found').length;
        // Calculate claims statistics
        const claimsSnapshot = await db
            .collection('claims')
            .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(lastMonth))
            .where('createdAt', '<', admin.firestore.Timestamp.fromDate(thisMonth))
            .get();
        const completedClaims = claimsSnapshot.docs.filter((doc) => doc.data().status === 'completed').length;
        // Calculate user statistics
        const usersSnapshot = await db
            .collection('users')
            .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(lastMonth))
            .where('createdAt', '<', admin.firestore.Timestamp.fromDate(thisMonth))
            .get();
        // Calculate category breakdown
        const categoryBreakdown = {};
        itemsSnapshot.docs.forEach(doc => {
            const category = doc.data().category || 'Other';
            categoryBreakdown[category] = (categoryBreakdown[category] || 0) + 1;
        });
        // Calculate district breakdown
        const districtBreakdown = {};
        itemsSnapshot.docs.forEach(doc => {
            const district = doc.data().district || 'Unknown';
            districtBreakdown[district] = (districtBreakdown[district] || 0) + 1;
        });
        const report = {
            period: {
                start: lastMonth.toISOString(),
                end: thisMonth.toISOString(),
                month: lastMonth.toLocaleDateString('en-US', { month: 'long', year: 'numeric' }),
            },
            items: {
                total: itemsSnapshot.size,
                lost: lostItems,
                found: foundItems,
            },
            claims: {
                total: claimsSnapshot.size,
                completed: completedClaims,
                successRate: claimsSnapshot.size > 0
                    ? Math.round((completedClaims / claimsSnapshot.size) * 100)
                    : 0,
            },
            users: {
                newRegistrations: usersSnapshot.size,
            },
            breakdown: {
                byCategory: categoryBreakdown,
                byDistrict: districtBreakdown,
            },
            generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        await db.collection('analytics_reports').add(report);
        console.log('✅ Monthly report generated:', report.period.month);
        console.log(`   Items: ${report.items.total} (Lost: ${lostItems}, Found: ${foundItems})`);
        console.log(`   Claims: ${report.claims.total} (Success Rate: ${report.claims.successRate}%)`);
        console.log(`   New Users: ${report.users.newRegistrations}`);
        return null;
    }
    catch (error) {
        console.error('❌ Error generating monthly report:', error);
        return null;
    }
});
//# sourceMappingURL=analytics.js.map