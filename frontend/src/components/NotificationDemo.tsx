import React from 'react';
import { useNotifications } from '../contexts/NotificationContext';
import { NotificationType, AlertSeverity } from '../types/notifications';
import { notificationService } from '../services/notificationService';

interface NotificationDemoProps {
  className?: string;
}

export const NotificationDemo: React.FC<NotificationDemoProps> = ({ className = '' }) => {
  const { addNotification, addAlert, addLogEntry } = useNotifications();

  const handleAddSuccessNotification = () => {
    addNotification({
      type: NotificationType.Success,
      title: 'Transaction Confirmed',
      message: 'Your Bitcoin deposit of 0.5 BTC has been confirmed.',
      duration: 5000,
      actionLabel: 'View Details',
      onAction: () => { /* View transaction details */ }
    });
  };

  const handleAddErrorNotification = () => {
    addNotification({
      type: NotificationType.Error,
      title: 'Transaction Failed',
      message: 'Your withdrawal request could not be processed due to insufficient balance.',
      duration: 0, // Persistent
      actionLabel: 'Retry',
      onAction: () => { /* Retry transaction */ }
    });
  };

  const handleAddWarningNotification = () => {
    addNotification({
      type: NotificationType.Warning,
      title: 'High Volatility Detected',
      message: 'Bitcoin price volatility is unusually high. Consider reviewing your strategy.',
      duration: 8000
    });
  };

  const handleAddInfoNotification = () => {
    addNotification({
      type: NotificationType.Info,
      title: 'Strategy Recommendation',
      message: 'Based on current market conditions, we recommend switching to a conservative strategy.',
      duration: 10000,
      actionLabel: 'Review',
      onAction: () => { /* Review strategy */ }
    });
  };

  const handleAddCriticalAlert = () => {
    addAlert({
      severity: AlertSeverity.Critical,
      title: 'Critical Risk Threshold Breached',
      message: 'Your portfolio has exceeded the maximum drawdown limit of 15%. Current drawdown: 18.5%.',
      user_id: 'demo-user',
      threshold_value: 15,
      current_value: 18.5,
      related_tx_id: 'tx-demo-123'
    });
  };

  const handleAddHighAlert = () => {
    addAlert({
      severity: AlertSeverity.High,
      title: 'High Volatility Alert',
      message: 'Market volatility has increased significantly. Consider reviewing your risk settings.',
      user_id: 'demo-user',
      threshold_value: 25,
      current_value: 32.1
    });
  };

  const handleAddMediumAlert = () => {
    addAlert({
      severity: AlertSeverity.Medium,
      title: 'Strategy Performance Notice',
      message: 'Your current strategy is underperforming compared to market benchmarks.',
      user_id: 'demo-user'
    });
  };

  const handleAddLowAlert = () => {
    addAlert({
      severity: AlertSeverity.Low,
      title: 'Portfolio Milestone',
      message: 'Congratulations! Your portfolio has reached 10% profit.',
      user_id: 'demo-user'
    });
  };

  const handleAddInfoLog = () => {
    addLogEntry({
      agent: 'Execution Agent',
      action: 'Transaction Confirmed',
      transaction_id: 'tx-demo-456',
      user_id: 'demo-user',
      level: 'info',
      details: {
        type: 'strategy_execute',
        amount_sats: '50000000',
        fee_sats: '2500',
        confirmed_height: 825123
      }
    });
  };

  const handleAddWarningLog = () => {
    addLogEntry({
      agent: 'Risk Guard',
      action: 'Threshold Monitoring',
      user_id: 'demo-user',
      level: 'warn',
      details: {
        threshold_type: 'drawdown',
        current_value: 12.5,
        threshold_value: 15,
        status: 'approaching_limit'
      }
    });
  };

  const handleAddErrorLog = () => {
    addLogEntry({
      agent: 'Strategy Selector',
      action: 'Recommendation Failed',
      user_id: 'demo-user',
      level: 'error',
      details: {
        error: 'Market data unavailable',
        retry_count: 3,
        last_attempt: new Date().toISOString()
      }
    });
  };

  const handleGenerateMockTransaction = () => {
    notificationService.generateMockTransactionEvent('demo-user');
  };

  const handleGenerateMockRiskAlert = () => {
    notificationService.generateMockRiskAlert('demo-user');
  };

  return (
    <div className={`notification-demo ${className}`}>
      <h3>Notification System Demo</h3>
      
      <div className="demo-section">
        <h4>Toast Notifications</h4>
        <div className="demo-buttons">
          <button type="button" onClick={handleAddSuccessNotification} className="demo-btn success">
            Success Notification
          </button>
          <button type="button" onClick={handleAddErrorNotification} className="demo-btn error">
            Error Notification
          </button>
          <button type="button" onClick={handleAddWarningNotification} className="demo-btn warning">
            Warning Notification
          </button>
          <button type="button" onClick={handleAddInfoNotification} className="demo-btn info">
            Info Notification
          </button>
        </div>
      </div>

      <div className="demo-section">
        <h4>Risk Alerts</h4>
        <div className="demo-buttons">
          <button type="button" onClick={handleAddCriticalAlert} className="demo-btn critical">
            Critical Alert
          </button>
          <button type="button" onClick={handleAddHighAlert} className="demo-btn high">
            High Alert
          </button>
          <button type="button" onClick={handleAddMediumAlert} className="demo-btn medium">
            Medium Alert
          </button>
          <button type="button" onClick={handleAddLowAlert} className="demo-btn low">
            Low Alert
          </button>
        </div>
      </div>

      <div className="demo-section">
        <h4>System Logs</h4>
        <div className="demo-buttons">
          <button type="button" onClick={handleAddInfoLog} className="demo-btn info">
            Info Log
          </button>
          <button type="button" onClick={handleAddWarningLog} className="demo-btn warning">
            Warning Log
          </button>
          <button type="button" onClick={handleAddErrorLog} className="demo-btn error">
            Error Log
          </button>
        </div>
      </div>

      <div className="demo-section">
        <h4>Service Integration</h4>
        <div className="demo-buttons">
          <button type="button" onClick={handleGenerateMockTransaction} className="demo-btn service">
            Mock Transaction Event
          </button>
          <button type="button" onClick={handleGenerateMockRiskAlert} className="demo-btn service">
            Mock Risk Alert
          </button>
        </div>
      </div>

      <style>{`
        .notification-demo {
          background: white;
          border-radius: 8px;
          border: 1px solid #e5e7eb;
          padding: 20px;
          margin: 20px 0;
        }

        .notification-demo h3 {
          margin: 0 0 20px 0;
          color: #1f2937;
        }

        .demo-section {
          margin-bottom: 24px;
        }

        .demo-section h4 {
          margin: 0 0 12px 0;
          color: #374151;
          font-size: 16px;
        }

        .demo-buttons {
          display: flex;
          flex-wrap: wrap;
          gap: 8px;
        }

        .demo-btn {
          padding: 8px 16px;
          border: none;
          border-radius: 6px;
          font-size: 14px;
          font-weight: 500;
          cursor: pointer;
          transition: all 0.2s;
        }

        .demo-btn:hover {
          transform: translateY(-1px);
          box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        }

        .demo-btn.success {
          background: #10b981;
          color: white;
        }

        .demo-btn.success:hover {
          background: #059669;
        }

        .demo-btn.error {
          background: #ef4444;
          color: white;
        }

        .demo-btn.error:hover {
          background: #dc2626;
        }

        .demo-btn.warning {
          background: #f59e0b;
          color: white;
        }

        .demo-btn.warning:hover {
          background: #d97706;
        }

        .demo-btn.info {
          background: #3b82f6;
          color: white;
        }

        .demo-btn.info:hover {
          background: #2563eb;
        }

        .demo-btn.critical {
          background: #dc2626;
          color: white;
        }

        .demo-btn.critical:hover {
          background: #b91c1c;
        }

        .demo-btn.high {
          background: #f59e0b;
          color: white;
        }

        .demo-btn.high:hover {
          background: #d97706;
        }

        .demo-btn.medium {
          background: #3b82f6;
          color: white;
        }

        .demo-btn.medium:hover {
          background: #2563eb;
        }

        .demo-btn.low {
          background: #10b981;
          color: white;
        }

        .demo-btn.low:hover {
          background: #059669;
        }

        .demo-btn.service {
          background: #6b7280;
          color: white;
        }

        .demo-btn.service:hover {
          background: #4b5563;
        }

        @media (max-width: 768px) {
          .demo-buttons {
            flex-direction: column;
          }

          .demo-btn {
            width: 100%;
          }
        }
      `}</style>
    </div>
  );
};