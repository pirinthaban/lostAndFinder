"use strict";
/**
 * Face Recognition Service for FindBack
 *
 * This module provides face detection, embedding extraction, and matching capabilities
 * for searching items based on faces in uploaded photos.
 *
 * Features:
 * - Face detection using Google Cloud Vision API
 * - Face embedding extraction for comparison
 * - Face similarity scoring using cosine similarity
 * - Search items by face
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
exports.testFaceDetection = exports.deleteFaceData = exports.searchByFace = exports.processFaceData = void 0;
exports.extractFacesFromImage = extractFacesFromImage;
exports.calculateFaceSimilarity = calculateFaceSimilarity;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const crypto = __importStar(require("crypto"));
// Google Cloud Vision client - use dynamic import for better compatibility
const vision = require('@google-cloud/vision');
const visionClient = new vision.ImageAnnotatorClient();
// Firestore reference
const db = admin.firestore();
// ============================================
// FACE DETECTION & EXTRACTION
// ============================================
/**
 * Extract face data from an image URL
 * Returns array of detected faces with their features
 */
async function extractFacesFromImage(imageUrl) {
    try {
        const [result] = await visionClient.faceDetection(imageUrl);
        const faces = result.faceAnnotations || [];
        console.log(`🔍 Detected ${faces.length} face(s) in image`);
        return faces.map((face, index) => {
            var _a;
            const vertices = ((_a = face.boundingPoly) === null || _a === void 0 ? void 0 : _a.vertices) || [];
            const x = Math.min(...vertices.map((v) => v.x || 0));
            const y = Math.min(...vertices.map((v) => v.y || 0));
            const maxX = Math.max(...vertices.map((v) => v.x || 0));
            const maxY = Math.max(...vertices.map((v) => v.y || 0));
            // Extract landmarks for face vector generation
            const landmarks = (face.landmarks || []).map((landmark) => {
                var _a, _b;
                return ({
                    type: landmark.type || '',
                    x: ((_a = landmark.position) === null || _a === void 0 ? void 0 : _a.x) || 0,
                    y: ((_b = landmark.position) === null || _b === void 0 ? void 0 : _b.y) || 0,
                });
            });
            // Generate a simplified face vector from landmarks
            const faceVector = generateFaceVector(landmarks, face);
            return {
                faceIndex: index,
                boundingBox: {
                    x,
                    y,
                    width: maxX - x,
                    height: maxY - y,
                },
                landmarks,
                emotions: {
                    joy: face.joyLikelihood || 'UNKNOWN',
                    sorrow: face.sorrowLikelihood || 'UNKNOWN',
                    anger: face.angerLikelihood || 'UNKNOWN',
                    surprise: face.surpriseLikelihood || 'UNKNOWN',
                },
                angles: {
                    roll: face.rollAngle || 0,
                    pan: face.panAngle || 0,
                    tilt: face.tiltAngle || 0,
                },
                confidence: face.detectionConfidence || 0,
                faceVector,
            };
        });
    }
    catch (error) {
        console.error('❌ Error detecting faces:', error);
        return [];
    }
}
/**
 * Generate a simplified face vector from landmarks
 * This creates a numerical representation of the face for comparison
 */
function generateFaceVector(landmarks, face) {
    const vector = [];
    // Key landmarks for face recognition
    const keyLandmarks = [
        'LEFT_EYE', 'RIGHT_EYE',
        'LEFT_OF_LEFT_EYEBROW', 'RIGHT_OF_LEFT_EYEBROW',
        'LEFT_OF_RIGHT_EYEBROW', 'RIGHT_OF_RIGHT_EYEBROW',
        'MIDPOINT_BETWEEN_EYES',
        'NOSE_TIP', 'NOSE_BOTTOM_RIGHT', 'NOSE_BOTTOM_LEFT', 'NOSE_BOTTOM_CENTER',
        'UPPER_LIP', 'LOWER_LIP',
        'MOUTH_LEFT', 'MOUTH_RIGHT', 'MOUTH_CENTER',
        'LEFT_EYE_LEFT_CORNER', 'LEFT_EYE_RIGHT_CORNER',
        'RIGHT_EYE_LEFT_CORNER', 'RIGHT_EYE_RIGHT_CORNER',
        'LEFT_EYEBROW_UPPER_MIDPOINT', 'RIGHT_EYEBROW_UPPER_MIDPOINT',
        'LEFT_EAR_TRAGION', 'RIGHT_EAR_TRAGION',
        'CHIN_GNATHION', 'CHIN_LEFT_GONION', 'CHIN_RIGHT_GONION',
        'FOREHEAD_GLABELLA',
    ];
    // Create a map of landmarks for quick lookup
    const landmarkMap = new Map();
    landmarks.forEach(l => landmarkMap.set(l.type, l));
    // Find reference points for normalization
    const leftEye = landmarkMap.get('LEFT_EYE');
    const rightEye = landmarkMap.get('RIGHT_EYE');
    if (!leftEye || !rightEye) {
        // If we can't normalize, use raw landmark positions
        for (const landmark of landmarks) {
            vector.push(landmark.x, landmark.y);
        }
        return vector;
    }
    // Calculate eye distance for normalization
    const eyeDistance = Math.sqrt(Math.pow(rightEye.x - leftEye.x, 2) +
        Math.pow(rightEye.y - leftEye.y, 2));
    // Center point between eyes
    const centerX = (leftEye.x + rightEye.x) / 2;
    const centerY = (leftEye.y + rightEye.y) / 2;
    // Extract normalized relative positions
    for (const landmarkType of keyLandmarks) {
        const landmark = landmarkMap.get(landmarkType);
        if (landmark && eyeDistance > 0) {
            // Normalize relative to eye center and eye distance
            vector.push((landmark.x - centerX) / eyeDistance, (landmark.y - centerY) / eyeDistance);
        }
        else {
            vector.push(0, 0);
        }
    }
    // Add face angles for additional discrimination
    vector.push((face.rollAngle || 0) / 45, // Normalize to [-1, 1] range approximately
    (face.panAngle || 0) / 45, (face.tiltAngle || 0) / 45);
    return vector;
}
/**
 * Calculate cosine similarity between two face vectors
 */
