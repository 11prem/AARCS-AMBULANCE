// Login Page Module - FIXED: Forces login on first run
const LoginPage = {
    // DOM elements
    loginPage: document.getElementById('loginPage'),
    dashboard: document.getElementById('dashboard'),
    loginBtn: document.getElementById('loginBtn'),
    username: document.getElementById('username'),
    password: document.getElementById('password'),
    errorMessage: document.getElementById('errorMessage'),
    currentUser: document.getElementById('currentUser'),

    // Initialize
    init() {
        console.log('📱 LoginPage initializing...');
        
        // CRITICAL FIX: ALWAYS start with login page visible on fresh load
        // Clear any existing session to force login on first run
        if (!sessionStorage.getItem('aarcs_initialized')) {
            localStorage.removeItem('aarcs_user');
            sessionStorage.setItem('aarcs_initialized', 'true');
        }
        
        // Set initial visibility - login visible, dashboard hidden
        if (this.loginPage) {
            this.loginPage.style.display = 'flex';
            this.loginPage.style.visibility = 'visible';
            this.loginPage.style.opacity = '1';
        }
        
        if (this.dashboard) {
            this.dashboard.style.display = 'none';
            this.dashboard.style.visibility = 'hidden';
            this.dashboard.style.opacity = '0';
        }
        
        this.bindEvents();
        this.checkSession();
    },

    // Bind events
    bindEvents() {
        if (this.loginBtn) {
            // Remove existing listeners to prevent duplicates
            const newBtn = this.loginBtn.cloneNode(true);
            this.loginBtn.parentNode.replaceChild(newBtn, this.loginBtn);
            this.loginBtn = newBtn;
            
            this.loginBtn.addEventListener('click', (e) => {
                e.preventDefault();
                this.handleLogin();
            });
        }
        
        if (this.password) {
            this.password.addEventListener('keypress', (e) => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    this.handleLogin();
                }
            });
        }
        
        if (this.username) {
            this.username.addEventListener('keypress', (e) => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    this.handleLogin();
                }
            });
        }
    },

    // Check existing session
    checkSession() {
        const savedUser = localStorage.getItem('aarcs_user');
        
        // ONLY auto-login if there's a saved user AND we're not on first run
        // First run is handled above by clearing localStorage
        if (savedUser && sessionStorage.getItem('aarcs_authenticated') === 'true') {
            console.log('🔐 Auto-login with:', savedUser);
            
            // Update user info
            const userElements = document.querySelectorAll('.user-name, #currentUser');
            userElements.forEach(el => {
                if (el) el.textContent = savedUser;
            });
            
            // Show dashboard, hide login
            if (this.loginPage) {
                this.loginPage.style.display = 'none';
                this.loginPage.style.visibility = 'hidden';
                this.loginPage.style.opacity = '0';
            }
            
            if (this.dashboard) {
                this.dashboard.style.display = 'block';
                this.dashboard.style.visibility = 'visible';
                this.dashboard.style.opacity = '1';
            }
            
            // Initialize dashboard
            setTimeout(() => {
                if (window.DashboardPage) {
                    window.DashboardPage.init();
                    window.DashboardPage.show();
                }
                if (window.App) {
                    window.App.showLiveTrip();
                }
            }, 100);
            
            return true;
        }
        
        // No valid session - ensure login is visible
        if (this.loginPage) {
            this.loginPage.style.display = 'flex';
            this.loginPage.style.visibility = 'visible';
            this.loginPage.style.opacity = '1';
        }
        
        if (this.dashboard) {
            this.dashboard.style.display = 'none';
            this.dashboard.style.visibility = 'hidden';
            this.dashboard.style.opacity = '0';
        }
        
        return false;
    },

    // Handle login
    handleLogin() {
        const username = this.username?.value.trim() || 'admin';
        const password = this.password?.value.trim() || 'admin';
        
        if (username && password) {
            // Store session
            localStorage.setItem('aarcs_user', username);
            sessionStorage.setItem('aarcs_authenticated', 'true');
            
            // Update user info
            const userElements = document.querySelectorAll('.user-name, #currentUser');
            userElements.forEach(el => {
                if (el) el.textContent = username;
            });
            
            // Hide login, show dashboard
            if (this.loginPage) {
                this.loginPage.style.display = 'none';
                this.loginPage.style.visibility = 'hidden';
                this.loginPage.style.opacity = '0';
            }
            
            if (this.dashboard) {
                this.dashboard.style.display = 'block';
                this.dashboard.style.visibility = 'visible';
                this.dashboard.style.opacity = '1';
            }
            
            // Hide error message
            if (this.errorMessage) {
                this.errorMessage.style.display = 'none';
            }
            
            // Show notification
            if (window.Helpers) {
                window.Helpers.showNotification(`Welcome back, ${username}!`, 'success');
            }
            
            // Initialize and show dashboard
            setTimeout(() => {
                if (window.DashboardPage) {
                    window.DashboardPage.init();
                    window.DashboardPage.show();
                }
                if (window.App) {
                    window.App.showLiveTrip();
                }
            }, 100);
        } else {
            if (this.errorMessage) {
                this.errorMessage.style.display = 'flex';
                setTimeout(() => {
                    this.errorMessage.style.display = 'none';
                }, 3000);
            }
        }
    },

    // Handle logout
    logout() {
        // Clear all storage
        localStorage.removeItem('aarcs_user');
        sessionStorage.removeItem('aarcs_authenticated');
        sessionStorage.removeItem('aarcs_initialized');
        
        // Hide dashboard
        if (this.dashboard) {
            this.dashboard.style.display = 'none';
            this.dashboard.style.visibility = 'hidden';
            this.dashboard.style.opacity = '0';
        }
        
        // Show login
        if (this.loginPage) {
            this.loginPage.style.display = 'flex';
            this.loginPage.style.visibility = 'visible';
            this.loginPage.style.opacity = '1';
        }
        
        // Clear form
        if (this.username) this.username.value = 'admin';
        if (this.password) this.password.value = 'admin';
    }
};

window.LoginPage = LoginPage;
console.log('✅ LoginPage loaded');