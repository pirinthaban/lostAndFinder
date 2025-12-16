import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as vision from '@google-cloud/vision';
import sharp from 'sharp';

const visionClient = new vision.ImageAnnotatorClient();

/**
 * Process uploaded images
 * - Detect and blur sensitive information
 * - Generate thumbnails
 * - Extract features for AI matching
 */
export const processImageUpload = functions.storage
  .object()
  .onFinalize(async (object) => {
    const filePath = object.name;
    
    if (!filePath) return null;

    // Only process images in item_images folder
    if (!filePath.startsWith('item_images/')) {
      console.log('Not an item image, skipping');
      return null;
    }

    const bucket = admin.storage().bucket(object.bucket);
    const fileName = filePath.split('/').pop();
    const tempFilePath = `/tmp/${fileName}`;

    try {
      // Download image
      await bucket.file(filePath).download({ destination: tempFilePath });
      console.log(`Downloaded image: ${fileName}`);

      // Detect sensitive information
      const [result] = await visionClient.textDetection(tempFilePath);
      const detections = result.textAnnotations || [];

      let needsBlurring = false;
      const blurRegions: Array<{ x: number; y: number; width: number; height: number }> = [];

      // Check for NIC numbers (format: 123456789V or 123456789012)
      for (const detection of detections) {
        const text = detection.description || '';
        const nicPattern = /\d{9}[VXvx]|\d{12}/;

        if (nicPattern.test(text) && detection.boundingPoly?.vertices) {
          needsBlurring = true;
          const vertices = detection.boundingPoly.vertices;
          
          // Calculate bounding box
          const x = Math.min(...vertices.map((v) => v.x || 0));
          const y = Math.min(...vertices.map((v) => v.y || 0));
          const width = Math.max(...vertices.map((v) => v.x || 0)) - x;
          const height = Math.max(...vertices.map((v) => v.y || 0)) - y;

          blurRegions.push({ x, y, width, height });
        }
      }

      // Detect faces
      const [faceResult] = await visionClient.faceDetection(tempFilePath);
      const faces = faceResult.faceAnnotations || [];

      if (faces.length > 0) {
        needsBlurring = true;
        
        for (const face of faces) {
          if (face.boundingPoly?.vertices) {
            const vertices = face.boundingPoly.vertices;
            const x = Math.min(...vertices.map((v) => v.x || 0));
            const y = Math.min(...vertices.map((v) => v.y || 0));
            const width = Math.max(...vertices.map((v) => v.x || 0)) - x;
            const height = Math.max(...vertices.map((v) => v.y || 0)) - y;

            blurRegions.push({ x, y, width, height });
          }
        }
      }

      // Apply blurring if needed
      if (needsBlurring) {
        const blurredFilePath = filePath.replace('item_images/', 'item_images_blurred/');
        const blurredTempPath = `/tmp/blurred_${fileName}`;

        // Load image
        let image = sharp(tempFilePath);

        // Blur each detected region
        for (const region of blurRegions) {
          image = image.composite([
            {
              input: await sharp(tempFilePath)
                .extract({
                  left: region.x,
                  top: region.y,
                  width: region.width,
                  height: region.height,
                })
                .blur(50)
                .toBuffer(),
              top: region.y,
              left: region.x,
            },
          ]);
        }

        await image.toFile(blurredTempPath);

        // Upload blurred image
        await bucket.upload(blurredTempPath, {
          destination: blurredFilePath,
          metadata: {
            contentType: object.contentType,
          },
        });

        console.log(`Blurred image uploaded: ${blurredFilePath}`);
      }

      // Generate thumbnail
      const thumbnailPath = filePath.replace('item_images/', 'item_thumbnails/');
      const thumbnailTempPath = `/tmp/thumb_${fileName}`;

      await sharp(tempFilePath)
        .resize(300, 300, { fit: 'cover' })
        .toFile(thumbnailTempPath);

      await bucket.upload(thumbnailTempPath, {
        destination: thumbnailPath,
        metadata: {
          contentType: object.contentType,
        },
      });

      console.log(`Thumbnail created: ${thumbnailPath}`);

      // Extract image features for AI matching (placeholder)
      // In production, use TensorFlow to extract image embeddings
      const features = {
        hasText: detections.length > 0,
        hasFaces: faces.length > 0,
        colors: await extractDominantColors(tempFilePath),
        // Add image embedding here
      };

      // Update item document with processed image info
      const itemId = filePath.split('/')[2]; // item_images/{userId}/{itemId}/{imageId}
      const db = admin.firestore();
      
      const itemsSnapshot = await db
        .collection('items')
        .where('images', 'array-contains', filePath)
        .limit(1)
        .get();

      if (!itemsSnapshot.empty) {
        const itemDoc = itemsSnapshot.docs[0];
        await itemDoc.ref.update({
          features,
          blurredImages: admin.firestore.FieldValue.arrayUnion(
            needsBlurring ? blurredFilePath : filePath
          ),
        });
      }

      return { success: true, needsBlurring, thumbnailCreated: true };
    } catch (error) {
      console.error('Error processing image:', error);
      return { success: false, error: String(error) };
    }
  });

/**
 * Extract dominant colors from image
 */
async function extractDominantColors(imagePath: string): Promise<string[]> {
  try {
    const image = sharp(imagePath);
    const { dominant } = await image.stats();
    
    return [
      `rgb(${dominant.r}, ${dominant.g}, ${dominant.b})`,
    ];
  } catch (error) {
    console.error('Error extracting colors:', error);
    return [];
  }
}
