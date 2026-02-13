// UI Service Module
const UIService = (function() {
    // Show loading state
    function showLoading(container, message = 'Loading...') {
        const loadingEl = document.createElement('div');
        loadingEl.className = 'loading-state';
        loadingEl.innerHTML = `
            <div class="loading-spinner"></div>
            <p>${message}</p>
        `;
        
        const target = typeof container === 'string' 
            ? document.getElementById(container) 
            : container;
            
        if (target) {
            target.innerHTML = '';
            target.appendChild(loadingEl);
        }
    }
    
    // Show empty state
    function showEmptyState(container, icon = 'fa-history', title = 'No Data', message = 'No items to display') {
        const emptyEl = document.createElement('div');
        emptyEl.className = 'empty-state';
        emptyEl.innerHTML = `
            <i class="fas ${icon}"></i>
            <h3>${title}</h3>
            <p>${message}</p>
        `;
        
        const target = typeof container === 'string' 
            ? document.getElementById(container) 
            : container;
            
        if (target) {
            target.innerHTML = '';
            target.appendChild(emptyEl);
        }
    }
    
    // Show notification
    function showNotification(message, type = 'info', duration = 3000) {
        const notification = document.createElement('div');
        notification.className = `notification notification-${type}`;
        notification.innerHTML = `
            <div class="notification-content">
                <i class="fas ${type === 'success' ? 'fa-check-circle' : type === 'error' ? 'fa-exclamation-circle' : 'fa-info-circle'}"></i>
                <span>${message}</span>
            </div>
            <button class="notification-close">
                <i class="fas fa-times"></i>
            </button>
        `;
        
        // Style the notification
        Object.assign(notification.style, {
            position: 'fixed',
            top: '24px',
            right: '24px',
            background: type === 'success' ? '#4caf50' : type === 'error' ? '#f44336' : type === 'warning' ? '#ff9800' : '#1976d2',
            color: 'white',
            padding: '12px 20px',
            borderRadius: '8px',
            boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: '16px',
            zIndex: '9999',
            animation: 'slideIn 0.3s ease-out'
        });
        
        // Add animation keyframes
        const style = document.createElement('style');
        style.textContent = `
            @keyframes slideIn {
                from { transform: translateX(100%); opacity: 0; }
                to { transform: translateX(0); opacity: 1; }
            }
        `;
        document.head.appendChild(style);
        
        document.body.appendChild(notification);
        
        // Close button
        notification.querySelector('.notification-close').addEventListener('click', () => {
            notification.remove();
        });
        
        // Auto remove
        setTimeout(() => {
            if (notification.parentNode) {
                notification.style.animation = 'slideOut 0.3s ease-out';
                notification.style.transform = 'translateX(100%)';
                notification.style.opacity = '0';
                setTimeout(() => notification.remove(), 300);
            }
        }, duration);
    }
    
    // Format numbers
    function formatNumber(num, decimals = 0) {
        if (num === undefined || num === null) return '0';
        return Number(num).toFixed(decimals);
    }
    
    // Truncate text
    function truncateText(text, maxLength = 50) {
        if (!text) return '';
        if (text.length <= maxLength) return text;
        return text.substring(0, maxLength) + '...';
    }
    
    // Debounce function
    function debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }
    
    // Public API
    return {
        showLoading,
        showEmptyState,
        showNotification,
        formatNumber,
        truncateText,
        debounce
    };
})();