// ==========================================
// FindBack Web App - JavaScript
// Full Firebase Integration
// ==========================================

// ==========================================
// Firebase Configuration
// ==========================================
// ⚠️ YOU MUST UPDATE THIS WITH YOUR REAL CONFIG!
// 
// TO GET YOUR CONFIG:
// 1. Go to https://console.firebase.google.com
// 2. Select your project (findback-eeb5b)
// 3. Click gear icon ⚙️ > Project Settings
// 4. Scroll to "Your apps" section
// 5. Click "Add app" > Web icon </>
// 6. Name it "FindBack Web" and register
// 7. Copy the config object below
// ==========================================

const firebaseConfig = {
    // 👇 REPLACE THESE VALUES WITH YOUR FIREBASE WEB CONFIG 👇
    apiKey: "PASTE_YOUR_API_KEY_HERE",
    authDomain: "findback-eeb5b.firebaseapp.com",
    projectId: "findback-eeb5b",
    storageBucket: "findback-eeb5b.firebasestorage.app",
    messagingSenderId: "387741256841",
    appId: "PASTE_YOUR_APP_ID_HERE"
};

// Check if config is still placeholder
const isConfigValid = !firebaseConfig.apiKey.includes('PASTE_') &&
    !firebaseConfig.appId.includes('PASTE_');

if (!isConfigValid) {
    // Show setup instructions
    document.addEventListener('DOMContentLoaded', () => {
        const app = document.getElementById('app');
        if (app) {
            app.innerHTML = `
                <div style="max-width: 600px; margin: 50px auto; padding: 20px; font-family: Inter, sans-serif; color: #fff; background: #1a1a2e; border-radius: 16px;">
                    <h1 style="color: #ef4444;">⚠️ Firebase Not Configured</h1>
                    <p>You need to add your Firebase Web App configuration.</p>
                    <h3 style="color: #667eea;">Steps to fix:</h3>
                    <ol style="line-height: 2;">
                        <li>Go to <a href="https://console.firebase.google.com/project/findback-eeb5b/settings/general" target="_blank" style="color: #667eea;">Firebase Console → Settings</a></li>
                        <li>Scroll to <strong>"Your apps"</strong> section</li>
                        <li>Click <strong>"Add app"</strong> → Select <strong>Web</strong> (&lt;/&gt;)</li>
                        <li>Name: <code style="background: #252540; padding: 2px 8px; border-radius: 4px;">FindBack Web</code></li>
                        <li>Click <strong>Register app</strong></li>
                        <li>Copy the <code>firebaseConfig</code> object</li>
                        <li>Open <code style="background: #252540; padding: 2px 8px; border-radius: 4px;">app.js</code></li>
                        <li>Replace the placeholder values (lines 17-22)</li>
                        <li>Refresh this page</li>
                    </ol>
                    <p style="margin-top: 20px; padding: 15px; background: #252540; border-radius: 8px;">
                        <strong>File location:</strong><br>
                        <code>d:\\lostAndFinder\\findback-webapp\\app.js</code>
                    </p>
                </div>
            `;
        }
    });
    throw new Error('Firebase config not set. Please update app.js with your Firebase Web App config.');
}

// Initialize Firebase
firebase.initializeApp(firebaseConfig);
const auth = firebase.auth();
const db = firebase.firestore();
const storage = firebase.storage();

// ==========================================
// App State
// ==========================================

const AppState = {
    user: null,
    currentFilter: 'all',
    currentItemType: 'lost',
    selectedItem: null,
    currentChat: null,
    items: [],
    matches: [],
    chats: []
};

// ==========================================
// DOM Elements
// ==========================================

