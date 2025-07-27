// Notification and alert type definitions

export enum NotificationType {
  Success = 'success',
  Warning = 'warning',
  Error = 'error',
  Info = 'info'
}

export enum AlertSeverity {
  Low = 'low',
  Medium = 'medium',
  High = 'high',
  Critical = 'critical'
}

export interface Notification {
  id: string;
  type: NotificationType;
  title: string;
  message: string;
  timestamp: number;
  duration?: number; // Auto-dismiss duration in ms, undefined for persistent
  actionLabel?: string;
  onAction?: () => void;
}

export interface Alert {
  id: string;
  severity: AlertSeverity;
  title: string;
  message: string;
  timestamp: number;
  acknowledged: boolean;
  user_id: string;
  related_tx_id?: string;
  threshold_value?: number;
  current_value?: number;
}

export interface LogEntry {
  id: string;
  timestamp: number;
  agent: string;
  action: string;
  transaction_id?: string;
  user_id: string;
  details: Record<string, unknown>;
  level: 'info' | 'warn' | 'error';
}

export interface NotificationContextType {
  notifications: Notification[];
  alerts: Alert[];
  logs: LogEntry[];
  addNotification: (notification: Omit<Notification, 'id' | 'timestamp'>) => void;
  removeNotification: (id: string) => void;
  addAlert: (alert: Omit<Alert, 'id' | 'timestamp' | 'acknowledged'>) => void;
  acknowledgeAlert: (id: string) => void;
  addLogEntry: (entry: Omit<LogEntry, 'id' | 'timestamp'>) => void;
  clearLogs: () => void;
}