// Firebase Service
const FirebaseService = {
    // Database reference
    get database() {
        return window.database || firebase.database();
    },

    // Store message listener reference
    _messageListener: null,

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
    },

    // ========== FIXED METHODS FOR CALL LOGS AND SUMMARIES ==========

    // Listen to active call logs
    listenToCallLogs(callback) {
        console.log('🔍 Setting up call log listener...');
        
        // Listen to all live calls to find the active one
        const callsRef = this.database.ref('live_calls');
        
        return callsRef.on('value', (snapshot) => {
            console.log('📡 Live calls snapshot received:', snapshot.val());
            
            if (snapshot.exists()) {
                const calls = snapshot.val();
                
                // Find the most recent active call
                let latestActiveCall = null;
                let latestTimestamp = 0;
                
                Object.entries(calls).forEach(([callId, callData]) => {
                    if (callData.status === 'active' && callData.timestamp > latestTimestamp) {
                        latestActiveCall = { id: callId, ...callData };
                        latestTimestamp = callData.timestamp;
                    }
                });
                
                if (latestActiveCall) {
                    console.log('✅ Found active call:', latestActiveCall.id);
                    
                    // Now listen to messages for this specific call
                    const messagesRef = this.database.ref(`live_calls/${latestActiveCall.id}/messages`);
                    
                    // Remove any existing message listener
                    if (this._messageListener) {
                        messagesRef.off('value', this._messageListener);
                    }
                    
                    this._messageListener = messagesRef.on('value', (msgSnapshot) => {
                        console.log('📨 Messages snapshot for call', latestActiveCall.id, ':', msgSnapshot.val());
                        
                        if (msgSnapshot.exists()) {
                            const messages = [];
                            msgSnapshot.forEach((child) => {
                                messages.push({
                                    id: child.key,
                                    ...child.val()
                                });
                            });
                            // Sort by timestamp
                            messages.sort((a, b) => a.timestamp - b.timestamp);
                            console.log('✅ Sorted messages:', messages);
                            callback({ messages, callId: latestActiveCall.id, status: 'active' });
                        } else {
                            console.log('📭 No messages yet for this call');
                            callback({ messages: [], callId: latestActiveCall.id, status: 'active' });
                        }
                    });
                } else {
                    console.log('📭 No active calls found');
                    callback({ messages: [], callId: null, status: 'inactive' });
                }
            } else {
                console.log('📭 No calls in database');
                callback({ messages: [], callId: null, status: 'inactive' });
            }
        });
    },

    // Listen to call summaries
    listenToCallSummaries(callback) {
        console.log('🔍 Setting up call summary listener...');
        
        return this.database.ref('call_summaries')
            .orderByChild('timestamp')
            .limitToLast(1)
            .on('value', (snapshot) => {
                console.log('📡 Summary snapshot received:', snapshot.val());
                
                if (snapshot.exists()) {
                    let latestSummary = null;
                    let latestTimestamp = 0;
                    
                    snapshot.forEach((child) => {
                        const summary = child.val();
                        const summaryTime = summary.timestamp ? new Date(summary.timestamp).getTime() : 0;
                        if (summaryTime > latestTimestamp) {
                            latestSummary = summary;
                            latestTimestamp = summaryTime;
                        }
                    });
                    
                    console.log('✅ Latest summary:', latestSummary);
                    callback(latestSummary);
                } else {
                    console.log('📭 No summaries found');
                    callback(null);
                }
            });
    },

    // Stop listening to calls (cleanup)
    stopListeningToCalls(listener) {
        if (listener) {
            this.database.ref('live_calls').off('value', listener);
        }
        if (this._messageListener) {
            this.database.ref().off('value', this._messageListener);
            this._messageListener = null;
        }
    }
};

window.FirebaseService = FirebaseService;
console.log('✅ FirebaseService loaded');