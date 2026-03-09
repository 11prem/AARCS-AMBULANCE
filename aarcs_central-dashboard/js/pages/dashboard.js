// Dashboard Page Module
// At the very top of dashboard.js
console.log("📊 Dashboard page loaded at:", new Date().toISOString());

// Check if this is a fresh load or a reload
if (performance.navigation.type === 1) {
  console.log("🔄 Page was reloaded");
} else {
  console.log("✅ Fresh page load");
}

const DashboardPage = {
  // DOM elements
  liveTripPage: document.getElementById("liveTripPage"),
  ambulanceInfoEl: document.getElementById("ambulanceInfo"),
  patientDetailsEl: document.getElementById("patientDetails"),
  timelineItemsEl: document.getElementById("timelineItems"),
  policeInfoEl: document.getElementById("policeInfo"),
  clearanceStatusEl: document.getElementById("clearanceStatus"),
  ambulanceStatus: document.getElementById("ambulanceStatus"),
  ambulanceUpdateTime: document.getElementById("ambulanceUpdateTime"),
  policeUpdateTime: document.getElementById("policeUpdateTime"),
  callMessageCache: [],

  // NEW: Call Log elements
  callLogContainer: document.getElementById("callLogContainer"),
  callStatus: document.getElementById("callStatus"),
  callStatusText: document.getElementById("callStatusText"),
  callLogUpdateTime: document.getElementById("callLogUpdateTime"),
  callSummarySection: document.getElementById("callSummarySection"),
  summaryContent: document.getElementById("summaryContent"),
  summaryUpdateTime: document.getElementById("summaryUpdateTime"),
  viewFullSummaryBtn: document.getElementById("viewFullSummaryBtn"),
  dispatchFromSummaryBtn: document.getElementById("dispatchFromSummaryBtn"),

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
    console.log("📊 DashboardPage initializing...");
    if (!this.liveTripPage) return;

    // Initialize message cache
    this.callMessageCache = [];
    this._isRendering = false;

    // Store login timestamp
    this.loginTimestamp = new Date();

    this.liveTripPage.classList.remove("active");
    this.liveTripPage.style.display = "none";

    this.startRealTimeUpdates();

    // Initialize call log features
    this.initCallLogFeatures();

    // Set initial timestamps
    this.setInitialTimestamps();

    // Fetch last call logs AFTER Firebase is ready
    setTimeout(() => {
      this.fetchLastCallLogs();
    }, 2000); // Small delay to ensure Firebase is connected
  },

  // Set initial timestamps to login time
  setInitialTimestamps() {
    const loginTimeStr = this.loginTimestamp.toLocaleTimeString([], {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
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

  // Add to DashboardPage object
  async fetchLastCallLogs() {
    console.log("🔍 Fetching last call logs from Firebase...");

    if (!window.FirebaseService) {
      console.error("FirebaseService not available");
      return;
    }

    try {
      // Get the most recent completed call summary
      const snapshot = await firebase
        .database()
        .ref("call_summaries")
        .orderByChild("timestamp")
        .limitToLast(1)
        .once("value");

      if (snapshot.exists()) {
        snapshot.forEach((child) => {
          const summary = child.val();
          console.log("Found last call summary:", summary);

          // If there's a call ID, fetch its messages
          if (child.key) {
            this.fetchCallMessages(child.key);
          }
        });
      } else {
        console.log("No previous calls found");
      }
    } catch (error) {
      console.error("Error fetching last call:", error);
    }
  },

  async fetchCallMessages(callId) {
    console.log(`🔍 Fetching messages for call: ${callId}`);

    try {
      const snapshot = await firebase
        .database()
        .ref(`live_calls/${callId}/messages`)
        .orderByChild("timestamp")
        .once("value");

      if (snapshot.exists()) {
        const messages = [];
        snapshot.forEach((child) => {
          messages.push({
            id: child.key,
            ...child.val(),
          });
        });

        // Sort by timestamp
        messages.sort((a, b) => a.timestamp - b.timestamp);

        console.log(`Found ${messages.length} messages`);

        // Cache and display
        this.callMessageCache = messages;
        this.renderCallLog(this.callMessageCache, "completed");

        // Update status to show it's from previous call
        if (this.callStatus && this.callStatusText) {
          this.callStatusText.textContent = "Previous call";
        }
      }
    } catch (error) {
      console.error("Error fetching messages:", error);
    }
  },

  // Start real-time updates
  startRealTimeUpdates() {
    if (window.FirebaseService) {
      this.ambulanceListener = window.FirebaseService.listenToEmergencyRequests(
        (requests) => {
          if (Object.keys(requests).length > 0) {
            const latestRequestKey = Object.keys(requests).sort(
              (a, b) => requests[b].timestamp - requests[a].timestamp,
            )[0];

            this.currentAmbulanceRequest = {
              id: latestRequestKey,
              ...requests[latestRequestKey],
            };

            this.updateAmbulanceInfo();
            this.updatePatientInfo();
            this._updateTimelineFromRequest(this.currentAmbulanceRequest);

            // Keep login timestamp - do not update
          }
        },
      );

      this.policeListener = window.FirebaseService.listenToTrafficAlerts(
        (alerts) => {
          if (Object.keys(alerts).length > 0) {
            const latestAlertKey = Object.keys(alerts).sort(
              (a, b) => alerts[b].timestamp - alerts[a].timestamp,
            )[0];

            this.currentPoliceAlert = {
              id: latestAlertKey,
              ...alerts[latestAlertKey],
            };

            this.updatePoliceInfo();
            this.updateClearanceStatus();

            // Keep login timestamp - do not update
          }
        },
      );
    }
  },

  // Load sample data for demo
  loadSampleData() {
    if (!this.currentAmbulanceRequest) {
      const now = Date.now();
      this.currentAmbulanceRequest = {
        ambulanceId: "AMB-001",
        currentLocation: "Near City Mall",
        destination: "City General Hospital",
        distance: "4.2 km",
        priority: 1,
        priorityLabel: "HIGH",
        status: "accepted",
        timestamp: now - 10 * 60000,
        description: "Car accident with chest pain",
      };

      this.currentPoliceAlert = {
        ambulanceId: "AMB-001",
        currentLocation: "Highway Junction",
        destination: "City General Hospital",
        acknowledged: true,
        acknowledgedBy: "TP-2024-156",
        acknowledgedAt: now - 7.5 * 60000,
        timestamp: now - 8 * 60000,
        status: "acknowledged",
        priority: 1,
        priorityLabel: "HIGH",
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
      let statusClass = "status-active";
      let statusText = "EN ROUTE";
      this.ambulanceStatus.className = `status-badge ${statusClass}`;
      this.ambulanceStatus.innerHTML = `<i class="fas fa-exclamation-triangle"></i> ${statusText}`;
    }

    const etaTime = request.timestamp
      ? new Date(request.timestamp + 15 * 60000)
      : new Date(Date.now() + 15 * 60000);
    const etaString = etaTime.toLocaleTimeString([], {
      hour: "2-digit",
      minute: "2-digit",
    });

    this.ambulanceInfoEl.innerHTML = `
            <div class="info-card">
                <div class="info-card-header">
                    <i class="fas fa-id-badge"></i>
                    <span>Ambulance ID</span>
                </div>
                <div class="info-card-value">${request.ambulanceId || "AMB-001"}</div>
            </div>
            <div class="info-card">
                <div class="info-card-header">
                    <i class="fas fa-map-marker-alt"></i>
                    <span>Current Location</span>
                </div>
                <div class="info-card-value">
                    ${request.currentLocation || "En route to patient"}
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
                <div class="info-card-value">${request.destination || "City General Hospital"}</div>
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
                <div class="info-card-value">${request.distance || "4.2 km"}</div>
            </div>
            <div class="info-card">
                <div class="info-card-header">
                    <i class="fas fa-exclamation-triangle"></i>
                    <span>Priority</span>
                </div>
                <div class="info-card-value">
                    <span class="history-priority ${window.Helpers.getPriorityClass(request.priority)}">
                        ${request.priorityLabel || "HIGH"}
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
                    <div class="info-card-value">${request.description || "Car collision on highway, front impact"}</div>
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
                            ${request.priorityLabel === "CRITICAL" ? "Critical" : "Moderate to Severe"}
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
    const requestTime = request.timestamp || now - 20 * 60000;
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
                    <p>${new Date(requestTime).toLocaleTimeString()} - ${request.ambulanceId || "AMB-001"} dispatched</p>
                </div>
            </div>
            <div class="timeline-item">
                <div class="timeline-marker ${now > etaToPatient ? "active" : "pending"}">
                    <i class="fas fa-location-dot"></i>
                </div>
                <div class="timeline-content">
                    <h4>ETA to Patient Location</h4>
                    <p>${new Date(etaToPatient).toLocaleTimeString()} - ${request.distance || "4.2 km"} away</p>
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

  // Update police information with acknowledgment details
  updatePoliceInfo() {
    if (!this.policeInfoEl) return;
    const alert = this.currentPoliceAlert || {};

    this.policeInfoEl.innerHTML = `
            <div class="info-card">
                <div class="info-card-header">
                    <i class="fas fa-id-badge"></i>
                    <span>Assigned Officer</span>
                </div>
                <div class="info-card-value">${alert.acknowledgedBy || "Not assigned"}</div>
            </div>
            <div class="info-card">
                <div class="info-card-header">
                    <i class="fas fa-map-marker-alt"></i>
                    <span>Clearance Location</span>
                </div>
                <div class="info-card-value">${alert.currentLocation || "Unknown"}</div>
            </div>
            <div class="info-card">
                <div class="info-card-header">
                    <i class="fas fa-ambulance"></i>
                    <span>Assisting Ambulance</span>
                </div>
                <div class="info-card-value">${alert.ambulanceId || "Unknown"}</div>
            </div>
            <div class="info-card">
                <div class="info-card-header">
                    <i class="fas fa-clock"></i>
                    <span>Acknowledged At</span>
                </div>
                <div class="info-card-value">${
                  alert.acknowledgedAt
                    ? new Date(alert.acknowledgedAt).toLocaleTimeString()
                    : "Not acknowledged"
                }</div>
            </div>
            <div class="info-card">
                <div class="info-card-header">
                    <i class="fas fa-traffic-light"></i>
                    <span>Clearance Status</span>
                </div>
                <div class="info-card-value">
                    <span class="history-status ${alert.acknowledged ? "status-completed" : "status-pending"}">
                        ${alert.acknowledged ? "CLEARED" : "PENDING"}
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
                        ${alert.priorityLabel || "MEDIUM"}
                    </span>
                </div>
            </div>
        `;
  },

  // Update clearance status with acknowledgment details
  updateClearanceStatus() {
    if (!this.clearanceStatusEl) return;
    const alert = this.currentPoliceAlert || {};
    const isAcknowledged = alert.acknowledged === true;

    this.clearanceStatusEl.innerHTML = `
            <div class="timeline-item">
                <div class="timeline-marker active">
                    <i class="fas fa-bell"></i>
                </div>
                <div class="timeline-content">
                    <h4>Traffic Clearance Requested</h4>
                    <p>${new Date(alert.timestamp || Date.now()).toLocaleTimeString()} - Alert sent to traffic police</p>
                </div>
            </div>
            <div class="timeline-item">
                <div class="timeline-marker ${isAcknowledged ? "active" : "pending"}">
                    <i class="fas fa-check-circle"></i>
                </div>
                <div class="timeline-content">
                    <h4>Police Acknowledgment</h4>
                    <p>${
                      isAcknowledged
                        ? `${new Date(alert.acknowledgedAt).toLocaleTimeString()} - Officer ${alert.acknowledgedBy || "Unknown"}`
                        : "Awaiting response..."
                    }</p>
                </div>
            </div>
            <div class="timeline-item">
                <div class="timeline-marker ${isAcknowledged ? "active" : "pending"}">
                    <i class="fas fa-traffic-light"></i>
                </div>
                <div class="timeline-content">
                    <h4>Route Cleared</h4>
                    <p>${
                      isAcknowledged
                        ? "Route cleared for ambulance"
                        : "Not yet cleared"
                    }</p>
                </div>
            </div>
        `;
  },

  // ========== FIXED METHODS FOR CALL LOGS AND SUMMARIES ==========

  // Initialize call log features
  initCallLogFeatures() {
    console.log("📞 Initializing Call Log Features...");

    // Check if all required elements exist
    console.log("callLogContainer:", this.callLogContainer);
    console.log("callStatus:", this.callStatus);
    console.log("callSummarySection:", this.callSummarySection);

    if (window.FirebaseService) {
      console.log("✅ FirebaseService found");

      // Listen to call logs
      this.callLogListener = window.FirebaseService.listenToCallLogs((data) => {
        console.log("🔥 Firebase call log data received:", data);
        this.updateCallLog(data);
      });

      // Listen to call summaries
      this.callSummaryListener = window.FirebaseService.listenToCallSummaries(
        (summary) => {
          console.log("🔥 Firebase summary received:", summary);
          this.updateCallSummary(summary);
        },
      );
    } else {
      console.error("❌ FirebaseService not found!");
    }

    // Bind button events
    if (this.viewFullSummaryBtn) {
      this.viewFullSummaryBtn.addEventListener("click", () => {
        this.showFullSummaryModal();
      });
    }

    // Dispatch from summary button
    if (this.dispatchFromSummaryBtn) {
      // Remove existing listeners by cloning
      const newBtn = this.dispatchFromSummaryBtn.cloneNode(true);
      this.dispatchFromSummaryBtn.parentNode.replaceChild(
        newBtn,
        this.dispatchFromSummaryBtn,
      );
      this.dispatchFromSummaryBtn = newBtn;

      // Replace the dispatch button click handler in initCallLogFeatures()

      // In central_dashboard/js/pages/dashboard.js
      // Replace the dispatch button click handler with this:

      // In central_dashboard/js/pages/dashboard.js
      // Replace the dispatch button click handler with this:

      this.dispatchFromSummaryBtn.addEventListener("click", async (e) => {
        e.preventDefault();

        if (!this.currentCallSummary) {
          window.Helpers.showNotification("No call summary available", "error");
          return;
        }

        // For demo, we'll assign to AMB-001
        const ambulanceId = "AMB-001";

        try {
          // Show loading state
          this.dispatchFromSummaryBtn.disabled = true;
          this.dispatchFromSummaryBtn.innerHTML =
            '<i class="fas fa-spinner fa-spin"></i> Dispatching...';

          // Create a new emergency request on the fly
          const summary = this.currentCallSummary;

          // Generate a unique request ID
          const newRequestId = "req_" + Date.now();

          // Extract location coordinates with proper defaults
          let destLat = 12.9716; // Default Bangalore coordinates
          let destLng = 77.5946; // Default Bangalore coordinates

          // Try to get coordinates from various possible locations in the summary
          if (summary.emergency_info?.location_details?.latitude) {
            destLat = summary.emergency_info.location_details.latitude;
            destLng = summary.emergency_info.location_details.longitude;
          } else if (summary.location_details?.latitude) {
            destLat = summary.location_details.latitude;
            destLng = summary.location_details.longitude;
          } else if (summary.emergency_info?.latitude) {
            destLat = summary.emergency_info.latitude;
            destLng = summary.emergency_info.longitude;
          }

          // Get location name
          const destination =
            summary.destination ||
            summary.emergency_info?.location ||
            summary.call_summary?.location ||
            "Unknown Location";

          const description =
            summary.emergency_info?.type ||
            summary.call_summary?.emergency_type ||
            "Emergency";

          const priority =
            summary.priority !== undefined ? summary.priority : 0;
          const priorityLabel = summary.priorityLabel || "CRITICAL";

          console.log("📝 Creating emergency request:", {
            newRequestId,
            destination,
            destLat,
            destLng,
            priority,
            priorityLabel,
            description,
          });

          // Create the emergency request in Firebase
          const requestRef = window.FirebaseService.database
            .ref("emergency_requests")
            .child(newRequestId);

          const requestData = {
            ambulanceId: null, // Will be assigned below
            destination: destination,
            currentLocation:
              summary.emergency_info?.location_details?.address || destination,
            status: "pending",
            timestamp: firebase.database.ServerValue.TIMESTAMP,
            priority: priority,
            priorityLabel: priorityLabel,
            description: description,
            sourceCoords: {
              lat: destLat,
              lng: destLng,
            },
            destCoords: {
              lat: destLat, // In real scenario, this would be hospital coordinates
              lng: destLng,
            },
          };

          await requestRef.set(requestData);
          console.log("✅ Emergency request created:", newRequestId);

          // Now assign the ambulance
          await window.FirebaseService.assignAmbulanceToRequest(
            newRequestId,
            ambulanceId,
          );
          console.log("✅ Ambulance assigned:", ambulanceId);

          // Prepare emergency data for notification - IMPORTANT: No undefined values!
          const emergencyData = {
            requestId: newRequestId,
            ambulanceId: ambulanceId,
            destination: destination,
            destinationLat: destLat, // Using destinationLat, not sourceLat
            destinationLng: destLng, // Using destinationLng, not sourceLng
            priority: priority,
            priorityLabel: priorityLabel,
            description: description,
            currentLocation:
              summary.emergency_info?.location_details?.address || destination,
            eta: "15 min",
            distance: "4.2 km",
          };

          console.log("📱 Sending notification with data:", emergencyData);

          // Send notification to ambulance
          await window.FirebaseService.dispatchAmbulanceNotification(
            ambulanceId,
            emergencyData,
          );
          console.log("✅ Notification sent successfully");

          window.Helpers.showNotification(
            `Ambulance ${ambulanceId} dispatched! Notification sent.`,
            "success",
          );

          // Update button
          this.dispatchFromSummaryBtn.innerHTML =
            '<i class="fas fa-check"></i> Dispatched';
          this.dispatchFromSummaryBtn.style.backgroundColor = "#10b981";

          // Store the dispatched request info
          this.dispatchedRequestId = newRequestId;
          this.dispatchedAmbulanceId = ambulanceId;

          // Hide the summary section after a delay
          setTimeout(() => {
            if (this.callSummarySection) {
              this.callSummarySection.style.display = "none";
            }
          }, 3000);
        } catch (error) {
          console.error("❌ Dispatch error:", error);
          window.Helpers.showNotification(
            "Failed to dispatch ambulance: " + error.message,
            "error",
          );
          this.dispatchFromSummaryBtn.disabled = false;
          this.dispatchFromSummaryBtn.innerHTML =
            '<i class="fas fa-ambulance"></i> Dispatch Ambulance';
        }
      });
    }
  },

  // Update call log display
  // In central_dashboard/js/pages/dashboard.js

  updateCallLog(data) {
    console.log("📞 updateCallLog called with data:", data);

    if (!this.callLogContainer) {
      console.error("❌ callLogContainer not found!");
      return;
    }

    const { messages, callId, status } = data;

    // Store current call ID
    this.currentCallId = callId;

    // IMPORTANT: Always cache messages if they exist, regardless of status
    if (messages && messages.length > 0) {
      this.callMessageCache = messages;
      console.log(`Cached ${messages.length} messages for call ${callId}`);
    }

    // Update status indicator
    if (this.callStatus && this.callStatusText) {
      const indicator = this.callStatus.querySelector(".status-indicator");
      if (status === "active") {
        indicator.className = "status-indicator status-active";
        this.callStatusText.textContent = "Active call in progress";
      } else {
        indicator.className = "status-indicator status-inactive";
        this.callStatusText.textContent = "Call ended";
      }
    }

    // Update timestamp
    if (this.callLogUpdateTime) {
      const now = new Date();
      this.callLogUpdateTime.textContent = now.toLocaleTimeString([], {
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
      });
    }

    // Always render cached messages if they exist, regardless of status
    if (this.callMessageCache && this.callMessageCache.length > 0) {
      this.renderCallLog(this.callMessageCache, "completed");
    } else if (status === "active") {
      // Only show "waiting" for active calls with no messages
      this.renderCallLog(null, "active");
    } else {
      // No cached messages and no active call - show empty state
      this.renderCallLog(null, "inactive");
    }
  },

  // Add a flag to prevent concurrent renders
  _isRendering: false,

  // Updated renderCallLog
  renderCallLog(messages, displayStatus) {
    // Prevent concurrent renders
    if (this._isRendering) {
      console.log("Already rendering, skipping...");
      return;
    }

    if (!this.callLogContainer) return;

    console.log(
      "Rendering call log with messages:",
      messages?.length || 0,
      "status:",
      displayStatus,
    );

    // Set rendering flag
    this._isRendering = true;

    try {
      // Clear container
      this.callLogContainer.innerHTML = "";

      if (messages && messages.length > 0) {
        console.log(`Rendering ${messages.length} messages`);

        // Use a document fragment for better performance
        const fragment = document.createDocumentFragment();

        messages.forEach((msg) => {
          const messageEl = document.createElement("div");
          messageEl.className = `call-log-message ${msg.speaker}`;

          const time =
            msg.time ||
            new Date(msg.timestamp).toLocaleTimeString([], {
              hour: "2-digit",
              minute: "2-digit",
              second: "2-digit",
            });

          messageEl.innerHTML = `
                    <div class="message-header ${msg.speaker}">
                        <i class="fas ${msg.speaker === "agent" ? "fa-robot" : "fa-user"}"></i>
                        <span>${msg.speaker === "agent" ? "AI Agent" : "Caller"}</span>
                        <span class="message-time">${time}</span>
                    </div>
                    <div class="message-bubble">${this.escapeHtml(msg.message)}</div>
                `;

          fragment.appendChild(messageEl);
        });

        this.callLogContainer.appendChild(fragment);

        // Scroll to bottom
        setTimeout(() => {
          if (this.callLogContainer) {
            this.callLogContainer.scrollTop =
              this.callLogContainer.scrollHeight;
          }
        }, 100);
      } else if (displayStatus === "active") {
        this.callLogContainer.innerHTML = `
                <div class="empty-state">
                    <i class="fas fa-microphone"></i>
                    <h3>Call Connected</h3>
                    <p>Waiting for conversation to begin...</p>
                </div>
            `;
      } else {
        this.callLogContainer.innerHTML = `
                <div class="empty-state">
                    <i class="fas fa-phone-slash"></i>
                    <h3>No Active Call</h3>
                    <p>Previous call logs will appear here when a call ends.</p>
                </div>
            `;
      }
    } catch (error) {
      console.error("Error rendering call log:", error);
    } finally {
      // Always reset the rendering flag
      this._isRendering = false;
    }
  },

  // Add this method to clear cache when needed (optional)
  clearCallLogCache() {
    this.callMessageCache = [];
    this.renderCallLog(null, "inactive");
  },

  // Update timeline from real request data
  _updateTimelineFromRequest(request) {
    if (!this.timelineItemsEl || !request) return;

    const items = [];
    const now = Date.now();

    // Helper to format time
    const formatTime = (timestamp) => {
      if (!timestamp) return null;
      return new Date(timestamp).toLocaleTimeString([], {
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
      });
    };

    // 1. Emergency Call Received (from NLP)
    if (request.callTimestamp || request.timestamp) {
      const callTime = request.callTimestamp || request.timestamp;
      items.push({
        marker: "active",
        icon: "fa-phone-alt",
        title: "Emergency Call Received",
        time: formatTime(callTime) || "N/A",
        description: "108 emergency services dispatched ambulance",
      });
    }

    // 2. Request Created
    if (request.timestamp) {
      items.push({
        marker: "active",
        icon: "fa-file-alt",
        title: "Emergency Request Created",
        time: formatTime(request.timestamp) || "N/A",
        description: `Priority: ${request.priorityLabel || "MEDIUM"}`,
      });
    }

    // 3. Ambulance Assigned (by dispatcher)
    if (
      request.assignedAt ||
      (request.ambulanceId && request.ambulanceId !== null)
    ) {
      const assignTime = request.assignedAt || request.timestamp;
      items.push({
        marker: "active",
        icon: "fa-ambulance",
        title: "Ambulance Assigned",
        time: formatTime(assignTime) || "N/A",
        description: `${request.ambulanceId || "AMB-001"} assigned to incident`,
      });
    }

    // 4. Ambulance Accepted (driver started navigation)
    if (request.accepted_at) {
      items.push({
        marker: "active",
        icon: "fa-play-circle",
        title: "Ambulance En Route",
        time: formatTime(request.accepted_at) || "N/A",
        description: "Driver accepted and started navigation",
      });
    }

    // 5. Current ETA (if available)
    if (request.eta && request.eta !== "N/A") {
      items.push({
        marker: request.completed_at ? "active" : "pending",
        icon: "fa-clock",
        title: "Estimated Arrival",
        time: request.eta,
        description: `Distance: ${request.distance || "N/A"}`,
      });
    }

    // 6. Live location updates (if available)
    if (request.liveLocation) {
      const speed = request.liveLocation.speed
        ? `${Math.round(request.liveLocation.speed)} km/h`
        : "moving";
      items.push({
        marker: "pending",
        icon: "fa-location-dot",
        title: "Live Tracking",
        time: formatTime(request.liveLocation.timestamp) || "N/A",
        description: `Ambulance en route, ${speed}`,
      });
    }

    // 7. Trip Completed
    if (request.completed_at) {
      items.push({
        marker: "active",
        icon: "fa-flag-checkered",
        title: "Trip Completed",
        time: formatTime(request.completed_at) || "N/A",
        description: "Patient delivered to hospital",
      });
    }

    // Render timeline
    if (items.length === 0) {
      this.timelineItemsEl.innerHTML = `
                <div class="empty-state" style="padding: 40px 20px;">
                    <i class="fas fa-stream"></i>
                    <h3>No Timeline Events</h3>
                    <p>Waiting for emergency events...</p>
                </div>
            `;
      return;
    }

    this.timelineItemsEl.innerHTML = items
      .map(
        (item) => `
            <div class="timeline-item">
                <div class="timeline-marker ${item.marker}">
                    <i class="fas ${item.icon}"></i>
                </div>
                <div class="timeline-content">
                    <h4>${item.title}</h4>
                    <p>${item.time} – ${item.description}</p>
                </div>
            </div>
        `,
      )
      .join("");

    // Update ambulance status based on request status
    if (this.ambulanceStatus) {
      let statusClass = "status-pending";
      let statusText = "PENDING";

      if (request.accepted_at) {
        statusClass = "status-active";
        statusText = "EN ROUTE";
      }
      if (request.completed_at) {
        statusClass = "status-active";
        statusText = "COMPLETED";
      }

      this.ambulanceStatus.className = `status-badge ${statusClass}`;
      this.ambulanceStatus.innerHTML = `<i class="fas fa-exclamation-triangle"></i> ${statusText}`;
    }
  },

  // Update call summary display
  updateCallSummary(summary) {
    console.log("📋 updateCallSummary called with:", summary);

    if (!this.callSummarySection || !this.summaryContent) {
      console.error("❌ Summary elements not found!");
      return;
    }

    if (summary) {
      this.currentCallSummary = summary;
      this.callSummarySection.style.display = "block";

      // Build summary HTML
      const emergencyInfo = summary.emergency_info || {};
      const ambulanceData = summary.ambulance_data || {};
      const callSummary = summary.call_summary || {};

      // Determine priority class
      const urgency = (
        emergencyInfo.urgency ||
        callSummary.urgency ||
        "normal"
      ).toLowerCase();
      let priorityClass = "priority-medium";
      if (urgency === "critical" || urgency === "urgent")
        priorityClass = "priority-critical";
      else if (urgency === "high") priorityClass = "priority-high";
      else if (urgency === "low") priorityClass = "priority-low";

      let priorityText = urgency.toUpperCase();
      if (urgency === "urgent") priorityText = "URGENT";

      this.summaryContent.innerHTML = `
                <div class="summary-grid">
                    <div class="summary-item">
                        <div class="summary-item-label">
                            <i class="fas fa-exclamation-triangle"></i>
                            <span>Emergency Type</span>
                        </div>
                        <div class="summary-item-value">
                            ${emergencyInfo.type || callSummary.emergency_type || "Unknown"}
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
                            ${emergencyInfo.location || callSummary.location || "Unknown"}
                        </div>
                        ${
                          emergencyInfo.location_details
                            ? `
                            <div class="summary-location-details">
                                <div>${emergencyInfo.location_details.address || ""}</div>
                                <div class="coordinates">
                                    ${
                                      emergencyInfo.location_details.latitude
                                        ? `${emergencyInfo.location_details.latitude.toFixed(4)}, ${emergencyInfo.location_details.longitude.toFixed(4)}`
                                        : callSummary.location_details
                                            ?.coordinates || ""
                                    }
                                </div>
                            </div>
                        `
                            : ""
                        }
                    </div>
                    
                    <div class="summary-item">
                        <div class="summary-item-label">
                            <i class="fas fa-user-injured"></i>
                            <span>Injuries</span>
                        </div>
                        <div class="summary-item-value">
                            ${
                              callSummary.injuries === true
                                ? "Yes"
                                : callSummary.injuries === false
                                  ? "No"
                                  : emergencyInfo.injuries
                                    ? "Yes"
                                    : "Unknown"
                            }
                            ${callSummary.injury_count ? ` (${callSummary.injury_count} persons)` : ""}
                        </div>
                    </div>
                    
                    <div class="summary-item">
                        <div class="summary-item-label">
                            <i class="fas fa-shield-alt"></i>
                            <span>Currently Safe</span>
                        </div>
                        <div class="summary-item-value">
                            ${
                              callSummary.is_safe === true
                                ? "Yes"
                                : callSummary.is_safe === false
                                  ? "No"
                                  : "Unknown"
                            }
                        </div>
                    </div>
                    
                    ${
                      ambulanceData.id
                        ? `
                    <div class="summary-item full-width">
                        <div class="summary-item-label">
                            <i class="fas fa-ambulance"></i>
                            <span>Ambulance Status</span>
                        </div>
                        <div class="summary-item-value">
                            ${ambulanceData.id} - ETA: ${ambulanceData.eta_minutes} minutes
                            ${ambulanceData.distance_km ? ` (${ambulanceData.distance_km.toFixed(1)} km away)` : ""}
                        </div>
                    </div>
                    `
                        : ""
                    }
                </div>
                
                ${
                  summary.conversation && summary.conversation.length > 0
                    ? `
                <div class="conversation-summary">
                    <h4><i class="fas fa-comments"></i> Recent Conversation</h4>
                    <div class="conversation-preview">
                        ${summary.conversation
                          .slice(-5)
                          .map(
                            (msg) => `
                            <div class="conversation-line">
                                <span class="speaker ${msg.speaker}">${msg.speaker === "ai" ? "AI" : "Caller"}</span>
                                <span class="message">${this.escapeHtml(msg.message)}</span>
                                <span class="time">${msg.time || ""}</span>
                            </div>
                        `,
                          )
                          .join("")}
                    </div>
                </div>
                `
                    : ""
                }
            `;
    } else {
      this.callSummarySection.style.display = "none";
      this.currentCallSummary = null;
    }
  },

  // Helper: Escape HTML to prevent XSS
  escapeHtml(text) {
    if (!text) return "";
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  },

  // Show full summary modal (placeholder)
  showFullSummaryModal() {
    if (this.currentCallSummary) {
      console.log("Full Summary:", this.currentCallSummary);

      if (window.Helpers) {
        window.Helpers.showNotification(
          "Full summary view coming soon!",
          "info",
        );
      }
    }
  },

  // Dispatch ambulance from summary
  dispatchAmbulanceFromSummary() {
    if (this.currentCallSummary) {
      const summary = this.currentCallSummary;
      const location =
        summary.emergency_info?.location || summary.call_summary?.location;

      if (location) {
        console.log("Dispatching ambulance to:", location);

        if (window.Helpers) {
          window.Helpers.showNotification(
            `Ambulance dispatched to ${location}`,
            "success",
          );
        }
      } else {
        if (window.Helpers) {
          window.Helpers.showNotification(
            "No location available for dispatch",
            "error",
          );
        }
      }
    }
  },

  // Show dashboard
  show() {
    if (this.liveTripPage) {
      this.liveTripPage.classList.add("active");
      this.liveTripPage.style.display = "block";
    }
  },

  // Hide dashboard
  hide() {
    if (this.liveTripPage) {
      this.liveTripPage.classList.remove("active");
      this.liveTripPage.style.display = "none";
    }
  },
};

window.DashboardPage = DashboardPage;
console.log("✅ DashboardPage loaded");
