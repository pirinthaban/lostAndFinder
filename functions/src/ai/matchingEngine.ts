import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();

/**
 * 🤖 Enhanced AI Matching Engine for Lost & Found Items
 * 
 * Calculates match scores between items using:
 * - Text similarity with synonyms & fuzzy matching
 * - Location proximity (Haversine formula)
 * - Time difference scoring
 * - Category matching with grouping
 * - Color matching
 * - Brand detection
 * - NIC/Document matching
 * - Image similarity (with embeddings when available)
 */

interface MatchScore {
  overallScore: number;
  textScore: number;
  locationScore: number;
  timeScore: number;
  categoryScore: number;
  imageScore: number;
  colorMatch: boolean;
  brandMatch: boolean;
  nicMatch: boolean;
  confidence: string;
}

// Synonym groups for better matching
const SYNONYMS: { [key: string]: string[] } = {
  phone: ['mobile', 'smartphone', 'cellphone', 'cellular', 'handphone', 'cell', 'iphone', 'android'],
  laptop: ['computer', 'notebook', 'macbook', 'pc', 'chromebook', 'netbook'],
  bag: ['backpack', 'handbag', 'purse', 'suitcase', 'briefcase', 'rucksack', 'tote', 'luggage'],
  wallet: ['purse', 'moneybag', 'cardholder', 'billfold', 'pocketbook'],
  keys: ['keychain', 'fob', 'smartkey', 'car key', 'house key', 'keyring'],
  glasses: ['spectacles', 'sunglasses', 'shades', 'eyeglasses', 'specs', 'eyewear'],
  watch: ['smartwatch', 'clock', 'timepiece', 'wristwatch', 'apple watch'],
  document: ['id', 'nic', 'passport', 'license', 'certificate', 'card', 'paper'],
  camera: ['dslr', 'mirrorless', 'gopro', 'camcorder'],
  headphones: ['earphones', 'earbuds', 'airpods', 'headset', 'earpods'],
  tablet: ['ipad', 'tab', 'kindle', 'e-reader'],
  jewelry: ['ring', 'necklace', 'bracelet', 'earring', 'chain', 'pendant', 'jewellery'],
  charger: ['adapter', 'cable', 'power bank', 'charging'],
};

// Color variants for matching
const COLOR_VARIANTS: { [key: string]: string[] } = {
  red: ['red', 'maroon', 'crimson', 'scarlet', 'ruby', 'cherry'],
  blue: ['blue', 'navy', 'azure', 'cobalt', 'sapphire', 'cyan', 'turquoise'],
  green: ['green', 'olive', 'lime', 'emerald', 'jade', 'mint', 'teal'],
  black: ['black', 'charcoal', 'ebony', 'onyx', 'jet'],
  white: ['white', 'ivory', 'cream', 'pearl', 'snow'],
  yellow: ['yellow', 'gold', 'golden', 'amber', 'mustard', 'lemon'],
  orange: ['orange', 'tangerine', 'peach', 'apricot', 'coral'],
  purple: ['purple', 'violet', 'lavender', 'plum', 'magenta', 'lilac'],
  pink: ['pink', 'rose', 'salmon', 'fuchsia', 'blush'],
  grey: ['grey', 'gray', 'silver', 'ash', 'slate', 'charcoal'],
  brown: ['brown', 'tan', 'beige', 'chocolate', 'coffee', 'caramel'],
};

// Known brands for matching
const KNOWN_BRANDS = new Set([
  // Phones
  'iphone', 'samsung', 'huawei', 'xiaomi', 'oppo', 'vivo', 'realme', 'oneplus', 'google', 'pixel', 'nokia',
  // Laptops
  'macbook', 'dell', 'hp', 'lenovo', 'asus', 'acer', 'msi', 'surface',
  // Bags
  'nike', 'adidas', 'puma', 'jansport', 'samsonite', 'american tourister',
  // Watches
  'rolex', 'casio', 'seiko', 'citizen', 'tissot', 'omega', 'fitbit', 'garmin',
  // Banks (Sri Lanka)
  'commercial bank', 'peoples bank', 'boc', 'hsbc', 'sampath', 'hnb', 'ndb',
]);

// Stop words to filter out
const STOP_WORDS = new Set([
  'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
  'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
  'should', 'may', 'might', 'must', 'shall', 'can', 'need', 'to', 'of',
  'in', 'for', 'on', 'with', 'at', 'by', 'from', 'as', 'into', 'through',
  'during', 'before', 'after', 'above', 'below', 'between', 'under',
  'lost', 'found', 'missing', 'please', 'help', 'contact', 'call', 'reward',
  'i', 'my', 'me', 'we', 'our', 'you', 'your', 'he', 'him', 'his', 'she',
  'her', 'it', 'its', 'they', 'them', 'their', 'this', 'that', 'these',
]);

