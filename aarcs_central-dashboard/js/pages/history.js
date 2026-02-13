// History Page Module
const HistoryPage = {
    // DOM elements
    historyPage: document.getElementById('historyPage'),
    historyList: document.getElementById('historyListContainer'),
    historyStats: document.getElementById('historyStats'),
    statusFilter: document.getElementById('statusFilter'),
    priorityFilter: document.getElementById('priorityFilter'),
    searchInput: document.getElementById('searchInput'),
    
    // Filters
    filters: {
        status: 'all',
        priority: 'all',
        search: ''
    },

    // Initialize
    init() {
        console.log('📋 HistoryPage initializing...');
        if (!this.historyPage) return;
        
        this.historyPage.classList.remove('active');
        this.historyPage.style.display = 'none';
        
        this.bindEvents();
    },

    // Bind events
    bindEvents() {
        if (this.statusFilter) {
            this.statusFilter.addEventListener('change', (e) => {
                this.filters.status = e.target.value;
                this.loadData();
            });
        }
        
        if (this.priorityFilter) {
            this.priorityFilter.addEventListener('change', (e) => {
                this.filters.priority = e.target.value;
                this.loadData();
            });
        }
        
        if (this.searchInput) {
            const debouncedSearch = window.Helpers.debounce(() => {
                this.filters.search = this.searchInput.value.toLowerCase();
                this.loadData();
            }, 500);
            
            this.searchInput.addEventListener('input', debouncedSearch);
        }
    },

    // Load history data
    async loadData() {
        if (!this.historyList) return;
        
        try {
            this.historyList.innerHTML = `
                <div class="loading-state">
                    <div class="loading-spinner"></div>
                    <p>Loading trip history...</p>
                </div>
            `;
            
            let historyData = [];
            if (window.FirebaseService) {
                historyData = await window.FirebaseService.getHistoryData(this.filters);
            }
            
            if (historyData.length === 0) {
                historyData = this.getSampleData();
                const filtered = historyData.filter(item => {
                    let include = true;
                    if (this.filters.status !== 'all' && item.status !== this.filters.status) include = false;
                    if (this.filters.priority !== 'all' && item.priority !== parseInt(this.filters.priority)) include = false;
                    if (this.filters.search) {
                        const searchLower = this.filters.search.toLowerCase();
                        if (!item.ambulanceId.toLowerCase().includes(searchLower) && 
                            !item.destination.toLowerCase().includes(searchLower)) {
                            include = false;
                        }
                    }
                    return include;
                });
                historyData = filtered;
            }
            
            this.renderList(historyData);
            this.renderStats(historyData);
            
        } catch (error) {
            console.error('Error loading history:', error);
            this.historyList.innerHTML = `
                <div class="empty-state">
                    <i class="fas fa-exclamation-triangle"></i>
                    <h3>Failed to Load Data</h3>
                    <p>Unable to load trip history. Please try again.</p>
                </div>
            `;
        }
    },

    // Get sample data for demo
    getSampleData() {
        const now = Date.now();
        const oneDay = 24 * 60 * 60 * 1000;
        
        return [
            {
                requestId: 'REQ-001',
                ambulanceId: 'AMB-001',
                currentLocation: 'Near City Mall',
                destination: 'City General Hospital',
                status: 'completed',
                timestamp: now - 2 * oneDay,
                accepted_at: now - 2 * oneDay + 2 * 60000,
                completed_at: now - 2 * oneDay + 45 * 60000,
                eta: '15 min',
                distance: '4.2 km',
                priority: 1,
                priorityLabel: 'HIGH',
                description: 'Car accident with chest pain',
                trafficClearanceRequested: true
            },
            {
                requestId: 'REQ-002',
                ambulanceId: 'AMB-003',
                currentLocation: 'Near Central Station',
                destination: 'Central Trauma Center',
                status: 'completed',
                timestamp: now - 3 * oneDay,
                accepted_at: now - 3 * oneDay + 3 * 60000,
                completed_at: now - 3 * oneDay + 52 * 60000,
                eta: '18 min',
                distance: '5.7 km',
                priority: 0,
                priorityLabel: 'CRITICAL',
                description: 'Heart attack, patient unconscious',
                trafficClearanceRequested: true
            },
            {
                requestId: 'REQ-003',
                ambulanceId: 'AMB-005',
                currentLocation: 'Near North Bridge',
                destination: 'Northside Medical Center',
                status: 'completed',
                timestamp: now - 5 * oneDay,
                accepted_at: now - 5 * oneDay + 4 * 60000,
                completed_at: now - 5 * oneDay + 38 * 60000,
                eta: '12 min',
                distance: '3.8 km',
                priority: 2,
                priorityLabel: 'MEDIUM',
                description: 'Fractured leg from fall',
                trafficClearanceRequested: false
            }
        ];
    },

    // Render history list
    renderList(historyData) {
        if (!this.historyList) return;
        
        if (!historyData || historyData.length === 0) {
            this.historyList.innerHTML = `
                <div class="empty-state">
                    <i class="fas fa-history"></i>
                    <h3>No Trips Found</h3>
                    <p>${this.filters.status !== 'all' || this.filters.priority !== 'all' || this.filters.search ? 
                        'No trips match your filters' : 
                        'No completed trips yet'}</p>
                </div>
            `;
            return;
        }
        
        this.historyList.innerHTML = '';
        
        historyData.forEach(item => {
            const card = window.HistoryCard.render(item);
            this.historyList.appendChild(card);
        });
    },

    // Render statistics
    renderStats(historyData) {
        if (!this.historyStats) return;
        
        const totalTrips = historyData.length;
        const completedTrips = historyData.filter(t => t.status === 'completed').length;
        const criticalTrips = historyData.filter(t => t.priority === 0).length;
        
        const totalDistance = historyData
            .map(t => {
                const distance = t.distance?.toString() || '0';
                const num = parseFloat(distance.replace(/[^0-9.]/g, ''));
                return isNaN(num) ? 0 : num;
            })
            .reduce((a, b) => a + b, 0)
            .toFixed(1);
        
        this.historyStats.innerHTML = `
            <div class="stat-card">
                <div class="stat-icon blue">
                    <i class="fas fa-ambulance"></i>
                </div>
                <div class="stat-info">
                    <h4>Total Trips</h4>
                    <div>
                        <span class="stat-number">${totalTrips}</span>
                    </div>
                </div>
            </div>
            <div class="stat-card">
                <div class="stat-icon green">
                    <i class="fas fa-check-circle"></i>
                </div>
                <div class="stat-info">
                    <h4>Completed</h4>
                    <div>
                        <span class="stat-number">${completedTrips}</span>
                        <span class="stat-label">${totalTrips ? Math.round(completedTrips / totalTrips * 100) : 0}%</span>
                    </div>
                </div>
            </div>
            <div class="stat-card">
                <div class="stat-icon red">
                    <i class="fas fa-exclamation-triangle"></i>
                </div>
                <div class="stat-info">
                    <h4>Critical Cases</h4>
                    <div>
                        <span class="stat-number">${criticalTrips}</span>
                    </div>
                </div>
            </div>
            <div class="stat-card">
                <div class="stat-icon" style="background: #e0f2fe; color: #0284c7;">
                    <i class="fas fa-route"></i>
                </div>
                <div class="stat-info">
                    <h4>Total Distance</h4>
                    <div>
                        <span class="stat-number">${totalDistance}</span>
                        <span class="stat-label">km</span>
                    </div>
                </div>
            </div>
        `;
    },

    // Refresh data
    refresh() {
        this.loadData();
    },

    // Show history page
    show() {
        if (this.historyPage) {
            this.historyPage.classList.add('active');
            this.historyPage.style.display = 'block';
            this.loadData();
        }
    },

    // Hide history page
    hide() {
        if (this.historyPage) {
            this.historyPage.classList.remove('active');
            this.historyPage.style.display = 'none';
        }
    }
};

window.HistoryPage = HistoryPage;
console.log('✅ HistoryPage loaded');