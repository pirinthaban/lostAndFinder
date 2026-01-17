import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();
const storage = admin.storage();

/**
 * Process uploaded images for items
 * - Generates thumbnails
 * - Extracts image metadata
 * - Auto-detects sensitive content (NIC numbers, faces)
 * - Applies blur to sensitive information
 */
export const processImageUpload = functions.storage
  .object()
  .onFinalize(async (object) => {
    const filePath = object.name;
    const contentType = object.contentType;

    // Only process images
    if (!contentType?.startsWith('image/')) {
      console.log('Not an image, skipping processing');
      return null;
    }

    // Only process item images
    if (!filePath?.includes('item_images/')) {
      console.log('Not an item image, skipping');
      return null;
    }

    console.log(`Processing image: ${filePath}`);

    try {
      const bucket = storage.bucket(object.bucket);
      const file = bucket.file(filePath!);
      
      // Get file metadata
      const [metadata] = await file.getMetadata();
      
      // Extract item ID from path (format: item_images/userId/itemId/imageId)
      const pathParts = filePath!.split('/');
      if (pathParts.length < 4) {
        console.log('Invalid path format');
        return null;
      }
      
      const userId = pathParts[1];
      const itemId = pathParts[2];
      
      console.log(`Processing image for user: ${userId}, item: ${itemId}`);

      // Update item with image processing status
      await db.collection('items').doc(itemId).update({
        imageProcessed: true,
        imageProcessedAt: admin.firestore.FieldValue.serverTimestamp(),
        imageMetadata: {
          size: metadata.size,
          contentType: contentType,
          created: metadata.timeCreated,
        },
      });

      // TODO: Add TensorFlow-based image analysis
      // - Face detection for privacy blurring
      // - NIC/ID card detection
      // - Image embedding generation for similarity matching

      console.log(`Successfully processed image for item: ${itemId}`);
      return null;
    } catch (error) {
      console.error('Error processing image:', error);
      return null;
    }
  });

/**
 * Generate image embeddings for AI matching
 * This is a placeholder for TensorFlow integration
 */
export async function generateImageEmbedding(imageUrl: string): Promise<number[]> {
  // TODO: Implement with TensorFlow.js or Cloud Vision API
  // For now, return a placeholder embedding
  console.log(`Generating embedding for: ${imageUrl}`);
  
  // Placeholder: Return random normalized vector
  const embedding: number[] = [];
  for (let i = 0; i < 128; i++) {
    embedding.push(Math.random() * 2 - 1);
  }
  
  // Normalize
  const magnitude = Math.sqrt(embedding.reduce((sum, val) => sum + val * val, 0));
  return embedding.map(val => val / magnitude);
}

/**
 * Detect sensitive content in images
 * Returns regions that should be blurred
 */
export async function detectSensitiveContent(imageUrl: string): Promise<{
  hasFaces: boolean;
  hasNIC: boolean;
  blurRegions: Array<{ x: number; y: number; width: number; height: number }>;
}> {
  // TODO: Implement with ML Kit or Cloud Vision API
  console.log(`Detecting sensitive content in: ${imageUrl}`);
  
  return {
    hasFaces: false,
    hasNIC: false,
    blurRegions: [],
  };
}
