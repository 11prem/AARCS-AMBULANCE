// Firebase Service
const FirebaseService = {
  // Database reference
  get database() {
    return window.database || firebase.database();
  },

  // Store message listener reference
  _messageListener: null,

  // Get all history data (ambulance trips + police actions)

  // Add this method to FirebaseService object

  // Dispatch ambulance notification
  // In firebase-service.js
  async dispatchAmbulanceNotification(ambulanceId, emergencyData) {
    console.log(
      `📱 Dispatching notification to ambulance ${ambulanceId}`,
      emergencyData,
    );

    try {
      const notificationRef = this.database
        .ref("ambulance_notifications")
        .push();

      // Ensure no undefined values
      const cleanData = {};
      Object.keys(emergencyData).forEach((key) => {
        if (emergencyData[key] !== undefined) {
          cleanData[key] = emergencyData[key];
        }
      });

      const notificationData = {
        ambulanceId: ambulanceId,
        notificationId: notificationRef.key,
        type: "EMERGENCY_DISPATCH",
        title: "🚑 New Emergency Assigned",
        body: `Destination: ${emergencyData.destination || "Unknown"}`,
        data: cleanData, // Use cleaned data
        read: false,
        createdAt: firebase.database.ServerValue.TIMESTAMP,
        timestamp: firebase.database.ServerValue.TIMESTAMP,
      };

      await notificationRef.set(notificationData);
      console.log("✅ Notification sent to Firebase:", notificationRef.key);

      return notificationRef.key;
    } catch (error) {
      console.error("❌ Error sending notification:", error);
      throw error;
    }
  },

  async getHistoryData(filters = {}) {
    try {
      // Get ambulance trips
      const tripsSnapshot = await this.database
        .ref("emergency_requests")
        .once("value");

      // Get police actions (acknowledged alerts)
      const policeSnapshot = await this.database
        .ref("traffic_clearance_alerts")
        .once("value");

      let allHistory = [];

      // Process ambulance trips
      if (tripsSnapshot.exists()) {
        const requests = tripsSnapshot.val();
        const trips = this._processAmbulanceTrips(requests, filters);
        allHistory = [...allHistory, ...trips];
      }

      // Process police actions
      if (policeSnapshot.exists()) {
        const alerts = policeSnapshot.val();
        const policeActions = this._processPoliceActions(alerts, filters);
        allHistory = [...allHistory, ...policeActions];
      }

      // Sort by timestamp (newest first)
      allHistory.sort((a, b) => b.timestamp - a.timestamp);

      return allHistory;
    } catch (error) {
      console.error("Error fetching history:", error);
      return [];
    }
  },

  // Process ambulance trips
  _processAmbulanceTrips(requests, filters) {
    const historyList = [];

    Object.entries(requests || {}).forEach(([key, request]) => {
      const status = request.status || "";

      // Only include completed or accepted trips
      if (["completed", "accepted", "cancelled"].includes(status)) {
        const historyItem = {
          id: key,
          type: "ambulance_trip",
          requestId: key,
          ambulanceId: request.ambulanceId || "Unknown",
          currentLocation: request.currentLocation || "Unknown",
          destination: request.destination || "Unknown Hospital",
          status: status,
          timestamp: request.timestamp || 0,
          accepted_at: request.accepted_at || 0,
          completed_at: request.completed_at || 0,
          eta: request.eta || "N/A",
          distance: request.distance || "N/A",
          priority: request.priority || 3,
          priorityLabel: request.priorityLabel || "MEDIUM",
          description: request.description || "",
          trafficClearanceRequested: request.trafficClearanceRequested || false,
          sourceCoords: request.sourceCoords,
          destCoords: request.destCoords,
          // Add icon based on status
          icon: this._getStatusIcon(status),
        };

        if (this._applyFilters(historyItem, filters)) {
          historyList.push(historyItem);
        }
      }
    });

    return historyList;
  },

  // Process police actions
  _processPoliceActions(alerts, filters) {
    const historyList = [];

    Object.entries(alerts || {}).forEach(([key, alert]) => {
      // Only include acknowledged alerts
      if (alert.acknowledged === true) {
        const historyItem = {
          id: key,
          type: "police_action",
          alertId: key,
          ambulanceId: alert.ambulanceId || "Unknown",
          destination: alert.destination || "Unknown Location",
          status: "acknowledged",
          timestamp: alert.timestamp || 0,
          acknowledgedAt: alert.acknowledgedAt || 0,
          acknowledgedBy: alert.acknowledgedBy || "Unknown Officer",
          eta: alert.eta || "N/A",
          distance: alert.distance || "N/A",
          priority: alert.priority || 3,
          priorityLabel: alert.priorityLabel || "MEDIUM",
          currentLocation: alert.currentLocation || "Unknown",
          requestId: alert.requestId,
          // Police-specific fields
          action: "traffic_clearance",
          description: `Traffic clearance provided for ambulance ${alert.ambulanceId}`,
          // Use priority from alert
          icon: "fa-traffic-light",
        };

        if (this._applyFilters(historyItem, filters)) {
          historyList.push(historyItem);
        }
      }
    });

    return historyList;
  },

  // Apply filters to history items
  _applyFilters(item, filters) {
    let include = true;

    if (filters.status && filters.status !== "all") {
      if (item.type === "police_action") {
        // Police actions have different status mapping
        if (filters.status === "completed" && item.status !== "acknowledged")
          include = false;
      } else {
        if (item.status !== filters.status) include = false;
      }
    }

    if (
      filters.priority &&
      filters.priority !== "all" &&
      item.priority !== parseInt(filters.priority)
    ) {
      include = false;
    }

    if (filters.search) {
      const searchLower = filters.search.toLowerCase();
      const searchFields = [
        item.ambulanceId,
        item.destination,
        item.acknowledgedBy,
        item.description,
      ]
        .filter(Boolean)
        .map((f) => f.toLowerCase());

      if (!searchFields.some((field) => field.includes(searchLower))) {
        include = false;
      }
    }

    return include;
  },

  // Get icon based on status
  _getStatusIcon(status) {
    switch (status?.toLowerCase()) {
      case "completed":
        return "fa-check-circle";
      case "accepted":
        return "fa-ambulance";
      case "cancelled":
        return "fa-times-circle";
      case "acknowledged":
        return "fa-traffic-light";
      default:
        return "fa-info-circle";
    }
  },

  // Filter history data (kept for backward compatibility)
  filterHistoryData(requests, filters) {
    const historyList = [];

    Object.entries(requests || {}).forEach(([key, request]) => {
      const status = request.status || "";

      if (["completed", "accepted", "cancelled"].includes(status)) {
        const historyItem = {
          requestId: key,
          ambulanceId: request.ambulanceId || "Unknown",
          currentLocation: request.currentLocation || "Unknown",
          destination: request.destination || "Unknown Hospital",
          status: status,
          timestamp: request.timestamp || 0,
          accepted_at: request.accepted_at || 0,
          completed_at: request.completed_at || 0,
          eta: request.eta || "N/A",
          distance: request.distance || "N/A",
          priority: request.priority || 3,
          priorityLabel: request.priorityLabel || "MEDIUM",
          description: request.description || "",
          trafficClearanceRequested: request.trafficClearanceRequested || false,
        };

        let include = true;

        if (
          filters.status &&
          filters.status !== "all" &&
          historyItem.status !== filters.status
        ) {
          include = false;
        }

        if (
          filters.priority &&
          filters.priority !== "all" &&
          historyItem.priority !== parseInt(filters.priority)
        ) {
          include = false;
        }

        if (filters.search) {
          const searchLower = filters.search.toLowerCase();
          if (
            !historyItem.ambulanceId.toLowerCase().includes(searchLower) &&
            !historyItem.destination.toLowerCase().includes(searchLower)
          ) {
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
    return this.database
      .ref("emergency_requests")
      .orderByChild("timestamp")
      .limitToLast(1)
      .on("value", (snapshot) => {
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
    return this.database
      .ref("traffic_clearance_alerts")
      .orderByChild("timestamp")
      .limitToLast(1)
      .on("value", (snapshot) => {
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

  // Assign ambulance to a pending request
  assignAmbulanceToRequest(requestId, ambulanceId) {
    console.log(
      `🚑 Assigning ambulance ${ambulanceId} to request ${requestId}`,
    );

    return this.database
      .ref(`emergency_requests/${requestId}`)
      .update({
        ambulanceId: ambulanceId,
        assignedAt: firebase.database.ServerValue.TIMESTAMP,
        // Keep status as pending until driver accepts
      })
      .then(() => {
        console.log("✅ Ambulance assigned successfully");
        return true;
      })
      .catch((error) => {
        console.error("❌ Error assigning ambulance:", error);
        throw error;
      });
  },

  // Get pending requests for a specific ambulance
  getPendingRequestsForAmbulance(ambulanceId) {
    return this.database
      .ref("emergency_requests")
      .orderByChild("ambulanceId")
      .equalTo(ambulanceId)
      .once("value")
      .then((snapshot) => {
        if (snapshot.exists()) {
          const requests = [];
          snapshot.forEach((child) => {
            const request = child.val();
            if (request.status === "pending") {
              requests.push({
                id: child.key,
                ...request,
              });
            }
          });
          return requests;
        }
        return [];
      });
  },

  // ========== CALL LOGS AND SUMMARIES ==========

  // Listen to active call logs
  // In central_dashboard/js/services/firebase-service.js

  listenToCallLogs(callback) {
    console.log("🔍 Setting up call log listener...");

    // Keep track of the current call ID and message listener
    let currentCallId = null;
    let messageListenerRef = null;

    // Listen to all live calls
    const callsRef = this.database.ref("live_calls");

    return callsRef.on("value", (snapshot) => {
      console.log("📡 Live calls snapshot received:", snapshot.val());

      // Clean up previous message listener if exists
      if (messageListenerRef) {
        messageListenerRef.off();
        messageListenerRef = null;
      }

      if (snapshot.exists()) {
        const calls = snapshot.val();

        // Find the most recent active call
        let activeCallId = null;
        let activeCallData = null;
        let latestTimestamp = 0;

        Object.keys(calls).forEach((callId) => {
          const call = calls[callId];
          // Only consider active calls
          if (call.status === "active" && call.timestamp > latestTimestamp) {
            activeCallId = callId;
            activeCallData = call;
            latestTimestamp = call.timestamp;
          }
        });

        if (activeCallId) {
          console.log(`✅ Found active call: ${activeCallId}`);
          currentCallId = activeCallId;

          // Send initial empty messages to show call connected
          callback({
            messages: [],
            callId: activeCallId,
            status: "active",
          });

          // Now listen to messages for this specific call
          const messagesRef = this.database.ref(
            `live_calls/${activeCallId}/messages`,
          );

          messageListenerRef = messagesRef.on("value", (msgSnapshot) => {
            console.log(
              `📨 Messages for call ${activeCallId}:`,
              msgSnapshot.val(),
            );

            if (msgSnapshot.exists()) {
              const messages = [];
              msgSnapshot.forEach((child) => {
                const msg = child.val();
                messages.push({
                  id: child.key,
                  speaker: msg.speaker || "unknown",
                  message: msg.message || "",
                  timestamp: msg.timestamp || Date.now(),
                  time:
                    msg.time || new Date(msg.timestamp).toLocaleTimeString(),
                });
              });

              // Sort by timestamp
              messages.sort((a, b) => a.timestamp - b.timestamp);

              callback({
                messages: messages,
                callId: activeCallId,
                status: "active",
              });
            } else {
              // No messages yet
              callback({
                messages: [],
                callId: activeCallId,
                status: "active",
              });
            }
          });
        } else {
          console.log("📭 No active calls found");
          callback({
            messages: [],
            callId: null,
            status: "inactive",
          });
        }
      } else {
        console.log("📭 No calls in database");
        callback({
          messages: [],
          callId: null,
          status: "inactive",
        });
      }
    });
  },

  // Listen to call summaries
  listenToCallSummaries(callback) {
    console.log("🔍 Setting up call summary listener...");

    return this.database
      .ref("call_summaries")
      .orderByChild("timestamp")
      .limitToLast(1)
      .on("value", (snapshot) => {
        if (snapshot.exists()) {
          let latestSummary = null;
          let latestTimestamp = 0;

          snapshot.forEach((child) => {
            const summary = child.val();
            const summaryTime = summary.timestamp
              ? new Date(summary.timestamp).getTime()
              : 0;
            if (summaryTime > latestTimestamp) {
              latestSummary = summary;
              latestTimestamp = summaryTime;
            }
          });

          callback(latestSummary);
        } else {
          callback(null);
        }
      });
  },

  // Stop listening to calls
  stopListeningToCalls(listener) {
    if (listener) {
      this.database.ref("live_calls").off("value", listener);
    }
    if (this._messageListener) {
      this.database.ref().off("value", this._messageListener);
      this._messageListener = null;
    }
  },
};

window.FirebaseService = FirebaseService;
console.log("✅ FirebaseService loaded");