const elements = {
    loadingScreen: document.getElementById('loading-screen'),
    authScreen: document.getElementById('auth-screen'),
    mainApp: document.getElementById('main-app'),
    loginForm: document.getElementById('login-form'),
    signupForm: document.getElementById('signup-form'),
    postForm: document.getElementById('post-form'),
    itemsList: document.getElementById('items-list'),
    matchesList: document.getElementById('matches-list'),
    chatsList: document.getElementById('chats-list'),
    myItemsList: document.getElementById('my-items-list'),
    itemModal: document.getElementById('item-modal'),
    chatModal: document.getElementById('chat-modal'),
    toastContainer: document.getElementById('toast-container')
};

// ==========================================
// Initialize App
// ==========================================

document.addEventListener('DOMContentLoaded', () => {
    initApp();
});

function initApp() {
    // Auth state listener
    auth.onAuthStateChanged(user => {
        setTimeout(() => {
            elements.loadingScreen.style.display = 'none';

            if (user) {
                AppState.user = user;
                showMainApp();
                loadUserData();
                loadItems();
                loadMatches();
                loadChats();
            } else {
                showAuthScreen();
            }
        }, 1000);
    });

    // Setup event listeners
    setupEventListeners();
}

function setupEventListeners() {
    // Auth tabs
    document.querySelectorAll('.auth-tab').forEach(tab => {
        tab.addEventListener('click', () => switchAuthTab(tab.dataset.tab));
    });

    // Login form
    elements.loginForm.addEventListener('submit', handleLogin);

    // Signup form
    elements.signupForm.addEventListener('submit', handleSignup);

    // Google sign in
    document.getElementById('google-signin').addEventListener('click', handleGoogleSignIn);

    // Navigation
    document.querySelectorAll('.nav-item').forEach(item => {
        item.addEventListener('click', () => switchTab(item.dataset.tab));
    });

    // Filter tabs
    document.querySelectorAll('.filter-tab').forEach(tab => {
        tab.addEventListener('click', () => {
            document.querySelectorAll('.filter-tab').forEach(t => t.classList.remove('active'));
            tab.classList.add('active');
            AppState.currentFilter = tab.dataset.filter;
            renderItems();
        });
    });

    // Post type selector
    document.querySelectorAll('.post-type').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.post-type').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            AppState.currentItemType = btn.dataset.type;
        });
    });

    // Post form
    elements.postForm.addEventListener('submit', handlePostItem);

    // Image upload
    document.getElementById('image-upload').addEventListener('click', () => {
        document.getElementById('item-image').click();
    });

    document.getElementById('item-image').addEventListener('change', handleImageSelect);

    // Modals
    document.getElementById('close-modal').addEventListener('click', closeItemModal);
    document.getElementById('close-chat').addEventListener('click', closeChatModal);

    // Send message
    document.getElementById('send-message').addEventListener('click', sendMessage);
    document.getElementById('chat-input').addEventListener('keypress', e => {
        if (e.key === 'Enter') sendMessage();
    });

    // Logout
    document.getElementById('logout-btn').addEventListener('click', handleLogout);

    // Search
    document.getElementById('search-input').addEventListener('input', debounce(handleSearch, 300));

    // Profile button
    document.getElementById('profile-btn').addEventListener('click', () => switchTab('profile'));
}

// ==========================================
// Authentication
// ==========================================

function switchAuthTab(tab) {
    document.querySelectorAll('.auth-tab').forEach(t => t.classList.remove('active'));
    document.querySelector(`[data-tab="${tab}"]`).classList.add('active');

    if (tab === 'login') {
        elements.loginForm.style.display = 'block';
        elements.signupForm.style.display = 'none';
    } else {
        elements.loginForm.style.display = 'none';
        elements.signupForm.style.display = 'block';
    }
}

async function handleLogin(e) {
    e.preventDefault();
    const email = document.getElementById('login-email').value;
    const password = document.getElementById('login-password').value;

    try {
        await auth.signInWithEmailAndPassword(email, password);
        showToast('Welcome back!', 'success');
    } catch (error) {
        showToast(error.message, 'error');
    }
}

