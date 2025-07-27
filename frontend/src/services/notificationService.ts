import { 
  NotificationType, 
  AlertSeverity, 
  Notification, 
  Alert, 
  LogEntry 
} from '../types/notifications';
import { TxRecord, TxStatus, TxType } from '../types';

export class NotificationService {
  private static instance: NotificationService;
  private notificationCallbacks: Array<(notification: Omit<Notification, 'id' | 'timestamp'>) => void> = [];
  private alertCallbacks: Array<(alert: Omit<Alert, 'id' | 'timestamp' | 'acknowledged'>) => void> = [];
  private logCallbacks: Array<(entry: Omit<LogEntry, 'id' | 'timestamp'>) => void> = [];

  private constructor() {}

  static getInstance(): NotificationService {
    if (!NotificationService.instance) {
      NotificationService.instance = new NotificationService();
    }
    return NotificationService.instance;
  }

  // Register callbacks from the notification context
  registerNotificationCallback(callback: (notification: Omit<Notification, 'id' | 'timestamp'>) => void) {
    this.notificationCallbacks.push(callback);
  }

  registerAlertCallback(callback: (alert: Omit<Alert, 'id' | 'timestamp' | 'acknowledged'>) => void) {
    this.alertCallbacks.push(callback);
  }

  registerLogCallback(callback: (entry: Omit<LogEntry, 'id' | 'timestamp'>) => void) {
    this.logCallbacks.push(callback);
  }

  // Transaction event notifications
  notifyTransactionConfirmed(tx: TxRecord) {
    const typeLabel = this.getTxTypeLabel(tx.tx_type);
    
    this.notificationCallbacks.forEach(callback => {
      callback({
        type: NotificationType.Success,
        title: 'Transaction Confirmed',
        message: `Your ${typeLabel} of ${this.formatSats(tx.amount_sats)} BTC has been confirmed.`,
        duration: 8000,
        actionLabel: 'View Details',
        onAction: () => {
          // This could navigate to transaction details
        }
      });
    });

    this.logCallbacks.forEach(callback => {
      callback({
        agent: 'Execution Agent',
        action: 'Transaction Confirmed',
        transaction_id: tx.txid,
        user_id: tx.user_id,
        level: 'info',
        details: {
          type: tx.tx_type,
          amount_sats: tx.amount_sats.toString(),
          fee_sats: tx.fee_sats.toString(),
          confirmed_height: tx.confirmed_height
        }
      });
    });
  }

  notifyTransactionFailed(tx: TxRecord, reason?: string) {
    const typeLabel = this.getTxTypeLabel(tx.tx_type);
    
    this.notificationCallbacks.forEach(callback => {
      callback({
        type: NotificationType.Error,
        title: 'Transaction Failed',
        message: `Your ${typeLabel} of ${this.formatSats(tx.amount_sats)} BTC has failed. ${reason || ''}`,
        duration: 0, // Persistent for errors
        actionLabel: 'Retry',
        onAction: () => {
          // This could trigger a retry
        }
      });
    });

    this.logCallbacks.forEach(callback => {
      callback({
        agent: 'Execution Agent',
        action: 'Transaction Failed',
        transaction_id: tx.txid,
        user_id: tx.user_id,
        level: 'error',
        details: {
          type: tx.tx_type,
          amount_sats: tx.amount_sats.toString(),
          reason: reason || 'Unknown error'
        }
      });
    });
  }

  notifyTransactionPending(tx: TxRecord) {
    const typeLabel = this.getTxTypeLabel(tx.tx_type);
    
    this.notificationCallbacks.forEach(callback => {
      callback({
        type: NotificationType.Info,
        title: 'Transaction Pending',
        message: `Your ${typeLabel} of ${this.formatSats(tx.amount_sats)} BTC is being processed.`,
        duration: 5000
      });
    });

    this.logCallbacks.forEach(callback => {
      callback({
        agent: 'Execution Agent',
        action: 'Transaction Submitted',
        transaction_id: tx.txid,
        user_id: tx.user_id,
        level: 'info',
        details: {
          type: tx.tx_type,
          amount_sats: tx.amount_sats.toString(),
          fee_sats: tx.fee_sats.toString()
        }
      });
    });
  }