/**
 * Calculate match score between two items
 * Callable function for on-demand matching
 */
export const calculateMatchScore = functions.https.onCall(
  async (data, context) => {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to calculate matches'
      );
    }

    const { item1Id, item2Id } = data;

    if (!item1Id || !item2Id) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Both item1Id and item2Id are required'
      );
    }

    try {
      // Fetch both items
      const [item1Doc, item2Doc] = await Promise.all([
        db.collection('items').doc(item1Id).get(),
        db.collection('items').doc(item2Id).get(),
      ]);

      if (!item1Doc.exists || !item2Doc.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'One or both items not found'
        );
      }

      const item1 = item1Doc.data()!;
      const item2 = item2Doc.data()!;

      // Calculate match score
      const score = calculateScore(item1, item2);

      return {
        success: true,
        item1Id,
        item2Id,
        ...score,
      };
    } catch (error) {
      console.error('Error calculating match:', error);
      throw new functions.https.HttpsError(
        'internal',
        'Error calculating match score'
      );
    }
  }
);

/**
 * Calculate comprehensive match score between two items
 */
function calculateScore(item1: any, item2: any): MatchScore {
  // Ensure items are opposite types (lost vs found)
  if (item1.status === item2.status) {
    return emptyScore();
  }

  // Calculate individual scores
  const textScore = calculateTextSimilarity(item1, item2);
  const locationScore = calculateLocationProximity(item1, item2);
  const timeScore = calculateTimeDifference(item1, item2);
  const categoryScore = calculateCategoryMatch(item1, item2);
  const imageScore = calculateImageSimilarity(item1, item2);
  
  // Bonus calculations
  const colorMatch = checkColorMatch(item1, item2);
  const brandMatch = checkBrandMatch(item1, item2);
  const nicMatch = checkNICMatch(item1, item2);

  // Weighted average (matching Dart client weights)
  const weights = {
    text: 0.40,
    location: 0.25,
    time: 0.15,
    category: 0.10,
    image: 0.10,
  };

  let overallScore =
    textScore * weights.text +
    locationScore * weights.location +
    timeScore * weights.time +
    categoryScore * weights.category +
    imageScore * weights.image;
  
  // Apply bonuses
  if (colorMatch) overallScore += 10;
  if (brandMatch) overallScore += 15;
  if (nicMatch) overallScore += 30; // Big bonus for NIC match
  
  overallScore = Math.min(100, Math.max(0, overallScore));

  // Determine confidence level
  let confidence: string;
  if (overallScore >= 80) {
    confidence = 'High';
  } else if (overallScore >= 60) {
    confidence = 'Medium';
  } else if (overallScore >= 40) {
    confidence = 'Low';
  } else {
    confidence = 'Very Low';
  }

  return {
    overallScore: Math.round(overallScore * 100) / 100,
    textScore: Math.round(textScore * 100) / 100,
    locationScore: Math.round(locationScore * 100) / 100,
    timeScore: Math.round(timeScore * 100) / 100,
    categoryScore: Math.round(categoryScore * 100) / 100,
    imageScore: Math.round(imageScore * 100) / 100,
    colorMatch,
    brandMatch,
    nicMatch,
    confidence,
  };
}

function emptyScore(): MatchScore {
  return {
    overallScore: 0,
    textScore: 0,
    locationScore: 0,
    timeScore: 0,
    categoryScore: 0,
    imageScore: 0,
    colorMatch: false,
    brandMatch: false,
    nicMatch: false,
    confidence: 'none',
  };
}

/**
 * Check if two words are synonyms
 */
function areSynonyms(word1: string, word2: string): boolean {
  word1 = word1.toLowerCase();
  word2 = word2.toLowerCase();
  if (word1 === word2) return true;
  
  for (const synonyms of Object.values(SYNONYMS)) {
    if (synonyms.includes(word1) && synonyms.includes(word2)) {
      return true;
    }
  }
  return false;
}

/**
 * Calculate Levenshtein distance for fuzzy matching
 */
function levenshteinDistance(s: string, t: string): number {
  if (s === t) return 0;
  if (s.length === 0) return t.length;
  if (t.length === 0) return s.length;

  const matrix: number[][] = [];
  for (let i = 0; i <= s.length; i++) {
    matrix[i] = [i];
  }
  for (let j = 0; j <= t.length; j++) {
    matrix[0][j] = j;
  }

  for (let i = 1; i <= s.length; i++) {
    for (let j = 1; j <= t.length; j++) {
      const cost = s[i - 1] === t[j - 1] ? 0 : 1;
      matrix[i][j] = Math.min(
        matrix[i - 1][j] + 1,
        matrix[i][j - 1] + 1,
        matrix[i - 1][j - 1] + cost
      );
    }
  }

  return matrix[s.length][t.length];
}

