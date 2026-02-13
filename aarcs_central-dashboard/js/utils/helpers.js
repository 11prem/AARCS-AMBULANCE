// Helper Functions
const Helpers = {
    // Format timestamp
    formatTimestamp(timestamp) {
        if (!timestamp || timestamp === 0) return 'N/A';
        try {
            const date = new Date(timestamp);
            const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
            const month = months[date.getMonth()];
            const day = date.getDate().toString().padStart(2, '0');
            const year = date.getFullYear();
            const hour = date.getHours().toString().padStart(2, '0');
            const minute = date.getMinutes().toString().padStart(2, '0');
            return `${month} ${day}, ${year} ${hour}:${minute}`;
        } catch (e) {
            return 'Invalid date';
        }
    },

    // Calculate duration
    calculateDuration(startTime, completedTime) {
        if (!startTime || startTime === 0 || !completedTime || completedTime === 0) {
            return 'N/A';
        }
        try {
            const start = new Date(startTime);
            const completed = new Date(completedTime);
            const duration = completed - start;
            const hours = Math.floor(duration / 3600000);
            const minutes = Math.floor((duration % 3600000) / 60000);
            return hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`;
        } catch (e) {
            return 'N/A';
        }
    },

    // Get status color
    getStatusColor(status) {
        switch (status?.toLowerCase()) {
            case 'completed': return '#4caf50';
            case 'accepted': return '#1976d2';
            case 'cancelled': return '#78909c';
            case 'pending': return '#ff9800';
            default: return '#78909c';
        }
    },

    // Get status icon
    getStatusIcon(status) {
        switch (status?.toLowerCase()) {
            case 'completed': return 'fa-check-circle';
            case 'accepted': return 'fa-ambulance';
            case 'cancelled': return 'fa-times-circle';
            case 'pending': return 'fa-clock';
            default: return 'fa-info-circle';
        }
    },

    // Get priority class
    getPriorityClass(priority) {
        const priorityValue = typeof priority === 'number' ? priority : 3;
        switch (priorityValue) {
            case 0: return 'priority-critical';
            case 1: return 'priority-high';
            case 2: return 'priority-medium';
            case 3: return 'priority-low';
            default: return 'priority-medium';
        }
    },

    // Truncate text
    truncateText(text, maxLength = 50) {
        if (!text) return '';
        if (text.length <= maxLength) return text;
        return text.substring(0, maxLength) + '...';
    },

    // Debounce function
    debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    },

    // Show notification
    showNotification(message, type = 'info', duration = 3000) {
        let container = document.getElementById('notificationContainer');
        if (!container) {
            container = document.createElement('div');
            container.id = 'notificationContainer';
            container.style.cssText = `
                position: fixed;
                top: 24px;
                right: 24px;
                z-index: 9999;
            `;
            document.body.appendChild(container);
        }

        const notification = document.createElement('div');
        const bgColor = type === 'success' ? '#4caf50' : 
                       type === 'error' ? '#f44336' : 
                       type === 'warning' ? '#ff9800' : '#1976d2';
        
        notification.style.cssText = `
            background: ${bgColor};
            color: white;
            padding: 12px 20px;
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 12px;
            animation: slideIn 0.3s ease-out;
        `;

        const icon = type === 'success' ? 'fa-check-circle' : 
                    type === 'error' ? 'fa-exclamation-circle' : 
                    'fa-info-circle';

        notification.innerHTML = `
            <i class="fas ${icon}"></i>
            <span style="flex: 1;">${message}</span>
            <button style="background: none; border: none; color: white; cursor: pointer; padding: 4px;">
                <i class="fas fa-times"></i>
            </button>
        `;

        container.appendChild(notification);

        notification.querySelector('button').onclick = () => notification.remove();

        setTimeout(() => {
            if (notification.parentNode) {
                notification.style.animation = 'slideOut 0.3s ease-out';
                notification.style.transform = 'translateX(100%)';
                notification.style.opacity = '0';
                setTimeout(() => notification.remove(), 300);
            }
        }, duration);
    }
};

// Make globally available
window.Helpers = Helpers;
console.log('✅ Helpers loaded');