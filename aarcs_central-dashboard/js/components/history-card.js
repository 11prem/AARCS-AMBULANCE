// History Card Component
const HistoryCard = {
    // Render history card
    render(historyItem) {
        const card = document.createElement('div');
        card.className = 'history-card';
        card.dataset.requestId = historyItem.requestId;
        
        const formattedDate = window.Helpers.formatTimestamp(historyItem.timestamp);
        const statusIcon = window.Helpers.getStatusIcon(historyItem.status);
        const priorityClass = window.Helpers.getPriorityClass(historyItem.priority);
        
        const summary = document.createElement('div');
        summary.className = 'history-card-summary';
        summary.innerHTML = `
            <div class="history-id">
                <i class="fas ${statusIcon}"></i>
                <span>${historyItem.ambulanceId}</span>
            </div>
            <div class="history-hospital">${window.Helpers.truncateText(historyItem.destination, 25)}</div>
            <div class="history-date">${formattedDate}</div>
            <div><span class="history-priority ${priorityClass}">${historyItem.priorityLabel || 'MEDIUM'}</span></div>
            <div><span class="history-status status-${historyItem.status}">${historyItem.status.toUpperCase()}</span></div>
            <button class="expand-btn">
                <i class="fas fa-chevron-down"></i>
            </button>
        `;
        
        const details = document.createElement('div');
        details.className = 'history-details';
        details.innerHTML = this.renderDetails(historyItem);
        
        card.appendChild(summary);
        card.appendChild(details);
        
        const expandBtn = summary.querySelector('.expand-btn');
        expandBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            this.toggleExpand(card);
        });
        
        return card;
    },

    // Render detailed view
    renderDetails(historyItem) {
        const startTime = window.Helpers.formatTimestamp(historyItem.timestamp);
        const completedTime = window.Helpers.formatTimestamp(historyItem.completed_at);
        const acceptedTime = window.Helpers.formatTimestamp(historyItem.accepted_at);
        const duration = window.Helpers.calculateDuration(historyItem.timestamp, historyItem.completed_at);
        const priorityClass = window.Helpers.getPriorityClass(historyItem.priority);
        
        let emergencyConditionHtml = '';
        if (historyItem.priorityLabel === 'CRITICAL' && historyItem.description) {
            emergencyConditionHtml = `
                <div class="detail-row">
                    <span class="detail-label">Emergency Condition:</span>
                    <span class="detail-value" style="color: var(--danger); font-weight: 600;">
                        <i class="fas fa-exclamation-triangle" style="color: var(--danger); margin-right: 6px;"></i>
                        ${historyItem.description}
                    </span>
                </div>
            `;
        }
        
        return `
            <div class="details-grid">
                <div class="details-section">
                    <h4><i class="fas fa-info-circle"></i> Trip Information</h4>
                    <div class="detail-row">
                        <span class="detail-label">Trip ID:</span>
                        <span class="detail-value" style="font-family: monospace;">${historyItem.requestId}</span>
                    </div>
                    <div class="detail-row">
                        <span class="detail-label">Ambulance ID:</span>
                        <span class="detail-value">${historyItem.ambulanceId}</span>
                    </div>
                    <div class="detail-row">
                        <span class="detail-label">Status:</span>
                        <span class="detail-value">
                            <span class="history-status status-${historyItem.status}">${historyItem.status.toUpperCase()}</span>
                        </span>
                    </div>
                    <div class="detail-row">
                        <span class="detail-label">Priority:</span>
                        <span class="detail-value">
                            <span class="history-priority ${priorityClass}">${historyItem.priorityLabel || 'MEDIUM'}</span>
                        </span>
                    </div>
                    ${emergencyConditionHtml}
                </div>
                
                <div class="details-section">
                    <h4><i class="fas fa-route"></i> Route Information</h4>
                    <div class="detail-row">
                        <span class="detail-label">Starting Location:</span>
                        <span class="detail-value">${historyItem.currentLocation}</span>
                    </div>
                    <div class="detail-row">
                        <span class="detail-label">Destination:</span>
                        <span class="detail-value">${historyItem.destination}</span>
                    </div>
                    <div class="detail-row">
                        <span class="detail-label">Distance:</span>
                        <span class="detail-value">${historyItem.distance}</span>
                    </div>
                    <div class="detail-row">
                        <span class="detail-label">ETA:</span>
                        <span class="detail-value">${historyItem.eta}</span>
                    </div>
                </div>
                
                <div class="details-section">
                    <h4><i class="fas fa-clock"></i> Timeline</h4>
                    <div class="detail-row">
                        <span class="detail-label">Trip Started:</span>
                        <span class="detail-value">${startTime}</span>
                    </div>
                    <div class="detail-row">
                        <span class="detail-label">Accepted At:</span>
                        <span class="detail-value">${acceptedTime}</span>
                    </div>
                    <div class="detail-row">
                        <span class="detail-label">Completed At:</span>
                        <span class="detail-value">${completedTime}</span>
                    </div>
                    <div class="detail-row">
                        <span class="detail-label">Total Duration:</span>
                        <span class="detail-value"><strong>${duration}</strong></span>
                    </div>
                </div>
                
                <div class="details-section">
                    <h4><i class="fas fa-traffic-light"></i> Traffic Clearance</h4>
                    <div class="detail-row">
                        <span class="detail-label">Status:</span>
                        <span class="detail-value">
                            ${historyItem.trafficClearanceRequested ? 
                                '<span style="color: var(--success);"><i class="fas fa-check-circle"></i> REQUESTED</span>' : 
                                '<span style="color: var(--gray);"><i class="fas fa-times-circle"></i> NOT REQUESTED</span>'}
                        </span>
                    </div>
                </div>
            </div>
        `;
    },

    // Toggle expand/collapse
    toggleExpand(card) {
        card.classList.toggle('expanded');
        const icon = card.querySelector('.expand-btn i');
        if (card.classList.contains('expanded')) {
            icon.className = 'fas fa-chevron-up';
        } else {
            icon.className = 'fas fa-chevron-down';
        }
    },

    // Collapse all cards
    collapseAll() {
        document.querySelectorAll('.history-card.expanded').forEach(card => {
            card.classList.remove('expanded');
            const icon = card.querySelector('.expand-btn i');
            if (icon) icon.className = 'fas fa-chevron-down';
        });
    }
};

window.HistoryCard = HistoryCard;
console.log('✅ HistoryCard loaded');