async function handleSignup(e) {
    e.preventDefault();
    const name = document.getElementById('signup-name').value;
    const email = document.getElementById('signup-email').value;
    const password = document.getElementById('signup-password').value;
    const district = document.getElementById('signup-district').value;

    try {
        const userCredential = await auth.createUserWithEmailAndPassword(email, password);

        // Create user document in Firestore
        await db.collection('users').doc(userCredential.user.uid).set({
            name,
            email,
            district,
            reputation: 0,
            itemsPosted: 0,
            itemsReturned: 0,
            createdAt: firebase.firestore.FieldValue.serverTimestamp()
        });

        showToast('Account created successfully!', 'success');
    } catch (error) {
        showToast(error.message, 'error');
    }
}

async function handleGoogleSignIn() {
    const provider = new firebase.auth.GoogleAuthProvider();

    try {
        const result = await auth.signInWithPopup(provider);

        // Check if user document exists
        const userDoc = await db.collection('users').doc(result.user.uid).get();

        if (!userDoc.exists) {
            await db.collection('users').doc(result.user.uid).set({
                name: result.user.displayName,
                email: result.user.email,
                photoURL: result.user.photoURL,
                reputation: 0,
                itemsPosted: 0,
                itemsReturned: 0,
                createdAt: firebase.firestore.FieldValue.serverTimestamp()
            });
        }

        showToast('Welcome!', 'success');
    } catch (error) {
        showToast(error.message, 'error');
    }
}

function handleLogout() {
    auth.signOut();
    showToast('Logged out', 'info');
}

// ==========================================
// Navigation
// ==========================================

function showAuthScreen() {
    elements.authScreen.style.display = 'block';
    elements.mainApp.style.display = 'none';
}

function showMainApp() {
    elements.authScreen.style.display = 'none';
    elements.mainApp.style.display = 'block';
}

function switchTab(tab) {
    // Update nav items
    document.querySelectorAll('.nav-item').forEach(item => {
        item.classList.toggle('active', item.dataset.tab === tab);
    });

    // Update tab content
    document.querySelectorAll('.tab-content').forEach(content => {
        content.classList.toggle('active', content.id === `${tab}-tab`);
    });
}

// ==========================================
// Items
// ==========================================

async function loadItems() {
    try {
        const snapshot = await db.collection('items')
            .where('status', '==', 'active')
            .orderBy('createdAt', 'desc')
            .limit(50)
            .get();

        AppState.items = snapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data()
        }));

        renderItems();
    } catch (error) {
        console.error('Error loading items:', error);
    }
}

function renderItems() {
    const filteredItems = AppState.currentFilter === 'all'
        ? AppState.items
        : AppState.items.filter(item => item.type === AppState.currentFilter);

    if (filteredItems.length === 0) {
        elements.itemsList.innerHTML = `
            <div class="empty-state" style="grid-column: 1/-1;">
                <div class="empty-icon">📦</div>
                <div class="empty-title">No items found</div>
                <p>Be the first to post an item!</p>
            </div>
        `;
        return;
    }

    elements.itemsList.innerHTML = filteredItems.map(item => `
        <div class="item-card" onclick="openItemDetail('${item.id}')">
            <div class="item-image">
                ${item.images && item.images[0]
            ? `<img src="${item.images[0]}" alt="${item.title}">`
            : getCategoryEmoji(item.category)}
            </div>
            <div class="item-info">
                <span class="item-badge ${item.type}">${item.type.toUpperCase()}</span>
                <div class="item-title">${item.title}</div>
                <div class="item-location">📍 ${item.district}</div>
            </div>
        </div>
    `).join('');
}

function getCategoryEmoji(category) {
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
}

