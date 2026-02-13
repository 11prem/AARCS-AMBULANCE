// Firebase Service
const FirebaseService = {
    // Database reference
    get database() {
        return window.database || firebase.database();
    },

    // Get all history data
    async getHistoryData(filters = {}) {
        try {
            const snapshot = await this.database.ref('emergency_requests').once('value');
            
            if (snapshot.exists()) {
                const requests = snapshot.val();
                return this.filterHistoryData(requests, filters);
            }
            return [];
        } catch (error) {
            console.error('Error fetching history:', error);
            return [];
        }
    },

    // Filter history data
    filterHistoryData(requests, filters) {
        const historyList = [];
        
        Object.entries(requests || {}).forEach(([key, request]) => {
            const status = request.status || '';
            
            if (['completed', 'accepted', 'cancelled'].includes(status)) {
                const historyItem = {
                    requestId: key,
                    ambulanceId: request.ambulanceId || 'Unknown',
                    currentLocation: request.currentLocation || 'Unknown',
                    destination: request.destination || 'Unknown Hospital',
                    status: status,
                    timestamp: request.timestamp || 0,
                    accepted_at: request.accepted_at || 0,
                    completed_at: request.completed_at || 0,
                    eta: request.eta || 'N/A',
                    distance: request.distance || 'N/A',
                    priority: request.priority || 3,
                    priorityLabel: request.priorityLabel || 'MEDIUM',
                    description: request.description || '',
                    trafficClearanceRequested: request.trafficClearanceRequested || false
                };

                let include = true;
                
                if (filters.status && filters.status !== 'all' && historyItem.status !== filters.status) {
                    include = false;
                }
                
                if (filters.priority && filters.priority !== 'all' && 
                    historyItem.priority !== parseInt(filters.priority)) {
                    include = false;
                }
                
                if (filters.search) {
                    const searchLower = filters.search.toLowerCase();
                    if (!historyItem.ambulanceId.toLowerCase().includes(searchLower) && 
                        !historyItem.destination.toLowerCase().includes(searchLower)) {
                        include = false;
                    }
                }

                if (include) {
                    historyList.push(historyItem);
                }
            }
        });

        return historyList.sort((a, b) => b.timestamp - a.timestamp);
    },

    // Listen to emergency requests
    listenToEmergencyRequests(callback) {
        return this.database.ref('emergency_requests')
            .orderByChild('timestamp')
            .limitToLast(1)
            .on('value', (snapshot) => {
                if (snapshot.exists()) {
                    const requests = {};
                    snapshot.forEach((child) => {
                        requests[child.key] = child.val();
                    });
                    callback(requests);
                } else {
                    callback({});
                }
            });
    },

    // Listen to traffic alerts
    listenToTrafficAlerts(callback) {
        return this.database.ref('traffic_clearance_alerts')
            .orderByChild('timestamp')
            .limitToLast(1)
            .on('value', (snapshot) => {
                if (snapshot.exists()) {
                    const alerts = {};
                    snapshot.forEach((child) => {
                        alerts[child.key] = child.val();
                    });
                    callback(alerts);
                } else {
                    callback({});
                }
            });
    }
};

window.FirebaseService = FirebaseService;
console.log('✅ FirebaseService loaded');