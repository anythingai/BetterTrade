import React, { useState } from 'react';
import { AlertSeverity } from '../types/notifications';
import { useNotifications } from '../contexts/NotificationContext';

interface AlertPanelProps {
  className?: string;
}

export const AlertPanel: React.FC<AlertPanelProps> = ({ className = '' }) => {
  const { alerts, acknowledgeAlert } = useNotifications();
  const [showAcknowledged, setShowAcknowledged] = useState(false);

  const getSeverityIcon = (severity: AlertSeverity): string => {
    switch (severity) {
      case AlertSeverity.Critical:
        return '🚨';
      case AlertSeverity.High:
        return '⚠️';
      case AlertSeverity.Medium:
        return '⚡';
      case AlertSeverity.Low:
      default:
        return 'ℹ️';
    }
  };

  const getSeverityColor = (severity: AlertSeverity): string => {
    switch (severity) {
      case AlertSeverity.Critical:
        return 'critical';
      case AlertSeverity.High:
        return 'high';
      case AlertSeverity.Medium:
        return 'medium';
      case AlertSeverity.Low:
      default:
        return 'low';
    }
  };

  const formatTimestamp = (timestamp: number): string => {
    return new Date(timestamp).toLocaleString();
  };

  const formatValue = (value: number): string => {
    return value.toFixed(2);
  };

  const filteredAlerts = showAcknowledged 
    ? alerts 
    : alerts.filter(alert => !alert.acknowledged);

  const sortedAlerts = [...filteredAlerts].sort((a, b) => {
    // Sort by severity first (critical first), then by timestamp (newest first)
    const severityOrder = { critical: 0, high: 1, medium: 2, low: 3 };
    const severityDiff = severityOrder[a.severity] - severityOrder[b.severity];
    if (severityDiff !== 0) return severityDiff;
    return b.timestamp - a.timestamp;
  });

  const unacknowledgedCount = alerts.filter(alert => !alert.acknowledged).length;

  return (
    <div className={`alert-panel ${className}`}>
      <div className="alert-panel-header">
        <h3>
          Risk Alerts
          {unacknowledgedCount > 0 && (
            <span className="alert-badge">{unacknowledgedCount}</span>
          )}
        </h3>
        <div className="alert-panel-controls">
          <label className="alert-toggle">
            <input
              type="checkbox"
              checked={showAcknowledged}
              onChange={(e) => setShowAcknowledged(e.target.checked)}
            />
            Show acknowledged
          </label>
        </div>
      </div>

      <div className="alert-list">
        {sortedAlerts.length === 0 ? (
          <div className="alert-empty">
            {showAcknowledged ? 'No alerts' : 'No active alerts'}
          </div>
        ) : (
          sortedAlerts.map(alert => (
            <div 
              key={alert.id} 
              className={`alert-item alert-${getSeverityColor(alert.severity)} ${
                alert.acknowledged ? 'acknowledged' : ''
              }`}
            >
              <div className="alert-content">
                <div className="alert-header">
                  <span className="alert-icon">{getSeverityIcon(alert.severity)}</span>
                  <span className="alert-title">{alert.title}</span>
                  <span className="alert-severity">{alert.severity.toUpperCase()}</span>
                  <span className="alert-time">{formatTimestamp(alert.timestamp)}</span>
                </div>
                
                <div className="alert-message">{alert.message}</div>
                
                {(alert.threshold_value !== undefined && alert.current_value !== undefined) && (
                  <div className="alert-values">
                    <span>Threshold: {formatValue(alert.threshold_value)}%</span>
                    <span>Current: {formatValue(alert.current_value)}%</span>
                  </div>
                )}
                
                {alert.related_tx_id && (
                  <div className="alert-tx">
                    Related TX: <code>{alert.related_tx_id.substring(0, 16)}...</code>
                  </div>
                )}
              </div>
              
              {!alert.acknowledged && (
                <div className="alert-actions">
                  <button 
                    type="button"
                    className="alert-acknowledge-btn"
                    onClick={() => acknowledgeAlert(alert.id)}
                  >
                    Acknowledge
                  </button>
                </div>
              )}
            </div>
          ))
        )}
      </div>
    </div>
  );
};