async function handlePostItem(e) {
    e.preventDefault();

    const title = document.getElementById('item-title').value;
    const category = document.getElementById('item-category').value;
    const description = document.getElementById('item-description').value;
    const district = document.getElementById('item-district').value;
    const location = document.getElementById('item-location').value;
    const imageFile = document.getElementById('item-image').files[0];

    try {
        let imageUrl = null;

        // Upload image if provided
        if (imageFile) {
            const storageRef = storage.ref(`items/${Date.now()}_${imageFile.name}`);
            await storageRef.put(imageFile);
            imageUrl = await storageRef.getDownloadURL();
        }

        // Create item document
        await db.collection('items').add({
            title,
            category,
            description,
            district,
            location,
            type: AppState.currentItemType,
            status: 'active',
            userId: AppState.user.uid,
            userName: AppState.user.displayName || AppState.user.email.split('@')[0],
            images: imageUrl ? [imageUrl] : [],
            createdAt: firebase.firestore.FieldValue.serverTimestamp()
        });

        // Update user's item count
        await db.collection('users').doc(AppState.user.uid).update({
            itemsPosted: firebase.firestore.FieldValue.increment(1)
        });

        showToast('Item posted successfully!', 'success');
        elements.postForm.reset();
        document.getElementById('image-preview').style.display = 'none';
        document.querySelector('.upload-placeholder').style.display = 'block';

        switchTab('home');
        loadItems();
        loadUserData();
    } catch (error) {
        showToast(error.message, 'error');
    }
}

function handleImageSelect(e) {
    const file = e.target.files[0];
    if (file) {
        const reader = new FileReader();
        reader.onload = function (e) {
            document.getElementById('image-preview').src = e.target.result;
            document.getElementById('image-preview').style.display = 'block';
            document.querySelector('.upload-placeholder').style.display = 'none';
        };
        reader.readAsDataURL(file);
    }
}

function openItemDetail(itemId) {
    const item = AppState.items.find(i => i.id === itemId);
    if (!item) return;

    AppState.selectedItem = item;

    document.getElementById('item-detail-content').innerHTML = `
        <div class="item-detail">
            <div class="item-detail-image">
                ${item.images && item.images[0]
            ? `<img src="${item.images[0]}" alt="${item.title}">`
            : getCategoryEmoji(item.category)}
            </div>
            <span class="item-badge ${item.type}">${item.type.toUpperCase()}</span>
            <h2>${item.title}</h2>
            <div class="item-detail-info">
                <div class="item-detail-row">
                    <span class="item-detail-label">Category</span>
                    <span>${item.category}</span>
                </div>
                <div class="item-detail-row">
                    <span class="item-detail-label">District</span>
                    <span>${item.district}</span>
                </div>
                <div class="item-detail-row">
                    <span class="item-detail-label">Location</span>
                    <span>${item.location || 'Not specified'}</span>
                </div>
                <div class="item-detail-row">
                    <span class="item-detail-label">Posted by</span>
                    <span>${item.userName}</span>
                </div>
            </div>
            <p style="margin-bottom: 1.5rem; color: var(--text-secondary);">${item.description}</p>
            ${item.userId !== AppState.user.uid ? `
                <button class="btn btn-primary btn-full" onclick="startChat('${item.id}', '${item.userId}', '${item.userName}', '${item.title}')">
                    💬 Contact ${item.type === 'lost' ? 'Owner' : 'Finder'}
                </button>
            ` : ''}
        </div>
    `;

    elements.itemModal.style.display = 'flex';
}

function closeItemModal() {
    elements.itemModal.style.display = 'none';
    AppState.selectedItem = null;
}

function handleSearch(e) {
    const query = e.target.value.toLowerCase();

    if (!query) {
        renderItems();
        return;
    }

    const filtered = AppState.items.filter(item =>
        item.title.toLowerCase().includes(query) ||
        item.description.toLowerCase().includes(query) ||
        item.category.toLowerCase().includes(query) ||
        item.district.toLowerCase().includes(query)
    );

    elements.itemsList.innerHTML = filtered.map(item => `
        <div class="item-card" onclick="openItemDetail('${item.id}')">
            <div class="item-image">
                ${item.images && item.images[0]
            ? `<img src="${item.images[0]}" alt="${item.title}">`
            : getCategoryEmoji(item.category)}
            </div>
            <div class="item-info">
                <span class="item-badge ${item.type}">${item.type.toUpperCase()}</span>
                <div class="item-title">${item.title}</div>
                <div class="item-location">📍 ${item.district}</div>
            </div>
        </div>
    `).join('');
}

