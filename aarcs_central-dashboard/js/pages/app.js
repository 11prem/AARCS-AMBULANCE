// Main Application Controller - FIXED: Clean initialization
const App = {
    // DOM elements
    liveTripBtn: document.getElementById('liveTripBtn'),
    historyBtn: document.getElementById('historyBtn'),
    logoutBtn: document.getElementById('logoutBtn'),
    liveIndicator: document.querySelector('.live-indicator'),

    // Initialize
    init() {
        console.log('🚀 Initializing AARCS Central Dashboard...');
        
        // Clear any pending state
        if (!sessionStorage.getItem('aarcs_initialized')) {
            // First run - ensure login is visible
            const loginPage = document.getElementById('loginPage');
            const dashboard = document.getElementById('dashboard');
            
            if (loginPage) {
                loginPage.style.display = 'flex';
                loginPage.style.visibility = 'visible';
                loginPage.style.opacity = '1';
            }
            
            if (dashboard) {
                dashboard.style.display = 'none';
                dashboard.style.visibility = 'hidden';
                dashboard.style.opacity = '0';
            }
        }
        
        // Initialize LoginPage first
        if (window.LoginPage) {
            window.LoginPage.init();
        }
        
        // Initialize other modules but keep them hidden
        if (window.DashboardPage) {
            window.DashboardPage.init();
            window.DashboardPage.hide();
        }
        
        if (window.HistoryPage) {
            window.HistoryPage.init();
            window.HistoryPage.hide();
        }
        
        this.bindEvents();
        
        console.log('✅ App initialized');
    },

    // Bind events
    bindEvents() {
        if (this.liveTripBtn) {
            const newBtn = this.liveTripBtn.cloneNode(true);
            this.liveTripBtn.parentNode.replaceChild(newBtn, this.liveTripBtn);
            this.liveTripBtn = newBtn;
            
            this.liveTripBtn.addEventListener('click', (e) => {
                e.preventDefault();
                this.showLiveTrip();
            });
        }
        
        if (this.historyBtn) {
            const newBtn = this.historyBtn.cloneNode(true);
            this.historyBtn.parentNode.replaceChild(newBtn, this.historyBtn);
            this.historyBtn = newBtn;
            
            this.historyBtn.addEventListener('click', (e) => {
                e.preventDefault();
                this.showHistory();
            });
        }
        
        if (this.logoutBtn) {
            const newBtn = this.logoutBtn.cloneNode(true);
            this.logoutBtn.parentNode.replaceChild(newBtn, this.logoutBtn);
            this.logoutBtn = newBtn;
            
            this.logoutBtn.addEventListener('click', (e) => {
                e.preventDefault();
                if (window.LoginPage) window.LoginPage.logout();
            });
        }
    },

    // Show live trip page
    showLiveTrip() {
        if (this.liveTripBtn) {
            this.liveTripBtn.classList.add('active');
            if (this.liveIndicator) this.liveIndicator.style.display = 'inline-flex';
        }
        if (this.historyBtn) {
            this.historyBtn.classList.remove('active');
        }
        
        if (window.DashboardPage) {
            window.DashboardPage.show();
        }
        if (window.HistoryPage) {
            window.HistoryPage.hide();
        }
    },

    // Show history page
    showHistory() {
        if (this.liveTripBtn) {
            this.liveTripBtn.classList.remove('active');
            if (this.liveIndicator) this.liveIndicator.style.display = 'none';
        }
        if (this.historyBtn) {
            this.historyBtn.classList.add('active');
        }
        
        if (window.DashboardPage) {
            window.DashboardPage.hide();
        }
        if (window.HistoryPage) {
            window.HistoryPage.show();
        }
    }
};

// Initialize app when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.App = App;
    App.init();
});