/**
 * Calculate text similarity using enhanced matching
 */
function calculateTextSimilarity(item1: any, item2: any): number {
  const text1 = `${item1.title || ''} ${item1.description || ''} ${item1.extractedText || ''}`.toLowerCase();
  const text2 = `${item2.title || ''} ${item2.description || ''} ${item2.extractedText || ''}`.toLowerCase();

  // Tokenize and filter stop words
  const words1 = new Set(
    text1.split(/\s+/)
      .filter((w: string) => w.length > 2 && !STOP_WORDS.has(w))
  );
  const words2 = new Set(
    text2.split(/\s+/)
      .filter((w: string) => w.length > 2 && !STOP_WORDS.has(w))
  );

  if (words1.size === 0 || words2.size === 0) return 0;

  // Enhanced matching with synonyms and fuzzy matching
  let matchCount = 0;
  for (const w1 of words1) {
    for (const w2 of words2) {
      // Exact match
      if (w1 === w2) {
        matchCount++;
        break;
      }
      // Synonym match
      if (areSynonyms(w1, w2)) {
        matchCount++;
        break;
      }
      // Fuzzy match (Levenshtein <= 2 for words > 4 chars)
      if (w1.length > 4 && w2.length > 4 && levenshteinDistance(w1, w2) <= 2) {
        matchCount++;
        break;
      }
    }
  }

  // Jaccard-style similarity
  const similarity = matchCount / (words1.size + words2.size - matchCount);
  return similarity * 100;
}

/**
 * Calculate location proximity score
 */
function calculateLocationProximity(item1: any, item2: any): number {
  // Check if both have coordinates
  if (!item1.latitude || !item1.longitude || !item2.latitude || !item2.longitude) {
    // Fall back to district matching
    if (item1.district && item2.district) {
      return item1.district.toLowerCase() === item2.district.toLowerCase() ? 70 : 20;
    }
    return 0;
  }

  // Calculate distance using Haversine formula
  const distance = haversineDistance(
    item1.latitude,
    item1.longitude,
    item2.latitude,
    item2.longitude
  );

  // Score based on distance (km)
  if (distance < 0.5) return 100; // Within 500m
  if (distance < 1) return 95;
  if (distance < 2) return 90;
  if (distance < 5) return 80;
  if (distance < 10) return 60;
  if (distance < 20) return 40;
  if (distance < 50) return 20;
  return 5;
}

/**
 * Calculate Haversine distance between two coordinates
 */