function calculateFaceSimilarity(vector1, vector2) {
    if (vector1.length === 0 || vector2.length === 0)
        return 0;
    if (vector1.length !== vector2.length) {
        // Pad shorter vector with zeros
        const maxLen = Math.max(vector1.length, vector2.length);
        while (vector1.length < maxLen)
            vector1.push(0);
        while (vector2.length < maxLen)
            vector2.push(0);
    }
    let dotProduct = 0;
    let norm1 = 0;
    let norm2 = 0;
    for (let i = 0; i < vector1.length; i++) {
        dotProduct += vector1[i] * vector2[i];
        norm1 += vector1[i] * vector1[i];
        norm2 += vector2[i] * vector2[i];
    }
    const magnitude = Math.sqrt(norm1) * Math.sqrt(norm2);
    if (magnitude === 0)
        return 0;
    const similarity = dotProduct / magnitude;
    // Convert to percentage (0-100)
    return Math.round((similarity + 1) * 50); // Maps [-1, 1] to [0, 100]
}
// ============================================
// CLOUD FUNCTIONS
// ============================================
/**
 * Process uploaded image and extract face data
 * Triggered when an item is created
 */
exports.processFaceData = functions.firestore
    .document('items/{itemId}')
    .onCreate(async (snapshot, context) => {
    const item = snapshot.data();
    const itemId = context.params.itemId;
    if (!item.images || item.images.length === 0) {
        console.log(`📷 No images in item ${itemId}`);
        return { success: false, reason: 'No images' };
    }
    console.log(`🔍 Processing faces for item ${itemId}`);
    const allFaces = [];
    for (const imageUrl of item.images) {
        const faces = await extractFacesFromImage(imageUrl);
        for (const face of faces) {
            const faceId = crypto.randomUUID();
            const faceData = {
                faceId,
                itemId,
                userId: item.userId,
                imageUrl,
                boundingBox: face.boundingBox,
                landmarks: face.landmarks,
                emotions: face.emotions,
                angles: face.angles,
                confidence: face.confidence,
                faceVector: face.faceVector,
                createdAt: admin.firestore.Timestamp.now(),
            };
            allFaces.push(faceData);
            // Store face data in Firestore
            await db.collection('faces').doc(faceId).set(faceData);
        }
    }
    // Update item with face count
    await snapshot.ref.update({
        faceCount: allFaces.length,
        hasFaces: allFaces.length > 0,
    });
    console.log(`✅ Extracted ${allFaces.length} face(s) from item ${itemId}`);
    return { success: true, facesExtracted: allFaces.length };
});
/**
 * Search for items containing similar faces
 * HTTP callable function
 */