// ==========================================
// Matches
// ==========================================

async function loadMatches() {
    try {
        const snapshot = await db.collection('matches')
            .where('userId', '==', AppState.user.uid)
            .orderBy('createdAt', 'desc')
            .limit(20)
            .get();

        AppState.matches = snapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data()
        }));

        renderMatches();
    } catch (error) {
        console.error('Error loading matches:', error);
    }
}

function renderMatches() {
    if (AppState.matches.length === 0) {
        elements.matchesList.innerHTML = `
            <div class="empty-state">
                <div class="empty-icon">🎯</div>
                <div class="empty-title">No matches yet</div>
                <p>Post an item and our AI will find potential matches!</p>
            </div>
        `;
        return;
    }

    elements.matchesList.innerHTML = AppState.matches.map(match => {
        // Support both old and new field names
        const overallScore = match.overallScore ?? match.confidenceScore ?? 0;
        const textScore = match.textScore ?? match.textSimilarity ?? 0;
        const imageScore = match.imageScore ?? 0;
        const faceScore = match.faceScore ?? 0;
        const locationScore = match.locationScore ?? 0;
        const timeScore = match.timeScore ?? 0;
        const aiScore = match.aiScore ?? 0;
        const confidenceLevel = match.confidenceLevel ?? getConfidenceLevel(overallScore);
        const matchedBy = match.matchedBy || [];

        return `
        <div class="match-card" onclick="openMatchDetails('${match.id}')">
            <div class="match-header">
                <span class="match-title">${match.matchedItemTitle || 'Potential Match'}</span>
                <div class="match-score-badge" style="background: ${getScoreGradient(overallScore)}">
                    <span class="score-value">${overallScore}%</span>
                    <span class="score-label">${confidenceLevel}</span>
                </div>
            </div>
            <p class="match-description">${match.matchedItemDescription || 'View details to learn more'}</p>
            
            <!-- Score Breakdown -->
            <div class="score-breakdown">
                <div class="score-row">
                    ${buildScoreBar('📝 Text', textScore)}
                    ${buildScoreBar('📷 Image', imageScore)}
                    ${buildScoreBar('📍 Location', locationScore)}
                </div>
                <div class="score-row">
                    ${buildScoreBar('⏱️ Time', timeScore)}
                    ${buildScoreBar('👤 Face', faceScore)}
                    ${buildScoreBar('🤖 AI', aiScore)}
                </div>
            </div>
            
            ${matchedBy.length > 0 ? `
                <div class="matched-by">
                    <span>Matched by: ${matchedBy.join(', ')}</span>
                </div>
            ` : ''}
            
            <div class="match-actions">
                <button class="match-btn secondary" onclick="event.stopPropagation(); openItemDetail('${match.matchedItemId}')">View Item</button>
                <button class="match-btn primary" onclick="event.stopPropagation(); startChatFromMatch('${match.matchedUserId}', '${match.matchedUserName}', '${match.matchedItemId}', '${match.matchedItemTitle}')">Contact</button>
            </div>
        </div>
    `}).join('');
}

function buildScoreBar(label, score) {
    const color = getScoreColor(score);
    return `
        <div class="score-item">
            <div class="score-item-header">
                <span class="score-item-label">${label}</span>
                <span class="score-item-value" style="color: ${color}">${score}%</span>
            </div>
            <div class="score-bar-bg">
                <div class="score-bar-fill" style="width: ${score}%; background: ${color}"></div>
            </div>
        </div>
    `;
}

function getScoreColor(score) {
    if (score >= 85) return '#10B981';
    if (score >= 70) return '#22C55E';
    if (score >= 50) return '#F59E0B';
    if (score >= 30) return '#EF4444';
    return '#6B7280';
}

