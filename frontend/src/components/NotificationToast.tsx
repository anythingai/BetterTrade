import React from 'react';
import { Notification, NotificationType } from '../types/notifications';
import { useNotifications } from '../contexts/NotificationContext';

interface NotificationToastProps {
  notification: Notification;
}

export const NotificationToast: React.FC<NotificationToastProps> = ({ notification }) => {
  const { removeNotification } = useNotifications();

  const getIcon = (type: NotificationType): string => {
    switch (type) {
      case NotificationType.Success:
        return '✅';
      case NotificationType.Warning:
        return '⚠️';
      case NotificationType.Error:
        return '❌';
      case NotificationType.Info:
      default:
        return 'ℹ️';
    }
  };

  const formatTimestamp = (timestamp: number): string => {
    return new Date(timestamp).toLocaleTimeString();
  };

  return (
    <div className={`notification-toast notification-${notification.type}`}>
      <div className="notification-content">
        <div className="notification-header">
          <span className="notification-icon">{getIcon(notification.type)}</span>
          <span className="notification-title">{notification.title}</span>
          <span className="notification-time">{formatTimestamp(notification.timestamp)}</span>
          <button 
            type="button"
            className="notification-close"
            onClick={() => removeNotification(notification.id)}
            aria-label="Close notification"
          >
            ×
          </button>
        </div>
        <div className="notification-message">{notification.message}</div>
        {notification.actionLabel && notification.onAction && (
          <div className="notification-actions">
            <button 
              type="button"
              className="notification-action-btn"
              onClick={notification.onAction}
            >
              {notification.actionLabel}
            </button>
          </div>
        )}
      </div>
    </div>
  );
};

interface NotificationContainerProps {}

export const NotificationContainer: React.FC<NotificationContainerProps> = () => {
  const { notifications } = useNotifications();

  if (notifications.length === 0) {
    return null;
  }

  return (
    <div className="notification-container">
      {notifications.map(notification => (
        <NotificationToast key={notification.id} notification={notification} />
      ))}
    </div>
  );
};