exports.searchByFace = functions.https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'You must be logged in to search by face');
    }
    const { imageUrl, threshold = 60, limit = 20, category, district } = data;
    if (!imageUrl) {
        throw new functions.https.HttpsError('invalid-argument', 'Image URL is required');
    }
    console.log(`🔍 Face search initiated by user ${context.auth.uid}`);
    try {
        // Extract faces from the search image
        const searchFaces = await extractFacesFromImage(imageUrl);
        if (searchFaces.length === 0) {
            return {
                success: false,
                message: 'No faces detected in the uploaded image',
                results: [],
            };
        }
        // Get the first face for searching (primary face)
        const searchFace = searchFaces[0];
        const searchVector = searchFace.faceVector;
        console.log(`🔍 Searching for matches using face vector of length ${searchVector.length}`);
        // Query all faces from the database
        let facesQuery = db.collection('faces');
        // Apply filters if provided
        if (category || district) {
            // We need to query items first, then filter faces
            const itemsSnapshot = await db.collection('items')
                .where('status', '==', 'active')
                .where('hasFaces', '==', true)
                .get();
            const itemIds = itemsSnapshot.docs
                .filter(doc => {
                const item = doc.data();
                if (category && item.category !== category)
                    return false;
                if (district && item.district !== district)
                    return false;
                return true;
            })
                .map(doc => doc.id);
            if (itemIds.length === 0) {
                return {
                    success: true,
                    message: 'No items with faces found matching your criteria',
                    results: [],
                };
            }
            // Firestore 'in' queries are limited to 10 items at a time
            const matchingFaces = [];
            const chunks = chunkArray(itemIds, 10);
            for (const chunk of chunks) {
                const facesSnapshot = await db.collection('faces')
                    .where('itemId', 'in', chunk)
                    .get();
                for (const faceDoc of facesSnapshot.docs) {
                    const faceData = faceDoc.data();
                    const similarity = calculateFaceSimilarity(searchVector, faceData.faceVector);
                    if (similarity >= threshold) {
                        const itemDoc = await db.collection('items').doc(faceData.itemId).get();
                        matchingFaces.push({
                            itemId: faceData.itemId,
                            item: itemDoc.data(),
                            faceData,
                            similarity,
                            matchConfidence: getMatchConfidence(similarity),
                        });
                    }
                }
            }
            // Sort by similarity and limit results
            matchingFaces.sort((a, b) => b.similarity - a.similarity);
            const results = matchingFaces.slice(0, limit);
            return {
                success: true,
                message: `Found ${results.length} matching item(s)`,
                results,
                searchFaceDetected: true,
            };
        }
        else {
            // Search all faces
            const facesSnapshot = await facesQuery.limit(500).get();
            const matchingFaces = [];
            for (const faceDoc of facesSnapshot.docs) {
                const faceData = faceDoc.data();
                const similarity = calculateFaceSimilarity(searchVector, faceData.faceVector);
                if (similarity >= threshold) {
                    const itemDoc = await db.collection('items').doc(faceData.itemId).get();
                    if (itemDoc.exists) {
                        matchingFaces.push({
                            itemId: faceData.itemId,
                            item: itemDoc.data(),
                            faceData,
                            similarity,
                            matchConfidence: getMatchConfidence(similarity),
                        });
                    }
                }
            }
            // Sort by similarity and limit results
            matchingFaces.sort((a, b) => b.similarity - a.similarity);
            const results = matchingFaces.slice(0, limit);
            console.log(`✅ Found ${results.length} face matches above ${threshold}% threshold`);
            return {
                success: true,
                message: `Found ${results.length} matching item(s)`,
                results,
                searchFaceDetected: true,
            };
        }
    }
    catch (error) {
        console.error('❌ Face search error:', error);
        throw new functions.https.HttpsError('internal', 'Error searching by face: ' + String(error));
    }
});
/**
 * Get match confidence label based on similarity score
 */
function getMatchConfidence(similarity) {
    if (similarity >= 90)
        return 'Very High';
    if (similarity >= 75)
        return 'High';
    if (similarity >= 60)
        return 'Medium';
    if (similarity >= 45)
        return 'Low';
    return 'Very Low';
}
/**
 * Split array into chunks
 */
function chunkArray(array, chunkSize) {
    const chunks = [];
    for (let i = 0; i < array.length; i += chunkSize) {
        chunks.push(array.slice(i, i + chunkSize));
    }
    return chunks;
}
/**
 * Delete face data when an item is deleted
 */
exports.deleteFaceData = functions.firestore
    .document('items/{itemId}')
    .onDelete(async (snapshot, context) => {
    const itemId = context.params.itemId;
    console.log(`🗑️ Deleting face data for item ${itemId}`);
    const facesSnapshot = await db.collection('faces')
        .where('itemId', '==', itemId)
        .get();
    const batch = db.batch();
    facesSnapshot.docs.forEach(doc => {
        batch.delete(doc.ref);
    });
    await batch.commit();
    console.log(`✅ Deleted ${facesSnapshot.size} face records for item ${itemId}`);
    return { success: true, deletedFaces: facesSnapshot.size };
});
/**
 * HTTP endpoint to test face detection
 */
exports.testFaceDetection = functions.https.onRequest(async (req, res) => {
    const imageUrl = req.query.imageUrl;
    if (!imageUrl) {
        res.status(400).json({ error: 'imageUrl query parameter is required' });
        return;
    }
    try {
        const faces = await extractFacesFromImage(imageUrl);
        res.json({
            success: true,
            facesDetected: faces.length,
            faces: faces.map(f => ({
                boundingBox: f.boundingBox,
                emotions: f.emotions,
                angles: f.angles,
                confidence: f.confidence,
                vectorLength: f.faceVector.length,
            })),
        });
    }
    catch (error) {
        res.status(500).json({ error: String(error) });
    }
});
//# sourceMappingURL=faceRecognition.js.map