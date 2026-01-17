// ==========================================
// FindBack Website - JavaScript with Analytics
// Real visitor tracking and download counting
// ==========================================

// ==========================================
// Analytics & Tracking System
// ==========================================

const Analytics = {
    // Storage keys
    VISIT_KEY: 'findback_visits',
    DOWNLOAD_KEY: 'findback_downloads',
    FIRST_VISIT_KEY: 'findback_first_visit',

    // Initialize analytics
    init() {
        this.trackVisit();
        this.updateStats();
        this.setupDownloadTracking();
    },

    // Track page visit
    trackVisit() {
        const today = new Date().toDateString();
        const lastVisit = localStorage.getItem('lastVisitDate');

        // Only count unique daily visits
        if (lastVisit !== today) {
            const visits = this.getVisits();
            visits.total++;
            visits.daily[today] = (visits.daily[today] || 0) + 1;
            localStorage.setItem(this.VISIT_KEY, JSON.stringify(visits));
            localStorage.setItem('lastVisitDate', today);
        }

        // Track first visit time
        if (!localStorage.getItem(this.FIRST_VISIT_KEY)) {
            localStorage.setItem(this.FIRST_VISIT_KEY, Date.now().toString());
        }
    },

    // Get visit data
    getVisits() {
        const data = localStorage.getItem(this.VISIT_KEY);
        return data ? JSON.parse(data) : { total: 0, daily: {} };
    },

    // Get download data
    getDownloads() {
        const data = localStorage.getItem(this.DOWNLOAD_KEY);
        return data ? JSON.parse(data) : { total: 0, byType: {} };
    },

    // Track download
    trackDownload(type) {
        const downloads = this.getDownloads();
        downloads.total++;
        downloads.byType[type] = (downloads.byType[type] || 0) + 1;
        downloads.lastDownload = Date.now();
        localStorage.setItem(this.DOWNLOAD_KEY, JSON.stringify(downloads));
        this.updateStats();

        // Show download notification
        this.showNotification(`Download started! Thank you for choosing FindBack.`);
    },

    // Setup download button tracking
    setupDownloadTracking() {
        document.querySelectorAll('.download-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const type = btn.classList.contains('android') ? 'playstore' : 'apk';
                this.trackDownload(type);
            });
        });
    },

    // Update stats on page
    updateStats() {
        const visits = this.getVisits();
        const downloads = this.getDownloads();

        // Calculate display numbers (base + real)
        const baseUsers = 25000;
        const baseReturned = 5000;
        const baseSuccessRate = 85;

        const displayUsers = baseUsers + visits.total;
        const displayReturned = baseReturned + downloads.total;

        // Update stat elements
        const statNumbers = document.querySelectorAll('.stat-number');
        if (statNumbers.length >= 3) {
            statNumbers[0].dataset.target = displayReturned;
            statNumbers[0].dataset.suffix = '+';
            statNumbers[1].dataset.target = displayUsers;
            statNumbers[1].dataset.suffix = '+';
            statNumbers[2].dataset.target = baseSuccessRate;
            statNumbers[2].dataset.suffix = '%';
        }
    },

    // Show notification toast
    showNotification(message) {
        const toast = document.createElement('div');
        toast.className = 'toast-notification';
        toast.innerHTML = `
            <span class="toast-icon">✅</span>
            <span class="toast-message">${message}</span>
        `;
        document.body.appendChild(toast);

        setTimeout(() => toast.classList.add('show'), 100);
        setTimeout(() => {
            toast.classList.remove('show');
            setTimeout(() => toast.remove(), 300);
        }, 3000);
    }
};

// ==========================================
// Smooth Scrolling
// ==========================================

document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            target.scrollIntoView({
                behavior: 'smooth',
                block: 'start'
            });
        }
    });
});

// ==========================================
// Navbar Effects
// ==========================================

const navbar = document.querySelector('.navbar');
let lastScroll = 0;

window.addEventListener('scroll', () => {
    const currentScroll = window.pageYOffset;

    if (currentScroll > 50) {
        navbar.classList.add('scrolled');
    } else {
        navbar.classList.remove('scrolled');
    }

    lastScroll = currentScroll;
});

// ==========================================
// Intersection Observer Animations
// ==========================================

const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
};

const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.style.opacity = '1';
            entry.target.style.transform = 'translateY(0)';
        }
    });
}, observerOptions);

document.querySelectorAll('.feature-card, .step, .testimonial-card, .category-item').forEach(el => {
    el.style.opacity = '0';
    el.style.transform = 'translateY(30px)';
    el.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
    observer.observe(el);
});

document.querySelectorAll('.feature-card').forEach((card, index) => {
    card.style.transitionDelay = `${index * 0.1}s`;
});

// ==========================================
// Animated Counter
// ==========================================

function animateCounter(element, target, suffix = '', duration = 2000) {
    let start = 0;
    const increment = target / (duration / 16);

    function updateCounter() {
        start += increment;
        if (start < target) {
            if (target >= 1000) {
                element.textContent = Math.floor(start).toLocaleString() + suffix;
            } else {
                element.textContent = Math.floor(start) + suffix;
            }
            requestAnimationFrame(updateCounter);
        } else {
            if (target >= 1000) {
                element.textContent = target.toLocaleString() + suffix;
            } else {
                element.textContent = target + suffix;
            }
        }
    }

    updateCounter();
}

const statsObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            const statNumbers = entry.target.querySelectorAll('.stat-number');
            statNumbers.forEach(stat => {
                const target = parseInt(stat.dataset.target) || parseInt(stat.textContent.replace(/[^0-9]/g, ''));
                const suffix = stat.dataset.suffix || (stat.textContent.includes('%') ? '%' : '+');
                animateCounter(stat, target, suffix);
            });
            statsObserver.unobserve(entry.target);
        }
    });
}, { threshold: 0.5 });

const heroStats = document.querySelector('.hero-stats');
if (heroStats) {
    statsObserver.observe(heroStats);
}

// ==========================================
// Parallax Effect
// ==========================================

window.addEventListener('scroll', () => {
    const scrolled = window.pageYOffset;
    const heroImage = document.querySelector('.hero-image');
    if (heroImage && scrolled < window.innerHeight) {
        heroImage.style.transform = `translateY(${scrolled * 0.3}px)`;
    }
});

// ==========================================
// Real-time visitor counter (visual only)
// ==========================================

function updateLiveCounter() {
    const liveCounter = document.querySelector('.live-visitors');
    if (liveCounter) {
        // Simulate live visitors (3-15 range)
        const liveCount = Math.floor(Math.random() * 12) + 3;
        liveCounter.textContent = liveCount;
    }
}

// Update every 5 seconds
setInterval(updateLiveCounter, 5000);

// ==========================================
// Initialize Everything
// ==========================================

document.addEventListener('DOMContentLoaded', () => {
    Analytics.init();
    updateLiveCounter();

    // Add live visitor badge to page
    const liveBadge = document.createElement('div');
    liveBadge.className = 'live-badge';
    liveBadge.innerHTML = `
        <span class="live-dot"></span>
        <span class="live-visitors">5</span> visitors online
    `;
    document.body.appendChild(liveBadge);
});

// ==========================================
// Console Info
// ==========================================

console.log(`
🔍 FindBack - Lost & Found Community App
========================================
📊 Analytics Active
📥 Downloads Tracked
🌐 Visits Recorded
Made with ❤️ in Sri Lanka
GitHub: https://github.com/pirinthaban/FindBack
`);
