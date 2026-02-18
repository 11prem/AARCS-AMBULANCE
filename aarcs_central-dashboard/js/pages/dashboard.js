// Dashboard Page Module
const DashboardPage = {
    // DOM elements
    liveTripPage: document.getElementById('liveTripPage'),
    ambulanceInfoEl: document.getElementById('ambulanceInfo'),
    patientDetailsEl: document.getElementById('patientDetails'),
    timelineItemsEl: document.getElementById('timelineItems'),
    policeInfoEl: document.getElementById('policeInfo'),
    clearanceStatusEl: document.getElementById('clearanceStatus'),
    ambulanceStatus: document.getElementById('ambulanceStatus'),
    ambulanceUpdateTime: document.getElementById('ambulanceUpdateTime'),
    policeUpdateTime: document.getElementById('policeUpdateTime'),
    
    // NEW: Call Log elements
    callLogContainer: document.getElementById('callLogContainer'),
    callStatus: document.getElementById('callStatus'),
    callStatusText: document.getElementById('callStatusText'),
    callLogUpdateTime: document.getElementById('callLogUpdateTime'),
    callSummarySection: document.getElementById('callSummarySection'),
    summaryContent: document.getElementById('summaryContent'),
    summaryUpdateTime: document.getElementById('summaryUpdateTime'),
    viewFullSummaryBtn: document.getElementById('viewFullSummaryBtn'),
    dispatchFromSummaryBtn: document.getElementById('dispatchFromSummaryBtn'),
    
    // Current data
    currentAmbulanceRequest: null,
    currentPoliceAlert: null,
    
    // NEW: Call log data
    currentCallId: null,
    currentCallSummary: null,
    
    // Login timestamp
    loginTimestamp: null,
    
    // Listeners
    ambulanceListener: null,
    policeListener: null,
    // NEW: Call log listeners
    callLogListener: null,
    callSummaryListener: null,
    timer: null,

    // Initialize
    init() {
        console.log('📊 DashboardPage initializing...');
        if (!this.liveTripPage) return;
        
        // Store login timestamp
        this.loginTimestamp = new Date();
        
        this.liveTripPage.classList.remove('active');
        this.liveTripPage.style.display = 'none';
        
        this.startRealTimeUpdates();
        this.loadSampleData();
        
        // Initialize call log features
        this.initCallLogFeatures();
        
        // Set initial timestamps to login time
        this.setInitialTimestamps();
    },

    // Set initial timestamps to login time
    setInitialTimestamps() {
        const loginTimeStr = this.loginTimestamp.toLocaleTimeString([], { 
            hour: '2-digit', 
            minute: '2-digit', 
            second: '2-digit' 
        });
        
        if (this.ambulanceUpdateTime) {
            this.ambulanceUpdateTime.textContent = loginTimeStr;
        }
        
        if (this.policeUpdateTime) {
            this.policeUpdateTime.textContent = loginTimeStr;
        }
        
        if (this.callLogUpdateTime) {
            this.callLogUpdateTime.textContent = loginTimeStr;
        }
        
        if (this.summaryUpdateTime) {
            this.summaryUpdateTime.textContent = loginTimeStr;
        }
    },

    // Start real-time updates
    startRealTimeUpdates() {
        if (window.FirebaseService) {
            this.ambulanceListener = window.FirebaseService.listenToEmergencyRequests((requests) => {
                if (Object.keys(requests).length > 0) {
                    const latestRequestKey = Object.keys(requests).sort((a, b) => 
                        requests[b].timestamp - requests[a].timestamp
                    )[0];
                    
                    this.currentAmbulanceRequest = {
                        id: latestRequestKey,
                        ...requests[latestRequestKey]
                    };
                    
                    this.updateAmbulanceInfo();
                    this.updatePatientInfo();
                    this.updateTimeline();
                    
                    // Keep login timestamp - do not update
                }
            });
            
            this.policeListener = window.FirebaseService.listenToTrafficAlerts((alerts) => {
                if (Object.keys(alerts).length > 0) {
                    const latestAlertKey = Object.keys(alerts).sort((a, b) => 
                        alerts[b].timestamp - alerts[a].timestamp
                    )[0];
                    
                    this.currentPoliceAlert = {
                        id: latestAlertKey,
                        ...alerts[latestAlertKey]
                    };
                    
                    this.updatePoliceInfo();
                    this.updateClearanceStatus();
                    
                    // Keep login timestamp - do not update
                }
            });
        }
        
        // Timer removed to prevent continuous updates
    },

    // Load sample data for demo
    loadSampleData() {
        if (!this.currentAmbulanceRequest) {
            const now = Date.now();
            this.currentAmbulanceRequest = {
                ambulanceId: 'AMB-001',
                currentLocation: 'Near City Mall',
                destination: 'City General Hospital',
                distance: '4.2 km',
                priority: 1,
                priorityLabel: 'HIGH',
                status: 'accepted',
                timestamp: now - 10 * 60000,
                description: 'Car accident with chest pain'
            };
            
            this.currentPoliceAlert = {
                ambulanceId: 'AMB-001',
                currentLocation: 'Highway Junction',
                destination: 'City General Hospital',
                acknowledged: true,
                acknowledgedBy: 'TP-2024-156',
                acknowledgedAt: now - 7.5 * 60000,
                timestamp: now - 8 * 60000,
                status: 'acknowledged',
                priority: 1,
                priorityLabel: 'HIGH'
            };
            
            this.updateAmbulanceInfo();
            this.updatePatientInfo();
            this.updateTimeline();
            this.updatePoliceInfo();
            this.updateClearanceStatus();
            
            // Keep login timestamp - do not update
        }
    },

    // Update ambulance information
    updateAmbulanceInfo() {
        if (!this.ambulanceInfoEl || !this.currentAmbulanceRequest) return;
        
        const request = this.currentAmbulanceRequest;
        
        if (this.ambulanceStatus) {
            let statusClass = 'status-active';
            let statusText = 'EN ROUTE';
            this.ambulanceStatus.className = `status-badge ${statusClass}`;
            this.ambulanceStatus.innerHTML = `<i class="fas fa-exclamation-triangle"></i> ${statusText}`;
        }
        
        const etaTime = request.timestamp ? new Date(request.timestamp + 15 * 60000) : new Date(Date.now() + 15 * 60000);
        const etaString = etaTime.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        
        this.ambulanceInfoEl.innerHTML = `
            <div class="info-card">
                <div class="info-card-header">
                    <i class="fas fa-id-badge"></i>
                    <span>Ambulance ID</span>
                </div>
                <div class="info-card-value">${request.ambulanceId || 'AMB-001'}</div>
            </div>
            <div class="info-card">
                <div class="info-card-header">
                    <i class="fas fa-map-marker-alt"></i>
                    <span>Current Location</span>
                </div>
                <div class="info-card-value">
                    ${request.currentLocation || 'En route to patient'}
                    <span class="speed-indicator">
                        <i class="fas fa-tachometer-alt"></i>
                        <span class="speed-value">65 km/h</span>
                    </span>
                </div>
            </div>
            <div class="info-card">
                <div class="info-card-header">
                    <i class="fas fa-hospital"></i>
                    <span>Destination</span>
                </div>
                <div class="info-card-value">${request.destination || 'City General Hospital'}</div>
            </div>
            <div class="info-card">
                <div class="info-card-header">
                    <i class="fas fa-clock"></i>
                    <span>ETA to Patient</span>
                </div>
                <div class="info-card-value">${etaString}</div>
            </div>
            <div class="info-card">
                <div class="info-card-header">
                    <i class="fas fa-road"></i>
                    <span>Distance</span>
                </div>
                <div class="info-card-value">${request.distance || '4.2 km'}</div>
            </div>
            <div class="info-card">
                <div class="info-card-header">
                    <i class="fas fa-exclamation-triangle"></i>
                    <span>Priority</span>
                </div>
                <div class="info-card-value">
                    <span class="history-priority ${window.Helpers.getPriorityClass(request.priority)}">
                        ${request.priorityLabel || 'HIGH'}
                    </span>
                </div>
            </div>
        `;
    },

    // Update patient information
    updatePatientInfo() {
        if (!this.patientDetailsEl) return;
        const request = this.currentAmbulanceRequest || {};
        
        this.patientDetailsEl.innerHTML = `
            <div class="info-grid">
                <div class="info-card">
                    <div class="info-card-header">
                        <i class="fas fa-car-crash"></i>
                        <span>Incident Type</span>
                    </div>
                    <div class="info-card-value">${request.description || 'Car collision on highway, front impact'}</div>
                </div>
                <div class="info-card">
                    <div class="info-card-header">
                        <i class="fas fa-user-injured"></i>
                        <span>Patient Condition</span>
                    </div>
                    <div class="info-card-value">Conscious with chest pain, possible fractures</div>
                </div>
                <div class="info-card">
                    <div class="info-card-header">
                        <i class="fas fa-location-dot"></i>
                        <span>Incident Location</span>
                    </div>
                    <div class="info-card-value">Highway Exit 5, near signal</div>
                </div>
                <div class="info-card">
                    <div class="info-card-header">
                        <i class="fas fa-exclamation-circle"></i>
                        <span>Severity Level</span>
                    </div>
                    <div class="info-card-value">
                        <span class="history-priority ${window.Helpers.getPriorityClass(request.priority)}">
                            ${request.priorityLabel === 'CRITICAL' ? 'Critical' : 'Moderate to Severe'}
                        </span>
                    </div>
                </div>
            </div>
        `;
    },

    // Update timeline
    updateTimeline() {
        if (!this.timelineItemsEl) return;
        
        const request = this.currentAmbulanceRequest || {};
        const now = Date.now();
        const requestTime = request.timestamp || (now - 20 * 60000);
        const etaToPatient = requestTime + 15 * 60000;
        const pickupTime = requestTime + 20 * 60000;
        const hospitalArrival = pickupTime + 25 * 60000;
        
        this.timelineItemsEl.innerHTML = `
            <div class="timeline-item">
                <div class="timeline-marker active">
                    <i class="fas fa-phone-alt"></i>
                </div>
                <div class="timeline-content">
                    <h4>Emergency Call Received <span class="live-indicator"><span class="live-dot"></span> LIVE</span></h4>
                    <p>${new Date(requestTime).toLocaleTimeString()} - 108 emergency services</p>
                </div>
            </div>
            <div class="timeline-item">
                <div class="timeline-marker active">
                    <i class="fas fa-ambulance"></i>
                </div>
                <div class="timeline-content">
                    <h4>Ambulance Assigned</h4>
                    <p>${new Date(requestTime).toLocaleTimeString()} - ${request.ambulanceId || 'AMB-001'} dispatched</p>
                </div>
            </div>
            <div class="timeline-item">
                <div class="timeline-marker ${now > etaToPatient ? 'active' : 'pending'}">
                    <i class="fas fa-location-dot"></i>
                </div>
                <div class="timeline-content">
                    <h4>ETA to Patient Location</h4>
                    <p>${new Date(etaToPatient).toLocaleTimeString()} - ${request.distance || '4.2 km'} away</p>
                </div>
            </div>
            <div class="timeline-item">
                <div class="timeline-marker pending">
                    <i class="fas fa-user-check"></i>
                </div>
                <div class="timeline-content">
                    <h4>Patient Pickup</h4>
                    <p>${new Date(pickupTime).toLocaleTimeString()} - Estimated pickup time</p>
                </div>
            </div>
            <div class="timeline-item">
                <div class="timeline-marker pending">
                    <i class="fas fa-flag-checkered"></i>
                </div>
                <div class="timeline-content">
                    <h4>Hospital Arrival</h4>
                    <p>${new Date(hospitalArrival).toLocaleTimeString()} - Estimated arrival</p>
                </div>
            </div>
        `;
    },

    // Update police information
    updatePoliceInfo() {
        if (!this.policeInfoEl) return;
        const alert = this.currentPoliceAlert || {};
        
        this.policeInfoEl.innerHTML = `
            <div class="info-card">
                <div class="info-card-header">
                    <i class="fas fa-id-badge"></i>
                    <span>Assigned Officer</span>
                </div>
                <div class="info-card-value">${alert.acknowledgedBy || 'TP-2024-156'}</div>
            </div>
            <div class="info-card">
                <div class="info-card-header">
                    <i class="fas fa-map-marker-alt"></i>
                    <span>Clearance Location</span>
                </div>
                <div class="info-card-value">${alert.currentLocation || 'Highway Junction'}</div>
            </div>
            <div class="info-card">
                <div class="info-card-header">
                    <i class="fas fa-ambulance"></i>
                    <span>Assisting Ambulance</span>
                </div>
                <div class="info-card-value">${alert.ambulanceId || 'AMB-001'}</div>
            </div>
            <div class="info-card">
                <div class="info-card-header">
                    <i class="fas fa-clock"></i>
                    <span>Response Time</span>
                </div>
                <div class="info-card-value">${alert.acknowledgedAt ? '2 min 15 sec' : 'Awaiting response'}</div>
            </div>
            <div class="info-card">
                <div class="info-card-header">
                    <i class="fas fa-traffic-light"></i>
                    <span>Clearance Status</span>
                </div>
                <div class="info-card-value">
                    <span class="history-status ${alert.acknowledged ? 'status-completed' : 'status-pending'}">
                        ${alert.acknowledged ? 'CLEARED' : 'PENDING'}
                    </span>
                </div>
            </div>
            <div class="info-card">
                <div class="info-card-header">
                    <i class="fas fa-exclamation-circle"></i>
                    <span>Priority Level</span>
                </div>
                <div class="info-card-value">
                    <span class="history-priority ${window.Helpers.getPriorityClass(alert.priority)}">
                        ${alert.priorityLabel || 'HIGH'}
                    </span>
                </div>
            </div>
        `;
    },

    // Update clearance status
    updateClearanceStatus() {
        if (!this.clearanceStatusEl) return;
        const alert = this.currentPoliceAlert || {};
        const isAcknowledged = alert.acknowledged === true;
        
        this.clearanceStatusEl.innerHTML = `
            <div class="timeline-item">
                <div class="timeline-marker ${isAcknowledged ? 'active' : 'pending'}">
                    <i class="fas fa-bell"></i>
                </div>
                <div class="timeline-content">
                    <h4>Traffic Clearance Requested</h4>
                    <p>${new Date(alert.timestamp || Date.now()).toLocaleTimeString()} - Alert sent to traffic police</p>
                </div>
            </div>
            <div class="timeline-item">
                <div class="timeline-marker ${isAcknowledged ? 'active' : 'pending'}">
                    <i class="fas fa-check-circle"></i>
                </div>
                <div class="timeline-content">
                    <h4>Police Acknowledgment</h4>
                    <p>${isAcknowledged ? 
                        `${new Date(alert.acknowledgedAt).toLocaleTimeString()} - Officer ${alert.acknowledgedBy}` : 
                        'Awaiting response...'}</p>
                </div>
            </div>
            <div class="timeline-item">
                <div class="timeline-marker pending">
                    <i class="fas fa-traffic-light"></i>
                </div>
                <div class="timeline-content">
                    <h4>Route Cleared</h4>
                    <p>${isAcknowledged ? 
                        `${new Date(alert.acknowledgedAt + 2 * 60000).toLocaleTimeString()} - Route cleared for ambulance` : 
                        'Not yet cleared'}</p>
                </div>
            </div>
        `;
    },

    // ========== FIXED METHODS FOR CALL LOGS AND SUMMARIES ==========

    // Initialize call log features
    initCallLogFeatures() {
        console.log('📞 Initializing Call Log Features...');
        
        // Check if all required elements exist
        console.log('callLogContainer:', this.callLogContainer);
        console.log('callStatus:', this.callStatus);
        console.log('callSummarySection:', this.callSummarySection);
        
        if (window.FirebaseService) {
            console.log('✅ FirebaseService found');
            
            // Listen to call logs
            this.callLogListener = window.FirebaseService.listenToCallLogs((data) => {
                console.log('🔥 Firebase call log data received:', data);
                this.updateCallLog(data);
            });
            
            // Listen to call summaries
            this.callSummaryListener = window.FirebaseService.listenToCallSummaries((summary) => {
                console.log('🔥 Firebase summary received:', summary);
                this.updateCallSummary(summary);
            });
        } else {
            console.error('❌ FirebaseService not found!');
        }
        
        // Bind button events
        if (this.viewFullSummaryBtn) {
            this.viewFullSummaryBtn.addEventListener('click', () => {
                this.showFullSummaryModal();
            });
        }
        
        if (this.dispatchFromSummaryBtn) {
            this.dispatchFromSummaryBtn.addEventListener('click', () => {
                this.dispatchAmbulanceFromSummary();
            });
        }
    },

    // Update call log display
    updateCallLog(data) {
        console.log('📞 updateCallLog called with data:', data);
        
        if (!this.callLogContainer) {
            console.error('❌ callLogContainer not found!');
            return;
        }
        
        const { messages, callId, status } = data;
        console.log('Messages:', messages, 'CallId:', callId, 'Status:', status);
        
        this.currentCallId = callId;
        
        // Update status indicator
        if (this.callStatus && this.callStatusText) {
            const indicator = this.callStatus.querySelector('.status-indicator');
            if (status === 'active') {
                indicator.className = 'status-indicator status-active';
                this.callStatusText.textContent = 'Active call in progress';
            } else {
                indicator.className = 'status-indicator status-inactive';
                this.callStatusText.textContent = 'No active call';
            }
        }
        
        // Keep login timestamp - do not update callLogUpdateTime
        
        // Update messages
        if (messages && messages.length > 0) {
            this.callLogContainer.innerHTML = '';
            
            messages.forEach(msg => {
                const messageEl = document.createElement('div');
                messageEl.className = `call-log-message ${msg.speaker}`;
                
                const time = msg.time || new Date(msg.timestamp).toLocaleTimeString([], {
                    hour: '2-digit',
                    minute: '2-digit',
                    second: '2-digit'
                });
                
                messageEl.innerHTML = `
                    <div class="message-header ${msg.speaker}">
                        <i class="fas ${msg.speaker === 'agent' ? 'fa-robot' : 'fa-user'}"></i>
                        <span>${msg.speaker === 'agent' ? 'AI Agent' : 'Caller'}</span>
                        <span class="message-time">${time}</span>
                    </div>
                    <div class="message-bubble">${this.escapeHtml(msg.message)}</div>
                `;
                
                this.callLogContainer.appendChild(messageEl);
            });
            
            // Scroll to bottom
            this.callLogContainer.scrollTop = this.callLogContainer.scrollHeight;
        } else if (status === 'active') {
            // Active call but no messages yet
            this.callLogContainer.innerHTML = `
                <div class="empty-state">
                    <i class="fas fa-microphone"></i>
                    <h3>Call Connected</h3>
                    <p>Waiting for conversation to begin...</p>
                </div>
            `;
        } else {
            // No active call
            this.callLogContainer.innerHTML = `
                <div class="empty-state">
                    <i class="fas fa-phone-slash"></i>
                    <h3>No Active Call</h3>
                    <p>Waiting for emergency call to begin...</p>
                </div>
            `;
        }
    },

    // Update call summary display
    updateCallSummary(summary) {
        console.log('📋 updateCallSummary called with:', summary);
        
        if (!this.callSummarySection || !this.summaryContent) {
            console.error('❌ Summary elements not found!');
            return;
        }
        
        if (summary) {
            this.currentCallSummary = summary;
            this.callSummarySection.style.display = 'block';
            
            // Keep login timestamp - do not update summaryUpdateTime
            
            // Build summary HTML
            const emergencyInfo = summary.emergency_info || {};
            const ambulanceData = summary.ambulance_data || {};
            const callSummary = summary.call_summary || {};
            
            // Determine priority class
            const urgency = (emergencyInfo.urgency || callSummary.urgency || 'normal').toLowerCase();
            let priorityClass = 'priority-medium';
            if (urgency === 'critical' || urgency === 'urgent') priorityClass = 'priority-critical';
            else if (urgency === 'high') priorityClass = 'priority-high';
            else if (urgency === 'low') priorityClass = 'priority-low';
            
            let priorityText = urgency.toUpperCase();
            if (urgency === 'urgent') priorityText = 'URGENT';
            
            this.summaryContent.innerHTML = `
                <div class="summary-grid">
                    <div class="summary-item">
                        <div class="summary-item-label">
                            <i class="fas fa-exclamation-triangle"></i>
                            <span>Emergency Type</span>
                        </div>
                        <div class="summary-item-value">
                            ${emergencyInfo.type || callSummary.emergency_type || 'Unknown'}
                        </div>
                    </div>
                    
                    <div class="summary-item">
                        <div class="summary-item-label">
                            <i class="fas fa-flag"></i>
                            <span>Priority</span>
                        </div>
                        <div class="summary-item-value">
                            <span class="priority-badge ${priorityClass}">${priorityText}</span>
                        </div>
                    </div>
                    
                    <div class="summary-item full-width">
                        <div class="summary-item-label">
                            <i class="fas fa-map-marker-alt"></i>
                            <span>Location</span>
                        </div>
                        <div class="summary-item-value">
                            ${emergencyInfo.location || callSummary.location || 'Unknown'}
                        </div>
                        ${emergencyInfo.location_details ? `
                            <div class="summary-location-details">
                                <div>${emergencyInfo.location_details.address || ''}</div>
                                <div class="coordinates">
                                    ${emergencyInfo.location_details.latitude ? 
                                        `${emergencyInfo.location_details.latitude.toFixed(4)}, ${emergencyInfo.location_details.longitude.toFixed(4)}` : 
                                        callSummary.location_details?.coordinates || ''}
                                </div>
                            </div>
                        ` : ''}
                    </div>
                    
                    <div class="summary-item">
                        <div class="summary-item-label">
                            <i class="fas fa-user-injured"></i>
                            <span>Injuries</span>
                        </div>
                        <div class="summary-item-value">
                            ${callSummary.injuries === true ? 'Yes' : 
                              callSummary.injuries === false ? 'No' : 
                              emergencyInfo.injuries ? 'Yes' : 'Unknown'}
                            ${callSummary.injury_count ? ` (${callSummary.injury_count} persons)` : ''}
                        </div>
                    </div>
                    
                    <div class="summary-item">
                        <div class="summary-item-label">
                            <i class="fas fa-shield-alt"></i>
                            <span>Currently Safe</span>
                        </div>
                        <div class="summary-item-value">
                            ${callSummary.is_safe === true ? 'Yes' : 
                              callSummary.is_safe === false ? 'No' : 'Unknown'}
                        </div>
                    </div>
                    
                    ${ambulanceData.id ? `
                    <div class="summary-item full-width">
                        <div class="summary-item-label">
                            <i class="fas fa-ambulance"></i>
                            <span>Ambulance Status</span>
                        </div>
                        <div class="summary-item-value">
                            ${ambulanceData.id} - ETA: ${ambulanceData.eta_minutes} minutes
                            ${ambulanceData.distance_km ? ` (${ambulanceData.distance_km.toFixed(1)} km away)` : ''}
                        </div>
                    </div>
                    ` : ''}
                </div>
                
                ${summary.conversation && summary.conversation.length > 0 ? `
                <div class="conversation-summary">
                    <h4><i class="fas fa-comments"></i> Recent Conversation</h4>
                    <div class="conversation-preview">
                        ${summary.conversation.slice(-5).map(msg => `
                            <div class="conversation-line">
                                <span class="speaker ${msg.speaker}">${msg.speaker === 'ai' ? 'AI' : 'Caller'}</span>
                                <span class="message">${this.escapeHtml(msg.message)}</span>
                                <span class="time">${msg.time || ''}</span>
                            </div>
                        `).join('')}
                    </div>
                </div>
                ` : ''}
            `;
        } else {
            this.callSummarySection.style.display = 'none';
            this.currentCallSummary = null;
        }
    },

    // Helper: Escape HTML to prevent XSS
    escapeHtml(text) {
        if (!text) return '';
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    },

    // Show full summary modal (placeholder)
    showFullSummaryModal() {
        if (this.currentCallSummary) {
            console.log('Full Summary:', this.currentCallSummary);
            
            if (window.Helpers) {
                window.Helpers.showNotification('Full summary view coming soon!', 'info');
            }
        }
    },

    // Dispatch ambulance from summary
    dispatchAmbulanceFromSummary() {
        if (this.currentCallSummary) {
            const summary = this.currentCallSummary;
            const location = summary.emergency_info?.location || summary.call_summary?.location;
            
            if (location) {
                console.log('Dispatching ambulance to:', location);
                
                if (window.Helpers) {
                    window.Helpers.showNotification(`Ambulance dispatched to ${location}`, 'success');
                }
            } else {
                if (window.Helpers) {
                    window.Helpers.showNotification('No location available for dispatch', 'error');
                }
            }
        }
    },

    // Show dashboard
    show() {
        if (this.liveTripPage) {
            this.liveTripPage.classList.add('active');
            this.liveTripPage.style.display = 'block';
            this.loadSampleData();
        }
    },

    // Hide dashboard
    hide() {
        if (this.liveTripPage) {
            this.liveTripPage.classList.remove('active');
            this.liveTripPage.style.display = 'none';
        }
    }
};

window.DashboardPage = DashboardPage;
console.log('✅ DashboardPage loaded');