function getScoreGradient(score) {
    const color = getScoreColor(score);
    return `linear-gradient(135deg, ${color}, ${color}cc)`;
}

function getConfidenceLevel(score) {
    if (score >= 85) return 'Very High';
    if (score >= 70) return 'High';
    if (score >= 50) return 'Medium';
    if (score >= 30) return 'Low';
    return 'Very Low';
}

function openMatchDetails(matchId) {
    const match = AppState.matches.find(m => m.id === matchId);
    if (!match) return;

    const overallScore = match.overallScore ?? match.confidenceScore ?? 0;
    const textScore = match.textScore ?? match.textSimilarity ?? 0;
    const imageScore = match.imageScore ?? 0;
    const faceScore = match.faceScore ?? 0;
    const locationScore = match.locationScore ?? 0;
    const timeScore = match.timeScore ?? 0;
    const aiScore = match.aiScore ?? 0;
    const locationProximityKm = match.locationProximityKm ?? 0;
    const timeDifferenceHours = match.timeDifferenceHours ?? 0;
    const confidenceLevel = match.confidenceLevel ?? getConfidenceLevel(overallScore);

    // Create modal for detailed view
    const modal = document.createElement('div');
    modal.className = 'modal';
    modal.id = 'match-detail-modal';
    modal.style.display = 'flex';
    modal.innerHTML = `
        <div class="modal-content match-detail-modal-content">
            <button class="modal-close" onclick="closeMatchDetailModal()">✕</button>
            
            <div class="match-detail-header">
                <div class="overall-score-circle" style="background: ${getScoreGradient(overallScore)}">
                    <span class="overall-score-value">${overallScore}%</span>
                    <span class="overall-score-text">MATCH</span>
                </div>
                <span class="confidence-badge" style="background: ${getScoreColor(overallScore)}20; color: ${getScoreColor(overallScore)}">${confidenceLevel}</span>
            </div>
            
            <h2 style="margin: 1.5rem 0 1rem">${match.matchedItemTitle || 'Unknown Item'}</h2>
            
            <div class="detail-section">
                <h3>📊 Score Breakdown</h3>
                ${buildDetailedScoreRow('📝 Text Similarity', textScore, '20%')}
                ${buildDetailedScoreRow('📷 Image Match', imageScore, '30%')}
                ${buildDetailedScoreRow('📍 Location Proximity', locationScore, '15%', `${locationProximityKm.toFixed(1)} km away`)}
                ${buildDetailedScoreRow('⏱️ Time Difference', timeScore, '10%', `${timeDifferenceHours} hours apart`)}
                ${buildDetailedScoreRow('👤 Face Match', faceScore, '15%')}
                ${buildDetailedScoreRow('🤖 AI Analysis', aiScore, '10%')}
            </div>
            
            <div class="detail-section">
                <h3>📄 Description</h3>
                <p>${match.matchedItemDescription || 'No description available'}</p>
            </div>
            
            <div class="match-detail-actions">
                <button class="btn btn-secondary" onclick="closeMatchDetailModal()">Close</button>
                <button class="btn btn-primary" onclick="closeMatchDetailModal(); openItemDetail('${match.matchedItemId}')">View Item</button>
            </div>
        </div>
    `;

    document.body.appendChild(modal);
    modal.addEventListener('click', (e) => {
        if (e.target === modal) closeMatchDetailModal();
    });
}

function buildDetailedScoreRow(label, score, weight, subtitle = '') {
    const color = getScoreColor(score);
    return `
        <div class="detailed-score-row">
            <div class="detailed-score-header">
                <span class="detailed-score-label">${label}</span>
                <span class="detailed-score-value" style="color: ${color}">${score}%</span>
                <span class="detailed-score-weight">(${weight})</span>
            </div>
            ${subtitle ? `<span class="detailed-score-subtitle">${subtitle}</span>` : ''}
            <div class="detailed-score-bar-bg">
                <div class="detailed-score-bar-fill" style="width: ${score}%; background: ${color}"></div>
            </div>
        </div>
    `;
}

