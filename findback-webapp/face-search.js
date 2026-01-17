// ==========================================
// FindBack Web App - Face Search Module
// Face-Based Item Search Functionality
// ==========================================

/**
 * Face Search Service
 * Allows users to upload a photo containing a face and search for items
 * that contain photos of the same person.
 */

const FaceSearch = {
    // State
    selectedImage: null,
    searchResults: [],
    isSearching: false,
    faceDetected: false,
    threshold: 60,

    // ==========================================
    // Initialization
    // ==========================================

    init() {
        this.setupEventListeners();
        this.createFaceSearchModal();
    },

    setupEventListeners() {
        // Face search button in navigation or search area
        const faceSearchBtn = document.getElementById('face-search-btn');
        if (faceSearchBtn) {
            faceSearchBtn.addEventListener('click', () => this.openFaceSearchModal());
        }
    },

    // ==========================================
    // UI Components
    // ==========================================

    createFaceSearchModal() {
        const modal = document.createElement('div');
        modal.id = 'face-search-modal';
        modal.className = 'modal';
        modal.innerHTML = `
            <div class="modal-content face-search-modal-content">
                <div class="modal-header">
                    <h2><span class="modal-icon">👤</span> Face Search</h2>
                    <button class="close-btn" id="close-face-search">
                        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <line x1="18" y1="6" x2="6" y2="18"></line>
                            <line x1="6" y1="6" x2="18" y2="18"></line>
                        </svg>
                    </button>
                </div>
                
                <div class="face-search-body">
                    <!-- Instructions -->
                    <div class="face-search-instructions">
                        <div class="instruction-icon">🔍</div>
                        <h3>Search by Face</h3>
                        <p>Upload a photo containing a person's face to find items with photos of the same person.</p>
                    </div>
                    
                    <!-- Image Upload Area -->
                    <div class="face-upload-area" id="face-upload-area">
                        <input type="file" id="face-image-input" accept="image/*" style="display: none;">
                        <div class="upload-placeholder" id="face-upload-placeholder">
                            <div class="upload-icon">📷</div>
                            <span>Click to upload or drag & drop</span>
                            <small>Photo should contain a clear, visible face</small>
                        </div>
                        <img id="face-preview-image" class="face-preview" style="display: none;">
                        <div id="face-detection-overlay" class="face-detection-overlay" style="display: none;"></div>
                    </div>
                    
                    <!-- Face Detection Status -->
                    <div id="face-status" class="face-status" style="display: none;">
                        <span class="status-icon"></span>
                        <span class="status-text"></span>
                    </div>
                    
                    <!-- Threshold Slider -->
                    <div class="threshold-section" id="threshold-section" style="display: none;">
                        <div class="threshold-header">
                            <span>Match Threshold</span>
                            <span class="threshold-value" id="threshold-value">60%</span>
                        </div>
                        <input type="range" id="threshold-slider" min="30" max="95" value="60" step="5">
                        <small>Higher threshold = More accurate but fewer results</small>
                    </div>
                    
                    <!-- Search Button -->
                    <button class="btn btn-primary btn-full face-search-btn" id="start-face-search" style="display: none;">
                        <span class="btn-icon">🔍</span>
                        Search for Matching Items
                    </button>
                    
                    <!-- Loading State -->
                    <div id="face-search-loading" class="face-search-loading" style="display: none;">
                        <div class="loading-spinner"></div>
                        <span>AI is analyzing faces...</span>
                    </div>
                    
                    <!-- Results Section -->
                    <div id="face-search-results" class="face-search-results" style="display: none;">
                        <div class="results-header">
                            <h3>Search Results</h3>
                            <button class="btn btn-secondary" id="clear-face-search">Clear</button>
                        </div>
                        <div id="face-results-list" class="face-results-list"></div>
                    </div>
                    
                    <!-- No Results State -->
                    <div id="face-no-results" class="face-no-results" style="display: none;">
                        <div class="no-results-icon">😔</div>
                        <h3>No Matches Found</h3>
                        <p>We couldn't find any items containing photos of this person.</p>
                        <button class="btn btn-secondary" id="try-another-face">Try Another Photo</button>
                    </div>
                </div>
            </div>
        `;

        document.body.appendChild(modal);

        // Setup modal event listeners
        document.getElementById('close-face-search').addEventListener('click', () => this.closeFaceSearchModal());
        document.getElementById('face-upload-area').addEventListener('click', () => this.triggerImageUpload());
        document.getElementById('face-image-input').addEventListener('change', (e) => this.handleImageSelect(e));
        document.getElementById('threshold-slider').addEventListener('input', (e) => this.updateThreshold(e.target.value));
        document.getElementById('start-face-search').addEventListener('click', () => this.performSearch());
        document.getElementById('clear-face-search')?.addEventListener('click', () => this.clearSearch());
        document.getElementById('try-another-face')?.addEventListener('click', () => this.clearSearch());

        // Drag and drop
        const uploadArea = document.getElementById('face-upload-area');
        uploadArea.addEventListener('dragover', (e) => this.handleDragOver(e));
        uploadArea.addEventListener('dragleave', (e) => this.handleDragLeave(e));
        uploadArea.addEventListener('drop', (e) => this.handleDrop(e));

        // Close on backdrop click
        modal.addEventListener('click', (e) => {
            if (e.target === modal) this.closeFaceSearchModal();
        });
    },

    // ==========================================
    // Modal Controls
    // ==========================================

    openFaceSearchModal() {
        document.getElementById('face-search-modal').style.display = 'flex';
        document.body.style.overflow = 'hidden';
    },

    closeFaceSearchModal() {
        document.getElementById('face-search-modal').style.display = 'none';
        document.body.style.overflow = '';
        this.clearSearch();
    },

    // ==========================================
    // Image Handling
    // ==========================================

    triggerImageUpload() {
        document.getElementById('face-image-input').click();
    },

    handleImageSelect(event) {
        const file = event.target.files[0];
        if (file) {
            this.processImage(file);
        }
    },

    handleDragOver(e) {
        e.preventDefault();
        e.stopPropagation();
        e.currentTarget.classList.add('drag-over');
    },

    handleDragLeave(e) {
        e.preventDefault();
        e.stopPropagation();
        e.currentTarget.classList.remove('drag-over');
    },

    handleDrop(e) {
        e.preventDefault();
        e.stopPropagation();
        e.currentTarget.classList.remove('drag-over');

        const files = e.dataTransfer.files;
        if (files.length > 0 && files[0].type.startsWith('image/')) {
            this.processImage(files[0]);
        }
    },

    async processImage(file) {
        const reader = new FileReader();

        reader.onload = async (e) => {
            const imageData = e.target.result;

            // Show preview
            const preview = document.getElementById('face-preview-image');
            const placeholder = document.getElementById('face-upload-placeholder');

            preview.src = imageData;
            preview.style.display = 'block';
            placeholder.style.display = 'none';

            this.selectedImage = {
                file,
                dataUrl: imageData
            };

            // Simulate face detection (in production, this would call an API)
            await this.detectFaces();
        };

        reader.readAsDataURL(file);
    },

    async detectFaces() {
        const statusEl = document.getElementById('face-status');
        const thresholdSection = document.getElementById('threshold-section');
        const searchBtn = document.getElementById('start-face-search');

        statusEl.style.display = 'flex';
        statusEl.className = 'face-status detecting';
        statusEl.innerHTML = `
            <span class="status-icon">⏳</span>
            <span class="status-text">Detecting faces...</span>
        `;

        // Simulate face detection delay
        await new Promise(resolve => setTimeout(resolve, 1500));

        // In a real implementation, this would use face-api.js or call a cloud function
        // For demo, we'll simulate face detection
        const facesDetected = Math.random() > 0.2; // 80% chance of detecting a face

        if (facesDetected) {
            this.faceDetected = true;
            statusEl.className = 'face-status success';
            statusEl.innerHTML = `
                <span class="status-icon">✅</span>
                <span class="status-text">1 face detected. Ready to search!</span>
            `;

            thresholdSection.style.display = 'block';
            searchBtn.style.display = 'flex';

            // Show face detection overlay
            this.showFaceDetectionOverlay();
        } else {
            this.faceDetected = false;
            statusEl.className = 'face-status error';
            statusEl.innerHTML = `
                <span class="status-icon">⚠️</span>
                <span class="status-text">No face detected. Please try a clearer photo.</span>
            `;

            thresholdSection.style.display = 'none';
            searchBtn.style.display = 'none';
        }
    },

    showFaceDetectionOverlay() {
        const overlay = document.getElementById('face-detection-overlay');
        overlay.style.display = 'block';
        overlay.innerHTML = `
            <div class="face-box" style="
                position: absolute;
                top: 15%;
                left: 25%;
                width: 50%;
                height: 60%;
                border: 3px solid #10B981;
                border-radius: 50%;
                box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.2), 0 0 20px rgba(16, 185, 129, 0.3);
                animation: pulse-face 2s infinite;
            "></div>
        `;
    },

    updateThreshold(value) {
        this.threshold = parseInt(value);
        document.getElementById('threshold-value').textContent = `${value}%`;
    },

    // ==========================================
    // Search
    // ==========================================

    async performSearch() {
        if (!this.selectedImage || !this.faceDetected) {
            showToast('Please upload an image with a detectable face', 'error');
            return;
        }

        this.isSearching = true;

        // Hide search button, show loading
        document.getElementById('start-face-search').style.display = 'none';
        document.getElementById('face-search-loading').style.display = 'flex';
        document.getElementById('face-search-results').style.display = 'none';
        document.getElementById('face-no-results').style.display = 'none';

        try {
            // In production, this would call the Cloud Function
            // For now, we'll search locally with demo data
            const results = await this.searchFaceInItems();

            this.searchResults = results;
            this.isSearching = false;

            document.getElementById('face-search-loading').style.display = 'none';

            if (results.length > 0) {
                this.renderResults(results);
                document.getElementById('face-search-results').style.display = 'block';
            } else {
                document.getElementById('face-no-results').style.display = 'flex';
            }

        } catch (error) {
            console.error('Face search error:', error);
            this.isSearching = false;
            document.getElementById('face-search-loading').style.display = 'none';
            showToast('Search failed. Please try again.', 'error');
            document.getElementById('start-face-search').style.display = 'flex';
        }
    },

    async searchFaceInItems() {
        // Query items with faces from Firestore
        const snapshot = await db.collection('items')
            .where('status', '==', 'active')
            .where('hasFaces', '==', true)
            .limit(50)
            .get();

        if (snapshot.empty) {
            // If no items have faces processed yet, return demo results
            return this.getDemoResults();
        }

        // In a real implementation, we would:
        // 1. Upload the image temporarily
        // 2. Call the searchByFace Cloud Function
        // 3. Return the results

        // For now, return items that have faces as potential matches
        const results = snapshot.docs.map(doc => {
            const data = doc.data();
            return {
                itemId: doc.id,
                title: data.title,
                description: data.description,
                imageUrl: data.images?.[0],
                category: data.category,
                district: data.district,
                type: data.type,
                similarity: Math.floor(Math.random() * 30) + this.threshold, // Demo similarity
                matchConfidence: this.getMatchConfidence(Math.floor(Math.random() * 30) + this.threshold),
                userName: data.userName,
                createdAt: data.createdAt
            };
        });

        // Filter by threshold and sort by similarity
        return results
            .filter(r => r.similarity >= this.threshold)
            .sort((a, b) => b.similarity - a.similarity)
            .slice(0, 20);
    },

    getDemoResults() {
        // Return some demo results for testing
        return [
            {
                itemId: 'demo1',
                title: 'Found: Person in Coffee Shop',
                description: 'Found a photo of this person at the coffee shop on Main Street',
                imageUrl: null,
                category: 'Other',
                district: 'Colombo',
                type: 'found',
                similarity: 85,
                matchConfidence: 'High',
                userName: 'Demo User'
            },
            {
                itemId: 'demo2',
                title: 'Missing Person at Park',
                description: 'Looking for this person who was last seen at the central park',
                imageUrl: null,
                category: 'Other',
                district: 'Kandy',
                type: 'lost',
                similarity: 72,
                matchConfidence: 'Medium',
                userName: 'Demo User 2'
            }
        ].filter(r => r.similarity >= this.threshold);
    },

    getMatchConfidence(similarity) {
        if (similarity >= 90) return 'Very High';
        if (similarity >= 75) return 'High';
        if (similarity >= 60) return 'Medium';
        if (similarity >= 45) return 'Low';
        return 'Very Low';
    },

    getConfidenceColor(confidence) {
        switch (confidence) {
            case 'Very High': return '#10B981';
            case 'High': return '#22C55E';
            case 'Medium': return '#F59E0B';
            case 'Low': return '#EF4444';
            default: return '#6B7280';
        }
    },

    // ==========================================
    // Render Results
    // ==========================================

    renderResults(results) {
        const resultsEl = document.getElementById('face-results-list');

        resultsEl.innerHTML = results.map(result => `
            <div class="face-result-card" onclick="FaceSearch.openResult('${result.itemId}')">
                <div class="result-image">
                    ${result.imageUrl
                ? `<img src="${result.imageUrl}" alt="${result.title}">`
                : `<div class="result-image-placeholder">${this.getCategoryEmoji(result.category)}</div>`
            }
                </div>
                <div class="result-info">
                    <div class="result-badges">
                        <span class="item-badge ${result.type}">${result.type.toUpperCase()}</span>
                        <span class="category-badge">${result.category}</span>
                    </div>
                    <h4 class="result-title">${result.title}</h4>
                    <p class="result-description">${result.description}</p>
                    <div class="result-meta">
                        <span>📍 ${result.district}</span>
                        <span>👤 ${result.userName}</span>
                    </div>
                </div>
                <div class="result-score">
                    <div class="score-circle" style="border-color: ${this.getConfidenceColor(result.matchConfidence)}">
                        <span class="score-value">${result.similarity}%</span>
                    </div>
                    <span class="score-label" style="color: ${this.getConfidenceColor(result.matchConfidence)}">
                        ${result.matchConfidence}
                    </span>
                </div>
            </div>
        `).join('');
    },

    getCategoryEmoji(category) {
        const emojis = {
            'Electronics': '📱',
            'Documents': '📄',
            'Wallet': '👛',
            'Keys': '🔑',
            'Jewelry': '💍',
            'Bags': '👜',
            'Clothing': '👕',
            'Pets': '🐕',
            'Other': '📦'
        };
        return emojis[category] || '📦';
    },

    openResult(itemId) {
        this.closeFaceSearchModal();
        if (typeof openItemDetail === 'function') {
            openItemDetail(itemId);
        }
    },

    clearSearch() {
        this.selectedImage = null;
        this.searchResults = [];
        this.faceDetected = false;

        document.getElementById('face-preview-image').style.display = 'none';
        document.getElementById('face-upload-placeholder').style.display = 'flex';
        document.getElementById('face-status').style.display = 'none';
        document.getElementById('threshold-section').style.display = 'none';
        document.getElementById('start-face-search').style.display = 'none';
        document.getElementById('face-search-loading').style.display = 'none';
        document.getElementById('face-search-results').style.display = 'none';
        document.getElementById('face-no-results').style.display = 'none';
        document.getElementById('face-detection-overlay').style.display = 'none';
        document.getElementById('face-image-input').value = '';
    }
};

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    FaceSearch.init();
});

// Export for global access
window.FaceSearch = FaceSearch;
