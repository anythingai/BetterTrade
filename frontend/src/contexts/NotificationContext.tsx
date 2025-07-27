import React, { createContext, useContext, useState, useCallback, ReactNode } from 'react';
import { 
  Notification, 
  Alert, 
  LogEntry, 
  NotificationContextType,
  AlertSeverity,
  NotificationType
} from '../types/notifications';

const NotificationContext = createContext<NotificationContextType | undefined>(undefined);

export const useNotifications = () => {
  const context = useContext(NotificationContext);
  if (!context) {
    throw new Error('useNotifications must be used within a NotificationProvider');
  }
  return context;
};

interface NotificationProviderProps {
  children: ReactNode;
}

export const NotificationProvider: React.FC<NotificationProviderProps> = ({ children }) => {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [logs, setLogs] = useState<LogEntry[]>([]);

  const addNotification = useCallback((notification: Omit<Notification, 'id' | 'timestamp'>) => {
    const newNotification: Notification = {
      ...notification,
      id: `notification-${Date.now()}-${Math.random().toString(36).substring(2, 11)}`,
      timestamp: Date.now()
    };

    setNotifications(prev => [...prev, newNotification]);

    // Auto-remove notification after duration (default 5 seconds)
    if (notification.duration !== 0 && notification.duration !== undefined) {
      const duration = notification.duration || 5000;
      setTimeout(() => {
        setNotifications(prev => prev.filter(n => n.id !== newNotification.id));
      }, duration);
    }
  }, []);

  const removeNotification = useCallback((id: string) => {
    setNotifications(prev => prev.filter(notification => notification.id !== id));
  }, []);

  const addAlert = useCallback((alert: Omit<Alert, 'id' | 'timestamp' | 'acknowledged'>) => {
    const newAlert: Alert = {
      ...alert,
      id: `alert-${Date.now()}-${Math.random().toString(36).substring(2, 11)}`,
      timestamp: Date.now(),
      acknowledged: false
    };

    setAlerts(prev => [...prev, newAlert]);

    // Also add as notification for immediate visibility
    addNotification({
      type: alert.severity === AlertSeverity.Critical || alert.severity === AlertSeverity.High ? NotificationType.Error : NotificationType.Warning,
      title: alert.title,
      message: alert.message,
      duration: alert.severity === AlertSeverity.Critical ? 0 : 8000 // Critical alerts persist
    });
  }, [addNotification]);

  const acknowledgeAlert = useCallback((id: string) => {
    setAlerts(prev => prev.map(alert => 
      alert.id === id ? { ...alert, acknowledged: true } : alert
    ));
  }, []);

  const addLogEntry = useCallback((entry: Omit<LogEntry, 'id' | 'timestamp'>) => {
    const newLogEntry: LogEntry = {
      ...entry,
      id: `log-${Date.now()}-${Math.random().toString(36).substring(2, 11)}`,
      timestamp: Date.now()
    };

    setLogs(prev => {
      // Keep only the last 1000 log entries to prevent memory issues
      const updatedLogs = [...prev, newLogEntry];
      return updatedLogs.slice(-1000);
    });
  }, []);

  const clearLogs = useCallback(() => {
    setLogs([]);
  }, []);

  const value: NotificationContextType = {
    notifications,
    alerts,
    logs,
    addNotification,
    removeNotification,
    addAlert,
    acknowledgeAlert,
    addLogEntry,
    clearLogs
  };

  // Register callbacks with notification service on mount
  React.useEffect(() => {
    const { notificationService } = require('../services/notificationService');
    
    notificationService.registerNotificationCallback(addNotification);
    notificationService.registerAlertCallback(addAlert);
    notificationService.registerLogCallback(addLogEntry);
  }, [addNotification, addAlert, addLogEntry]);

  return (
    <NotificationContext.Provider value={value}>
      {children}
    </NotificationContext.Provider>
  );
};