  // Risk threshold alerts
  notifyRiskThresholdBreach(
    userId: string, 
    thresholdType: string, 
    thresholdValue: number, 
    currentValue: number,
    severity: AlertSeverity = AlertSeverity.High
  ) {
    this.alertCallbacks.forEach(callback => {
      callback({
        severity,
        title: 'Risk Threshold Breached',
        message: `Your ${thresholdType} has exceeded the configured threshold of ${thresholdValue.toFixed(2)}%. Current value: ${currentValue.toFixed(2)}%.`,
        user_id: userId,
        threshold_value: thresholdValue,
        current_value: currentValue
      });
    });

    this.logCallbacks.forEach(callback => {
      callback({
        agent: 'Risk Guard',
        action: 'Threshold Breach Detected',
        user_id: userId,
        level: 'warn',
        details: {
          threshold_type: thresholdType,
          threshold_value: thresholdValue,
          current_value: currentValue,
          severity
        }
      });
    });
  }

  // Strategy recommendation notifications
  notifyStrategyRecommendationChanged(userId: string, oldStrategy: string, newStrategy: string, reason: string) {
    this.notificationCallbacks.forEach(callback => {
      callback({
        type: NotificationType.Info,
        title: 'Strategy Recommendation Updated',
        message: `Based on current market conditions, we recommend switching from ${oldStrategy} to ${newStrategy}. ${reason}`,
        duration: 10000,
        actionLabel: 'Review',
        onAction: () => {
          // Navigate to strategy selection
        }
      });
    });

    this.logCallbacks.forEach(callback => {
      callback({
        agent: 'Strategy Selector',
        action: 'Recommendation Changed',
        user_id: userId,
        level: 'info',
        details: {
          old_strategy: oldStrategy,
          new_strategy: newStrategy,
          reason
        }
      });
    });
  }

  // Portfolio performance notifications
  notifyPortfolioMilestone(userId: string, milestone: string, value: number) {
    this.notificationCallbacks.forEach(callback => {
      callback({
        type: NotificationType.Success,
        title: 'Portfolio Milestone',
        message: `Congratulations! Your portfolio has reached ${milestone}: ${value.toFixed(2)}%.`,
        duration: 8000
      });
    });

    this.logCallbacks.forEach(callback => {
      callback({
        agent: 'Portfolio State',
        action: 'Milestone Reached',
        user_id: userId,
        level: 'info',
        details: {
          milestone,
          value
        }
      });
    });
  }

  // System status notifications
  notifySystemEvent(agent: string, action: string, userId: string, details: Record<string, unknown>, level: 'info' | 'warn' | 'error' = 'info') {
    this.logCallbacks.forEach(callback => {
      callback({
        agent,
        action,
        user_id: userId,
        level,
        details
      });
    });

    // For critical system events, also show as notification
    if (level === 'error') {
      this.notificationCallbacks.forEach(callback => {
        callback({
          type: NotificationType.Error,
          title: 'System Error',
          message: `${agent}: ${action}`,
          duration: 0 // Persistent for errors
        });
      });
    }
  }

  // Helper methods
  private getTxTypeLabel(txType: TxType): string {
    switch (txType) {
      case TxType.Deposit:
        return 'deposit';
      case TxType.Withdraw:
        return 'withdrawal';
      case TxType.StrategyExecute:
        return 'strategy execution';
      case TxType.Rebalance:
        return 'rebalance';
      default:
        return 'transaction';
    }
  }

  private formatSats(sats: bigint): string {
    return (Number(sats) / 100000000).toFixed(8);
  }

  // Mock methods for development/testing
  generateMockTransactionEvent(userId: string) {
    const mockTx: TxRecord = {
      txid: `mock-${Date.now()}-${Math.random().toString(36).substring(2, 11)}`,
      user_id: userId,
      tx_type: TxType.StrategyExecute,
      amount_sats: BigInt(Math.floor(Math.random() * 50000000) + 10000000), // 0.1 to 0.5 BTC
      fee_sats: BigInt(Math.floor(Math.random() * 5000) + 1000),
      status: TxStatus.Confirmed,
      confirmed_height: 825000 + Math.floor(Math.random() * 100),
      timestamp: Math.floor(Date.now() / 1000)
    };

    this.notifyTransactionConfirmed(mockTx);
  }

  generateMockRiskAlert(userId: string) {
    const thresholds = [
      { type: 'drawdown', value: 15, current: 18.5, severity: AlertSeverity.High },
      { type: 'volatility', value: 25, current: 28.2, severity: AlertSeverity.Medium },
      { type: 'liquidity', value: 10, current: 12.1, severity: AlertSeverity.Critical }
    ];

    const threshold = thresholds[Math.floor(Math.random() * thresholds.length)];
    this.notifyRiskThresholdBreach(userId, threshold.type, threshold.value, threshold.current, threshold.severity);
  }
}

export const notificationService = NotificationService.getInstance();