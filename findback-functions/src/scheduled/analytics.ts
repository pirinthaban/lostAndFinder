import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Generate monthly analytics report
 * Runs on 1st of each month at midnight (Sri Lanka time)
 */
export const generateMonthlyReport = functions.pubsub
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

            const completedClaims = claimsSnapshot.docs.filter(
                (doc) => doc.data().status === 'completed'
            ).length;

            // Calculate user statistics
            const usersSnapshot = await db
                .collection('users')
                .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(lastMonth))
                .where('createdAt', '<', admin.firestore.Timestamp.fromDate(thisMonth))
                .get();

            // Calculate category breakdown
            const categoryBreakdown: Record<string, number> = {};
            itemsSnapshot.docs.forEach(doc => {
                const category = doc.data().category || 'Other';
                categoryBreakdown[category] = (categoryBreakdown[category] || 0) + 1;
            });

            // Calculate district breakdown
            const districtBreakdown: Record<string, number> = {};
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
        } catch (error) {
            console.error('❌ Error generating monthly report:', error);
            return null;
        }
    });