function haversineDistance(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371; // Earth's radius in km
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRad(deg: number): number {
  return deg * (Math.PI / 180);
}

/**
 * Calculate time difference score
 */
function calculateTimeDifference(item1: any, item2: any): number {
  const date1 = item1.createdAt?.toDate?.() || new Date(item1.createdAt);
  const date2 = item2.createdAt?.toDate?.() || new Date(item2.createdAt);

  if (!date1 || !date2) return 50;

  const diffHours = Math.abs(date1.getTime() - date2.getTime()) / (1000 * 60 * 60);

  // Score based on time difference
  if (diffHours < 24) return 100; // Same day
  if (diffHours < 48) return 90; // Within 2 days
  if (diffHours < 72) return 80; // Within 3 days
  if (diffHours < 168) return 60; // Within a week
  if (diffHours < 336) return 40; // Within 2 weeks
  if (diffHours < 720) return 20; // Within a month
  return 5;
}

/**
 * Calculate category match score with grouping
 */
function calculateCategoryMatch(item1: any, item2: any): number {
  if (!item1.category || !item2.category) return 0;

  const cat1 = item1.category.toLowerCase();
  const cat2 = item2.category.toLowerCase();

  // Exact match
  if (cat1 === cat2) return 100;

  // Check synonym match
  if (areSynonyms(cat1, cat2)) return 80;

  // Similar categories
  const categoryGroups: { [key: string]: string[] } = {
    documents: ['nic', 'passport', 'license', 'documents', 'id card', 'certificate'],
    electronics: ['phone', 'laptop', 'tablet', 'electronics', 'camera', 'headphones'],
    accessories: ['wallet', 'bag', 'keys', 'watch', 'jewelry', 'glasses', 'charger'],
    clothing: ['clothes', 'shoes', 'hat', 'jacket', 'shirt', 'pants'],
    pets: ['dog', 'cat', 'bird', 'pet', 'animal'],
  };

  for (const group of Object.values(categoryGroups)) {
    if (group.includes(cat1) && group.includes(cat2)) {
      return 70;
    }
  }

  return 10;
}

/**
 * Check for color match between items
 */
function checkColorMatch(item1: any, item2: any): boolean {
  const text1 = `${item1.title || ''} ${item1.description || ''} ${item1.color || ''}`.toLowerCase();
  const text2 = `${item2.title || ''} ${item2.description || ''} ${item2.color || ''}`.toLowerCase();

  const colors1 = extractColors(text1);
  const colors2 = extractColors(text2);

  if (colors1.size === 0 || colors2.size === 0) return false;

  // Check for intersection
  for (const color of colors1) {
    if (colors2.has(color)) return true;
  }
  return false;
}

function extractColors(text: string): Set<string> {
  const foundColors = new Set<string>();
  
  for (const [baseColor, variants] of Object.entries(COLOR_VARIANTS)) {
    for (const variant of variants) {
      if (text.includes(variant)) {
        foundColors.add(baseColor);
        break;
      }
    }
  }
  
  return foundColors;
}

/**
 * Check for brand match between items
 */
function checkBrandMatch(item1: any, item2: any): boolean {
  const text1 = `${item1.title || ''} ${item1.description || ''} ${item1.brand || ''}`.toLowerCase();
  const text2 = `${item2.title || ''} ${item2.description || ''} ${item2.brand || ''}`.toLowerCase();

  const brands1 = extractBrands(text1);
  const brands2 = extractBrands(text2);

  if (brands1.length === 0 || brands2.length === 0) return false;

  // Check for intersection
  for (const brand of brands1) {
    if (brands2.includes(brand)) return true;
  }
  return false;
}

function extractBrands(text: string): string[] {
  const foundBrands: string[] = [];
  for (const brand of KNOWN_BRANDS) {
    if (text.includes(brand)) {
      foundBrands.push(brand);
    }
  }
  return foundBrands;
}

/**
 * Check for NIC/Document number match
 */
function checkNICMatch(item1: any, item2: any): boolean {
  const text1 = `${item1.title || ''} ${item1.description || ''} ${item1.extractedText || ''}`;
  const text2 = `${item2.title || ''} ${item2.description || ''} ${item2.extractedText || ''}`;

  // Sri Lankan NIC patterns
  const nicPatternOld = /\d{9}[VXvx]/g;
  const nicPatternNew = /\d{12}/g;

  const nics1 = [
    ...Array.from(text1.matchAll(nicPatternOld)).map(m => m[0]),
    ...Array.from(text1.matchAll(nicPatternNew)).map(m => m[0]),
  ];
  const nics2 = [
    ...Array.from(text2.matchAll(nicPatternOld)).map(m => m[0]),
    ...Array.from(text2.matchAll(nicPatternNew)).map(m => m[0]),
  ];

  if (nics1.length === 0 || nics2.length === 0) return false;

  // Check for matching NICs
  for (const nic of nics1) {
    if (nics2.includes(nic)) return true;
  }
  return false;
}

/**
 * Calculate image similarity (placeholder)
 * TODO: Implement with TensorFlow image embeddings
 */
function calculateImageSimilarity(item1: any, item2: any): number {
  // Check if both items have images
  if (!item1.images?.length || !item2.images?.length) {
    return 0;
  }

  // Check if we have pre-computed embeddings
  if (item1.imageEmbedding && item2.imageEmbedding) {
    return cosineSimilarity(item1.imageEmbedding, item2.imageEmbedding) * 100;
  }

  // Placeholder: Return moderate score if both have images
  return 40;
}

/**
 * Calculate cosine similarity between two vectors
 */
function cosineSimilarity(vec1: number[], vec2: number[]): number {
  if (vec1.length !== vec2.length) return 0;

  let dotProduct = 0;
  let norm1 = 0;
  let norm2 = 0;

  for (let i = 0; i < vec1.length; i++) {
    dotProduct += vec1[i] * vec2[i];
    norm1 += vec1[i] * vec1[i];
    norm2 += vec2[i] * vec2[i];
  }

  const magnitude = Math.sqrt(norm1) * Math.sqrt(norm2);
  return magnitude === 0 ? 0 : dotProduct / magnitude;
}

/**
 * Find potential matches for an item
 */
export async function findMatches(
  itemId: string,
  item: any,
  limit: number = 10
): Promise<Array<{ itemId: string; score: MatchScore }>> {
  const oppositeType = item.status === 'lost' ? 'found' : 'lost';

  // Query for potential matches
  let query = db
    .collection('items')
    .where('status', '==', oppositeType)
    .where('isResolved', '==', false);

  // Filter by category if available
  if (item.category) {
    query = query.where('category', '==', item.category);
  }

  const snapshot = await query.limit(50).get();

  const matches: Array<{ itemId: string; score: MatchScore }> = [];

  for (const doc of snapshot.docs) {
    if (doc.id === itemId) continue;

    const score = calculateScore(item, doc.data());
    if (score.overallScore >= 30) {
      matches.push({ itemId: doc.id, score });
    }
  }

  // Sort by score and return top matches
  return matches
    .sort((a, b) => b.score.overallScore - a.score.overallScore)
    .slice(0, limit);
}
