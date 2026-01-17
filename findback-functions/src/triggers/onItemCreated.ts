import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { GoogleGenerativeAI } from "@google/generative-ai";
import fetch from 'node-fetch'; // Ensure node-fetch is available or use native fetch in Node 18+

// Google Cloud Vision for fallback/basic properties
const vision = require('@google-cloud/vision');
const visionClient = new vision.ImageAnnotatorClient();

// Initialize Gemini with API Key
// USING GEMINI 1.5 FLASH for speed and multimodal capabilities
const genAI = new GoogleGenerativeAI(
    process.env.GEMINI_API_KEY ||
    process.env.gemini_key ||
    "YOUR_API_KEY_PLACEHOLDER"
);

// Firestore reference
const db = admin.firestore();

// ============================================
// MATCH SCORE WEIGHTS (UPDATED FOR AI PRIORITY)
// ============================================
const WEIGHTS = {
    TEXT: 0.15,          // 15% - Basic text similarity
    LOCATION: 0.15,      // 15% - Location proximity
    TIME: 0.10,          // 10% - Time difference
    IMAGE: 0.25,         // 25% - AI + Vision Visual similarity
    FACE: 0.10,          // 10% - Face vector matching
    AI_SEMANTIC: 0.25,   // 25% - Advanced AI Semantic + Visual reasoning
};

// ============================================
// INTERFACES
// ============================================
interface MatchScoreBreakdown {
    textScore: number;
    locationScore: number;
    timeScore: number;
    imageScore: number;
    faceScore: number;
    aiScore: number;

    textContribution: number;
    locationContribution: number;
    timeContribution: number;
    imageContribution: number;
    faceContribution: number;
    aiContribution: number;

    overallScore: number;
    confidenceLevel: string;
    matchedBy: string[];
    hasImages: boolean;
    hasFaces: boolean;
    locationProximityKm: number;
    timeDifferenceHours: number;
    aiReasoning?: string; // New field for AI explanation
}

/**
 * Helper to fetch image and convert to base64 for Gemini
 */
async function urlToGenerativePart(url: string, mimeType: string = "image/jpeg") {
    try {
        const response = await fetch(url);
        if (!response.ok) throw new Error(`Failed to fetch image: ${response.statusText}`);
        const buffer = await response.buffer();
        return {
            inlineData: {
                data: buffer.toString("base64"),
                mimeType
            },
        };
    } catch (error) {
        console.error("Error fetching image for AI:", error);
        return null;
    }
}

/**
 * Triggered when a new item is created
 */