function closeMatchDetailModal() {
    const modal = document.getElementById('match-detail-modal');
    if (modal) modal.remove();
}

function startChatFromMatch(userId, userName, itemId, itemTitle) {
    // Start chat with the matched user
    startChat(itemId, userId, userName, itemTitle);
}

// ==========================================
// Chats
// ==========================================

async function loadChats() {
    try {
        const snapshot = await db.collection('chats')
            .where('participants', 'array-contains', AppState.user.uid)
            .orderBy('lastMessageTime', 'desc')
            .limit(20)
            .get();

        AppState.chats = snapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data()
        }));

        renderChats();
    } catch (error) {
        console.error('Error loading chats:', error);
    }
}

function renderChats() {
    if (AppState.chats.length === 0) {
        elements.chatsList.innerHTML = `
            <div class="empty-state">
                <div class="empty-icon">💬</div>
                <div class="empty-title">No conversations yet</div>
                <p>Start a chat by contacting an item owner or finder!</p>
            </div>
        `;
        return;
    }

    elements.chatsList.innerHTML = AppState.chats.map(chat => {
        const otherUserId = chat.participants.find(p => p !== AppState.user.uid);
        const otherUserName = chat.participantNames?.[otherUserId] || 'User';

        return `
            <div class="chat-item" onclick="openChat('${chat.id}', '${otherUserName}', '${chat.itemTitle || ''}')">
                <div class="chat-avatar">${otherUserName.charAt(0).toUpperCase()}</div>
                <div class="chat-info">
                    <div class="chat-name">${otherUserName}</div>
                    <div class="chat-preview">${chat.lastMessage || 'No messages yet'}</div>
                </div>
                <div class="chat-time">${formatTime(chat.lastMessageTime)}</div>
            </div>
        `;
    }).join('');
}

async function startChat(itemId, otherUserId, otherUserName, itemTitle) {
    closeItemModal();

    // Check if chat already exists
    const existingChat = AppState.chats.find(c =>
        c.participants.includes(otherUserId) && c.itemId === itemId
    );

    if (existingChat) {
        openChat(existingChat.id, otherUserName, itemTitle);
        return;
    }

    // Create new chat
    try {
        const chatRef = await db.collection('chats').add({
            participants: [AppState.user.uid, otherUserId],
            participantNames: {
                [AppState.user.uid]: AppState.user.displayName || AppState.user.email.split('@')[0],
                [otherUserId]: otherUserName
            },
            itemId,
            itemTitle,
            createdAt: firebase.firestore.FieldValue.serverTimestamp(),
            lastMessageTime: firebase.firestore.FieldValue.serverTimestamp()
        });

        openChat(chatRef.id, otherUserName, itemTitle);
        loadChats();
    } catch (error) {
        showToast(error.message, 'error');
    }
}

async function openChat(chatId, userName, itemTitle) {
    AppState.currentChat = chatId;

    document.getElementById('chat-user-name').textContent = userName;
    document.getElementById('chat-item-title').textContent = itemTitle;

    elements.chatModal.style.display = 'flex';

    // Load messages
    loadMessages(chatId);

    // Listen for new messages
    db.collection('chats').doc(chatId).collection('messages')
        .orderBy('timestamp', 'asc')
        .onSnapshot(snapshot => {
            renderMessages(snapshot.docs.map(doc => ({
                id: doc.id,
                ...doc.data()
            })));
        });
}

function loadMessages(chatId) {
    db.collection('chats').doc(chatId).collection('messages')
        .orderBy('timestamp', 'asc')
        .get()
        .then(snapshot => {
            renderMessages(snapshot.docs.map(doc => ({
                id: doc.id,
                ...doc.data()
            })));
        });
}

