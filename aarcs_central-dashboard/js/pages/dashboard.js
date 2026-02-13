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
    
    // Current data
    currentAmbulanceRequest: null,
    currentPoliceAlert: null,
    
    // Listeners
    ambulanceListener: null,
    policeListener: null,
    timer: null,

    // Initialize
    init() {
        console.log('📊 DashboardPage initializing...');
        if (!this.liveTripPage) return;
        
        this.liveTripPage.classList.remove('active');
        this.liveTripPage.style.display = 'none';
        
        this.startRealTimeUpdates();
        this.loadSampleData();
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
                }
            });
        }
        
        this.timer = setInterval(() => {
            const now = new Date();
            const timeStr = now.toLocaleTimeString([], { 
                hour: '2-digit', 
                minute: '2-digit', 
                second: '2-digit' 
            });
            
            if (this.ambulanceUpdateTime) this.ambulanceUpdateTime.textContent = timeStr;
            if (this.policeUpdateTime) this.policeUpdateTime.textContent = timeStr;
        }, 1000);
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