export const onItemCreated = functions.firestore
    .document('items/{itemId}')
    .onCreate(async (snapshot, context) => {
        const item = snapshot.data();
        const itemId = context.params.itemId;

        console.log(`📦 New item created: ${itemId}, type: ${item.type} - Starting AI Analysis`);

        try {
            // Step 1: Process faces
            if (item.images && item.images.length > 0) {
                await processFacesForItem(itemId, item);
            }

            // Step 2: Find matches
            const matches = await findPotentialMatches(itemId, item);

            console.log(`🔍 Found ${matches.length} potential matches for ${itemId}`);

            // Step 3: Save matches
            const batch = db.batch();
            matches.forEach((match) => {
                const matchRef = db.collection('matches').doc();
                batch.set(matchRef, {
                    ...match,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    notificationSent: false,
                });
            });
            await batch.commit();

            // Step 4: Update item
            await snapshot.ref.update({
                matchCount: matches.length,
                matchesProcessedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // Step 5: Notify high confidence matches
            const highConfidenceMatches = matches.filter((m) => m.overallScore > 75);
            for (const match of highConfidenceMatches) {
                await sendMatchNotificationToUser(match);
            }

            return { success: true, matchesFound: matches.length };
        } catch (error) {
            console.error('❌ Error processing new item:', error);
            return { success: false, error: String(error) };
        }
    });

/**
 * Process faces in item images
 */
async function processFacesForItem(itemId: string, item: any): Promise<number> {
    let totalFaces = 0;
    try {
        for (const imageUrl of item.images) {
            const faces = await extractFacesFromImage(imageUrl);
            for (const face of faces) {
                const faceId = `${itemId}_face_${totalFaces}`;
                await db.collection('faces').doc(faceId).set({
                    faceId,
                    itemId,
                    userId: item.userId,
                    imageUrl,
                    boundingBox: face.boundingBox,
                    faceVector: face.faceVector,
                    confidence: face.confidence,
                    createdAt: admin.firestore.Timestamp.now(),
                });
                totalFaces++;
            }
        }
        await db.collection('items').doc(itemId).update({
            hasFaces: totalFaces > 0,
            faceCount: totalFaces,
        });
        console.log(`👤 Extracted ${totalFaces} face(s) from item ${itemId}`);
    } catch (error) {
        console.error(`❌ Error processing faces for item ${itemId}:`, error);
    }
    return totalFaces;
}

async function extractFacesFromImage(imageUrl: string): Promise<any[]> {
    try {
        const [result] = await visionClient.faceDetection(imageUrl);
        const faces = result.faceAnnotations || [];
        return faces.map((face: any, index: number) => {
            const vertices = face.boundingPoly?.vertices || [];
            const x = Math.min(...vertices.map((v: any) => v.x || 0));
            const y = Math.min(...vertices.map((v: any) => v.y || 0));
            const maxX = Math.max(...vertices.map((v: any) => v.x || 0));
            const maxY = Math.max(...vertices.map((v: any) => v.y || 0));

            const landmarks = (face.landmarks || []).map((landmark: any) => ({
                type: landmark.type || '',
                x: landmark.position?.x || 0,
                y: landmark.position?.y || 0,
            }));
            const faceVector = generateFaceVector(landmarks, face);

            return {
                faceIndex: index,
                boundingBox: { x, y, width: maxX - x, height: maxY - y },
                faceVector,
                confidence: face.detectionConfidence || 0,
            };
        });
    } catch (error) {
        return [];
    }
}

function generateFaceVector(landmarks: any[], face: any): number[] {
    const vector: number[] = [];
    const keyLandmarks = ['LEFT_EYE', 'RIGHT_EYE', 'NOSE_TIP', 'MOUTH_CENTER', 'LEFT_EAR_TRAGION', 'RIGHT_EAR_TRAGION', 'CHIN_GNATHION'];
    const landmarkMap = new Map();
    landmarks.forEach((l: any) => landmarkMap.set(l.type, l));
    const leftEye = landmarkMap.get('LEFT_EYE');
    const rightEye = landmarkMap.get('RIGHT_EYE');

    if (leftEye && rightEye) {
        const eyeDistance = Math.sqrt(Math.pow(rightEye.x - leftEye.x, 2) + Math.pow(rightEye.y - leftEye.y, 2));
        const centerX = (leftEye.x + rightEye.x) / 2;
        const centerY = (leftEye.y + rightEye.y) / 2;
        for (const type of keyLandmarks) {
            const landmark = landmarkMap.get(type);
            if (landmark && eyeDistance > 0) {
                vector.push((landmark.x - centerX) / eyeDistance, (landmark.y - centerY) / eyeDistance);
            } else {
                vector.push(0, 0);
            }
        }
    }
    vector.push((face.rollAngle || 0) / 45, (face.panAngle || 0) / 45, (face.tiltAngle || 0) / 45);
    return vector;
}

/**
 * Find potential matches
 */
async function findPotentialMatches(itemId: string, item: any): Promise<any[]> {
    const matches: any[] = [];
    const searchType = item.type === 'lost' ? 'found' : 'lost';

    const potentialMatches = await db
        .collection('items')
        .where('type', '==', searchType)
        .where('category', '==', item.category)
        .where('status', '==', 'active')
        .orderBy('createdAt', 'desc')
        .limit(20) // Limit to 20 most recent relevant items for deep AI analysis
        .get();

    console.log(`🔎 Comparing against ${potentialMatches.docs.length} potential matches`);

    const matchPromises = potentialMatches.docs.map(async (doc) => {
        const potentialMatch = doc.data();
        const scoreBreakdown = await calculateComprehensiveMatchScore(item, potentialMatch);

        if (scoreBreakdown.overallScore > 30) { // Lower threshold to allow AI scores to bubble up
            return {
                userId: item.userId,
                sourceItemId: itemId,
                sourceItemTitle: item.title,
                matchedItemId: doc.id,
                matchedItemTitle: potentialMatch.title,
                matchedItemDescription: potentialMatch.description,
                matchedUserName: potentialMatch.userName || 'Unknown',
                matchedUserId: potentialMatch.userId,
                category: item.category,
                imageUrl: potentialMatch.images?.[0] || null,
                ...scoreBreakdown,
                status: 'pending',
            };
        }
        return null;
    });

    const results = await Promise.all(matchPromises);
    matches.push(...results.filter(r => r !== null));

    matches.sort((a, b) => b.overallScore - a.overallScore);
    return matches.slice(0, 10);
}

/**
 * Calculate comprehensive match score with AI priority
 */
async function calculateComprehensiveMatchScore(item1: any, item2: any): Promise<MatchScoreBreakdown> {
    const matchedBy: string[] = [];
    let aiReasoning = '';

    // 1. Text Similarity (Classic)
    const textScore = calculateTextSimilarity(`${item1.title} ${item1.description || ''}`, `${item2.title} ${item2.description || ''}`);
    if (textScore > 40) matchedBy.push('text');

    // 2. Location
    const locationProximityKm = calculateLocationProximity(item1.location, item2.location);
    const locationScore = Math.max(0, 100 - (locationProximityKm * 2));
    if (locationScore > 60) matchedBy.push('location');

    // 3. Time
    let timeDifferenceHours = 0;
    if (item1.createdAt && item2.createdAt) {
        const d1 = item1.createdAt.toDate ? item1.createdAt.toDate() : new Date(item1.createdAt);
        const d2 = item2.createdAt.toDate ? item2.createdAt.toDate() : new Date(item2.createdAt);
        timeDifferenceHours = Math.abs(d1.getTime() - d2.getTime()) / (1000 * 60 * 60);
    }
    const timeScore = Math.max(0, 100 - (timeDifferenceHours / 24 * 5)); // Decays slower
    if (timeScore > 70) matchedBy.push('time');

    // 4. Image Similarity (Vision API + Basic)
    const hasImages = (item1.images?.length > 0) && (item2.images?.length > 0);
    let imageScore = 0;
    if (hasImages) {
        imageScore = await calculateImageSimilarity(item1.images, item2.images);
        if (imageScore > 50) matchedBy.push('image');
    }

    // 5. Face Matching
    let faceScore = 0;
    const hasFaces = (item1.hasFaces || item1.faceCount > 0) && (item2.hasFaces || item2.faceCount > 0);
    if (hasFaces) {
        faceScore = await calculateFaceSimilarity(item1, item2);
        if (faceScore > 60) matchedBy.push('face');
    }

    // 6. Gemini AI Advanced Analysis (Visual + Semantic)
    let aiScore = 0;

    // Only run expensive/slow AI if there is some potential match signal
    const preliminaryScore = (textScore * 0.4) + (locationScore * 0.3) + (imageScore * 0.3);

    if (preliminaryScore > 40 || locationScore > 90) { // If close textual match OR incredibly close location
        const aiResult = await calculateAdvancedGeminiScore(item1, item2);
        aiScore = aiResult.score;
        aiReasoning = aiResult.reasoning;
        if (aiScore > 65) matchedBy.push('ai-semantic');
    }

    // Weight Calculation
    const textContrib = Math.round(textScore * WEIGHTS.TEXT);
    const locContrib = Math.round(locationScore * WEIGHTS.LOCATION);
    const timeContrib = Math.round(timeScore * WEIGHTS.TIME);

    const imgWeight = hasImages ? WEIGHTS.IMAGE : 0;
    const imgContrib = Math.round(imageScore * imgWeight);

    const faceWeight = hasFaces ? WEIGHTS.FACE : 0;
    const faceContrib = Math.round(faceScore * faceWeight);

    const aiContrib = Math.round(aiScore * WEIGHTS.AI_SEMANTIC);

    const totalWeight = WEIGHTS.TEXT + WEIGHTS.LOCATION + WEIGHTS.TIME + imgWeight + faceWeight + WEIGHTS.AI_SEMANTIC;
    const rawScore = textContrib + locContrib + timeContrib + imgContrib + faceContrib + aiContrib;

    const overallScore = Math.round((rawScore / totalWeight));

    return {
        textScore, locationScore, timeScore, imageScore, faceScore, aiScore,
        textContribution: textContrib, locationContribution: locContrib, timeContribution: timeContrib,
        imageContribution: imgContrib, faceContribution: faceContrib, aiContribution: aiContrib,
        overallScore,
        confidenceLevel: getConfidenceLevel(overallScore),
        matchedBy, hasImages, hasFaces,
        locationProximityKm,
        timeDifferenceHours: Math.round(timeDifferenceHours),
        aiReasoning
    };
}

/**
 * Advanced Gemini Score: Uses 1.5 Flash for multimodal analysis
 */
async function calculateAdvancedGeminiScore(item1: any, item2: any): Promise<{ score: number, reasoning: string }> {
    // Determine model model (use Flash for speed and vision)
    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

    const promptText = `
    You are an expert Detective for a Lost & Found system.
    Analyze these two items and determine if they are the SAME physical object.
    
    Item 1 (${item1.type}): "${item1.title}" - ${item1.description || ''} (Color: ${item1.color || '?'}, Brand: ${item1.brand || '?'})
    Item 2 (${item2.type}): "${item2.title}" - ${item2.description || ''} (Color: ${item2.color || '?'}, Brand: ${item2.brand || '?'})
    
    Task:
    1. Compare visual details (if images provided), brand, model, color, and unique identifiers.
    2. Ignore minor discrepancies in user description (users describe things differently).
    3. Look for "dealbreakers" (e.g., different brand, completely different color).
    
    Output strictly in JSON format:
    {
        "score": <number 0-100 indicating probability they are the exact same item>,
        "reasoning": "<short sentence explaining why>"
    }
    `;

    const parts: any[] = [promptText];

    // Add images if available (up to 1 from each to save bandwidth/tokens)
    if (item1.images?.[0]) {
        const imgPart1 = await urlToGenerativePart(item1.images[0]);
        if (imgPart1) {
            parts.push("Item 1 Image:");
            parts.push(imgPart1);
        }
    }
    if (item2.images?.[0]) {
        const imgPart2 = await urlToGenerativePart(item2.images[0]);
        if (imgPart2) {
            parts.push("Item 2 Image:");
            parts.push(imgPart2);
        }
    }

    try {
        const result = await model.generateContent(parts);
        const responseText = result.response.text();

        // Clean markdown code blocks if present
        const cleanJson = responseText.replace(/```json/g, '').replace(/```/g, '').trim();
        const parsed = JSON.parse(cleanJson);

        return {
            score: typeof parsed.score === 'number' ? parsed.score : 0,
            reasoning: parsed.reasoning || "AI analysis complete."
        };
    } catch (error) {
        console.error("⚠️ Gemini Advanced Analysis Failed:", error);
        return { score: 0, reasoning: "AI analysis unavailable." };
    }
}

// ... (calculateImageSimilarity, calculateFaceSimilarity, calculateCosineSimilarity, calculateTextSimilarity, calculateLocationProximity remain similar)

/**
 * Calculate image similarity (Fallback/Hybrid with Vision API)
 */
async function calculateImageSimilarity(images1: string[], images2: string[]): Promise<number> {
    try {
        const [props1] = await visionClient.imageProperties(images1[0]);
        const [props2] = await visionClient.imageProperties(images2[0]);
        const colors1 = props1.imagePropertiesAnnotation?.dominantColors?.colors || [];
        const colors2 = props2.imagePropertiesAnnotation?.dominantColors?.colors || [];

        if (colors1.length === 0 || colors2.length === 0) return 0;

        let colorSimilarity = 0;
        const maxColors = Math.min(5, colors1.length, colors2.length);
        for (let i = 0; i < maxColors; i++) {
            const c1 = colors1[i].color;
            const c2 = colors2[i].color;
            const diff = (Math.abs((c1.red || 0) - (c2.red || 0)) + Math.abs((c1.green || 0) - (c2.green || 0)) + Math.abs((c1.blue || 0) - (c2.blue || 0)));
            colorSimilarity += (100 - (diff / 765 * 100)) * (colors1[i].pixelFraction || 0.2);
        }

        const [labels1] = await visionClient.labelDetection(images1[0]);
        const [labels2] = await visionClient.labelDetection(images2[0]);
        const set1 = new Set((labels1.labelAnnotations || []).map((l: any) => l.description?.toLowerCase()));
        const set2 = new Set((labels2.labelAnnotations || []).map((l: any) => l.description?.toLowerCase()));

        let labelOverlap = 0;
        set1.forEach(l => { if (set2.has(l)) labelOverlap++; });
        const labelSimilarity = (labelOverlap * 2) / (set1.size + set2.size || 1) * 100;

        return Math.round(colorSimilarity * 0.4 + labelSimilarity * 0.6);
    } catch (e) {
        console.warn("Vision API Error:", e);
        return 0;
    }
}

async function calculateFaceSimilarity(item1: any, item2: any): Promise<number> {
    try {
        const faces1 = (await db.collection('faces').where('itemId', '==', item1.id || '').limit(5).get()).docs.map(d => d.data());
        const faces2 = (await db.collection('faces').where('itemId', '==', item2.id || '').limit(5).get()).docs.map(d => d.data());

        if (faces1.length === 0 || faces2.length === 0) return 0;

        let maxSim = 0;
        for (const f1 of faces1) {
            for (const f2 of faces2) {
                maxSim = Math.max(maxSim, calculateCosineSimilarity(f1.faceVector, f2.faceVector));
            }
        }
        return maxSim;
    } catch (e) { return 0; }
}

function calculateCosineSimilarity(v1: number[], v2: number[]): number {
    if (!v1 || !v2 || v1.length === 0 || v2.length === 0) return 0;
    const len = Math.max(v1.length, v2.length);
    let dot = 0, n1 = 0, n2 = 0;
    for (let i = 0; i < len; i++) {
        const val1 = v1[i] || 0;
        const val2 = v2[i] || 0;
        dot += val1 * val2;
        n1 += val1 * val1;
        n2 += val2 * val2;
    }
    const mag = Math.sqrt(n1) * Math.sqrt(n2);
    return mag === 0 ? 0 : Math.round(((dot / mag) + 1) * 50);
}

function calculateTextSimilarity(text1: string, text2: string): number {
    if (!text1 || !text2) return 0;
    const w1 = text1.toLowerCase().split(/\s+/).filter(w => w.length > 2);
    const w2 = text2.toLowerCase().split(/\s+/).filter(w => w.length > 2);
    const s1 = new Set(w1);
    const s2 = new Set(w2);
    let common = 0;
    s1.forEach(w => { if (s2.has(w)) common++; });
    return Math.round((common * 2) / (s1.size + s2.size || 1) * 100);
}

function calculateLocationProximity(l1: any, l2: any): number {
    if (!l1 || !l2) return 50;
    const R = 6371;
    const dLat = (l2.latitude - l1.latitude) * Math.PI / 180;
    const dLon = (l2.longitude - l1.longitude) * Math.PI / 180;
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(l1.latitude * Math.PI / 180) * Math.cos(l2.latitude * Math.PI / 180) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return Math.round(R * c * 100) / 100;
}

function getConfidenceLevel(score: number): string {
    if (score >= 85) return 'Very High';
    if (score >= 70) return 'High';
    if (score >= 50) return 'Medium';
    if (score >= 30) return 'Low';
    return 'Very Low';
}

async function sendMatchNotificationToUser(match: any): Promise<void> {
    try {
        const userDoc = await db.collection('users').doc(match.userId).get();
        const user = userDoc.data();
        if (!user || !user.fcmToken) return;

        await admin.messaging().send({
            token: user.fcmToken,
            notification: {
                title: `🎉 ${match.overallScore}% Match Found!`,
                body: match.aiReasoning || `"${match.matchedItemTitle}" matches your item.`
            },
            data: {
                type: 'match',
                matchedItemId: match.matchedItemId,
                score: String(match.overallScore)
            }
        });

        await db.collection('notifications').add({
            userId: match.userId,
            title: `🎉 ${match.overallScore}% Match Found!`,
            body: match.aiReasoning || `Item match found.`,
            type: 'match',
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            data: { ...match }
        });
    } catch (e) { console.error(e); }
}