function renderMessages(messages) {
    const container = document.getElementById('chat-messages');

    container.innerHTML = messages.map(msg => `
        <div class="message ${msg.senderId === AppState.user.uid ? 'sent' : 'received'}">
            ${msg.text}
            <div class="message-time">${formatTime(msg.timestamp)}</div>
        </div>
    `).join('');

    // Scroll to bottom
    container.scrollTop = container.scrollHeight;
}

async function sendMessage() {
    const input = document.getElementById('chat-input');
    const text = input.value.trim();

    if (!text || !AppState.currentChat) return;

    try {
        await db.collection('chats').doc(AppState.currentChat).collection('messages').add({
            text,
            senderId: AppState.user.uid,
            timestamp: firebase.firestore.FieldValue.serverTimestamp()
        });

        await db.collection('chats').doc(AppState.currentChat).update({
            lastMessage: text,
            lastMessageTime: firebase.firestore.FieldValue.serverTimestamp()
        });

        input.value = '';
    } catch (error) {
        showToast(error.message, 'error');
    }
}

function closeChatModal() {
    elements.chatModal.style.display = 'none';
    AppState.currentChat = null;
}

// ==========================================
// User Profile
// ==========================================

async function loadUserData() {
    try {
        const userDoc = await db.collection('users').doc(AppState.user.uid).get();

        if (userDoc.exists) {
            const userData = userDoc.data();

            document.getElementById('profile-name').textContent = userData.name || AppState.user.email;
            document.getElementById('profile-email').textContent = AppState.user.email;
            document.getElementById('stat-posted').textContent = userData.itemsPosted || 0;
            document.getElementById('stat-returned').textContent = userData.itemsReturned || 0;
            document.getElementById('stat-reputation').textContent = userData.reputation || 0;

            if (userData.name) {
                document.getElementById('profile-avatar').textContent = userData.name.charAt(0).toUpperCase();
            }
        }

        // Load user's items
        loadMyItems();
    } catch (error) {
        console.error('Error loading user data:', error);
    }
}

async function loadMyItems() {
    try {
        const snapshot = await db.collection('items')
            .where('userId', '==', AppState.user.uid)
            .orderBy('createdAt', 'desc')
            .limit(10)
            .get();

        const items = snapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data()
        }));

        if (items.length === 0) {
            elements.myItemsList.innerHTML = `
                <div class="empty-state">
                    <p>You haven't posted any items yet</p>
                </div>
            `;
            return;
        }

        elements.myItemsList.innerHTML = items.map(item => `
            <div class="my-item" onclick="openItemDetail('${item.id}')">
                <span class="my-item-icon">${getCategoryEmoji(item.category)}</span>
                <div class="my-item-info">
                    <div class="my-item-title">${item.title}</div>
                    <div class="my-item-status">
                        <span class="item-badge ${item.type}">${item.type.toUpperCase()}</span>
                        ${item.status}
                    </div>
                </div>
            </div>
        `).join('');
    } catch (error) {
        console.error('Error loading my items:', error);
    }
}

// ==========================================
// Utilities
// ==========================================

function showToast(message, type = 'info') {
    const icons = {
        success: '✅',
        error: '❌',
        info: 'ℹ️'
    };

    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.innerHTML = `
        <span class="toast-icon">${icons[type]}</span>
        <span class="toast-message">${message}</span>
    `;

    elements.toastContainer.appendChild(toast);

    setTimeout(() => {
        toast.style.animation = 'toastOut 0.3s ease forwards';
        setTimeout(() => toast.remove(), 300);
    }, 3000);
}

function formatTime(timestamp) {
    if (!timestamp) return '';

    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    const now = new Date();
    const diff = now - date;

    if (diff < 60000) return 'Just now';
    if (diff < 3600000) return `${Math.floor(diff / 60000)}m ago`;
    if (diff < 86400000) return `${Math.floor(diff / 3600000)}h ago`;

    return date.toLocaleDateString();
}

function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Make functions globally accessible
window.openItemDetail = openItemDetail;
window.startChat = startChat;
window.openChat = openChat;
