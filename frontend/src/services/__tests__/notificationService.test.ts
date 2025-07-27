import { notificationService } from '../notificationService';
import { NotificationType, AlertSeverity } from '../../types/notifications';
import { TxType, TxStatus } from '../../types';

describe('NotificationService', () => {
  let mockNotificationCallback: jest.Mock;
  let mockAlertCallback: jest.Mock;
  let mockLogCallback: jest.Mock;

  beforeEach(() => {
    mockNotificationCallback = jest.fn();
    mockAlertCallback = jest.fn();
    mockLogCallback = jest.fn();

    // Register callbacks
    notificationService.registerNotificationCallback(mockNotificationCallback);
    notificationService.registerAlertCallback(mockAlertCallback);
    notificationService.registerLogCallback(mockLogCallback);

    jest.clearAllMocks();
  });

  describe('Transaction Notifications', () => {
    const mockTxRecord = {
      txid: 'test-tx-123',
      user_id: 'user-123',
      tx_type: TxType.StrategyExecute,
      amount_sats: 50000000n, // 0.5 BTC
      fee_sats: 2500n,
      status: TxStatus.Confirmed,
      confirmed_height: 825000,
      timestamp: Math.floor(Date.now() / 1000)
    };

    it('notifies transaction confirmed', () => {
      notificationService.notifyTransactionConfirmed(mockTxRecord);

      expect(mockNotificationCallback).toHaveBeenCalledWith({
        type: NotificationType.Success,
        title: 'Transaction Confirmed',
        message: 'Your strategy execution of 0.50000000 BTC has been confirmed.',
        duration: 8000,
        actionLabel: 'View Details',
        onAction: expect.any(Function)
      });

      expect(mockLogCallback).toHaveBeenCalledWith({
        agent: 'Execution Agent',
        action: 'Transaction Confirmed',
        transaction_id: 'test-tx-123',
        user_id: 'user-123',
        level: 'info',
        details: {
          type: TxType.StrategyExecute,
          amount_sats: '50000000',
          fee_sats: '2500',
          confirmed_height: 825000
        }
      });
    });

    it('notifies transaction failed', () => {
      const reason = 'Insufficient balance';
      notificationService.notifyTransactionFailed(mockTxRecord, reason);

      expect(mockNotificationCallback).toHaveBeenCalledWith({
        type: NotificationType.Error,
        title: 'Transaction Failed',
        message: 'Your strategy execution of 0.50000000 BTC has failed. Insufficient balance',
        duration: 0, // Persistent for errors
        actionLabel: 'Retry',
        onAction: expect.any(Function)
      });

      expect(mockLogCallback).toHaveBeenCalledWith({
        agent: 'Execution Agent',
        action: 'Transaction Failed',
        transaction_id: 'test-tx-123',
        user_id: 'user-123',
        level: 'error',
        details: {
          type: TxType.StrategyExecute,
          amount_sats: '50000000',
          reason: 'Insufficient balance'
        }
      });
    });

    it('notifies transaction pending', () => {
      notificationService.notifyTransactionPending(mockTxRecord);

      expect(mockNotificationCallback).toHaveBeenCalledWith({
        type: NotificationType.Info,
        title: 'Transaction Pending',
        message: 'Your strategy execution of 0.50000000 BTC is being processed.',
        duration: 5000
      });

      expect(mockLogCallback).toHaveBeenCalledWith({
        agent: 'Execution Agent',
        action: 'Transaction Submitted',
        transaction_id: 'test-tx-123',
        user_id: 'user-123',
        level: 'info',
        details: {
          type: TxType.StrategyExecute,
          amount_sats: '50000000',
          fee_sats: '2500'
        }
      });
    });

    it('handles different transaction types correctly', () => {
      const depositTx = { ...mockTxRecord, tx_type: TxType.Deposit };
      notificationService.notifyTransactionConfirmed(depositTx);

      expect(mockNotificationCallback).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'Your deposit of 0.50000000 BTC has been confirmed.'
        })
      );

      const withdrawTx = { ...mockTxRecord, tx_type: TxType.Withdraw };
      notificationService.notifyTransactionConfirmed(withdrawTx);

      expect(mockNotificationCallback).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'Your withdrawal of 0.50000000 BTC has been confirmed.'
        })
      );

      const rebalanceTx = { ...mockTxRecord, tx_type: TxType.Rebalance };
      notificationService.notifyTransactionConfirmed(rebalanceTx);

      expect(mockNotificationCallback).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'Your rebalance of 0.50000000 BTC has been confirmed.'
        })
      );
    });
  });

  describe('Risk Threshold Alerts', () => {
    it('notifies risk threshold breach', () => {
      notificationService.notifyRiskThresholdBreach(
        'user-123',
        'drawdown',
        15,
        18.5,
        AlertSeverity.High
      );

      expect(mockAlertCallback).toHaveBeenCalledWith({
        severity: AlertSeverity.High,
        title: 'Risk Threshold Breached',
        message: 'Your drawdown has exceeded the configured threshold of 15.00%. Current value: 18.50%.',
        user_id: 'user-123',
        threshold_value: 15,
        current_value: 18.5
      });

      expect(mockLogCallback).toHaveBeenCalledWith({
        agent: 'Risk Guard',
        action: 'Threshold Breach Detected',
        user_id: 'user-123',
        level: 'warn',
        details: {
          threshold_type: 'drawdown',
          threshold_value: 15,
          current_value: 18.5,
          severity: AlertSeverity.High
        }
      });
    });

    it('uses default severity when not provided', () => {
      notificationService.notifyRiskThresholdBreach('user-123', 'volatility', 25, 28.2);

      expect(mockAlertCallback).toHaveBeenCalledWith(
        expect.objectContaining({
          severity: AlertSeverity.High // Default
        })
      );
    });
  });

  describe('Strategy Notifications', () => {
    it('notifies strategy recommendation changed', () => {
      notificationService.notifyStrategyRecommendationChanged(
        'user-123',
        'Aggressive Growth',
        'Conservative Lending',
        'Market volatility has increased significantly.'
      );

      expect(mockNotificationCallback).toHaveBeenCalledWith({
        type: NotificationType.Info,
        title: 'Strategy Recommendation Updated',
        message: 'Based on current market conditions, we recommend switching from Aggressive Growth to Conservative Lending. Market volatility has increased significantly.',
        duration: 10000,
        actionLabel: 'Review',
        onAction: expect.any(Function)
      });

      expect(mockLogCallback).toHaveBeenCalledWith({
        agent: 'Strategy Selector',
        action: 'Recommendation Changed',
        user_id: 'user-123',
        level: 'info',
        details: {
          old_strategy: 'Aggressive Growth',
          new_strategy: 'Conservative Lending',
          reason: 'Market volatility has increased significantly.'
        }
      });
    });
  });

  describe('Portfolio Notifications', () => {
    it('notifies portfolio milestone', () => {
      notificationService.notifyPortfolioMilestone('user-123', '10% profit', 10.5);

      expect(mockNotificationCallback).toHaveBeenCalledWith({
        type: NotificationType.Success,
        title: 'Portfolio Milestone',
        message: 'Congratulations! Your portfolio has reached 10% profit: 10.50%.',
        duration: 8000
      });

      expect(mockLogCallback).toHaveBeenCalledWith({
        agent: 'Portfolio State',
        action: 'Milestone Reached',
        user_id: 'user-123',
        level: 'info',
        details: {
          milestone: '10% profit',
          value: 10.5
        }
      });
    });
  });

  describe('System Events', () => {
    it('notifies system event with info level', () => {
      notificationService.notifySystemEvent(
        'Test Agent',
        'Test Action',
        'user-123',
        { key: 'value' },
        'info'
      );

      expect(mockLogCallback).toHaveBeenCalledWith({
        agent: 'Test Agent',
        action: 'Test Action',
        user_id: 'user-123',
        level: 'info',
        details: { key: 'value' }
      });

      expect(mockNotificationCallback).not.toHaveBeenCalled();
    });

    it('notifies system event with error level and creates notification', () => {
      notificationService.notifySystemEvent(
        'Test Agent',
        'Critical Error',
        'user-123',
        { error: 'Something went wrong' },
        'error'
      );

      expect(mockLogCallback).toHaveBeenCalledWith({
        agent: 'Test Agent',
        action: 'Critical Error',
        user_id: 'user-123',
        level: 'error',
        details: { error: 'Something went wrong' }
      });

      expect(mockNotificationCallback).toHaveBeenCalledWith({
        type: NotificationType.Error,
        title: 'System Error',
        message: 'Test Agent: Critical Error',
        duration: 0
      });
    });

    it('uses default info level when not specified', () => {
      notificationService.notifySystemEvent('Test Agent', 'Test Action', 'user-123', {});

      expect(mockLogCallback).toHaveBeenCalledWith(
        expect.objectContaining({
          level: 'info'
        })
      );
    });
  });

  describe('Mock Methods', () => {
    it('generates mock transaction event', () => {
      notificationService.generateMockTransactionEvent('user-123');

      expect(mockNotificationCallback).toHaveBeenCalledWith(
        expect.objectContaining({
          type: NotificationType.Success,
          title: 'Transaction Confirmed'
        })
      );

      expect(mockLogCallback).toHaveBeenCalledWith(
        expect.objectContaining({
          agent: 'Execution Agent',
          action: 'Transaction Confirmed',
          user_id: 'user-123',
          level: 'info'
        })
      );
    });

    it('generates mock risk alert', () => {
      notificationService.generateMockRiskAlert('user-123');

      expect(mockAlertCallback).toHaveBeenCalledWith(
        expect.objectContaining({
          title: 'Risk Threshold Breached',
          user_id: 'user-123'
        })
      );

      expect(mockLogCallback).toHaveBeenCalledWith(
        expect.objectContaining({
          agent: 'Risk Guard',
          action: 'Threshold Breach Detected',
          user_id: 'user-123',
          level: 'warn'
        })
      );
    });
  });

  describe('Helper Methods', () => {
    it('formats satoshis correctly', () => {
      // Test through transaction notification
      const txRecord = {
        txid: 'test-tx',
        user_id: 'user-123',
        tx_type: TxType.Deposit,
        amount_sats: 100000000n, // 1 BTC
        fee_sats: 1000n,
        status: TxStatus.Confirmed,
        timestamp: Math.floor(Date.now() / 1000)
      };

      notificationService.notifyTransactionConfirmed(txRecord);

      expect(mockNotificationCallback).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'Your deposit of 1.00000000 BTC has been confirmed.'
        })
      );
    });

    it('handles small amounts correctly', () => {
      const txRecord = {
        txid: 'test-tx',
        user_id: 'user-123',
        tx_type: TxType.Deposit,
        amount_sats: 1000n, // 0.00001 BTC
        fee_sats: 100n,
        status: TxStatus.Confirmed,
        timestamp: Math.floor(Date.now() / 1000)
      };

      notificationService.notifyTransactionConfirmed(txRecord);

      expect(mockNotificationCallback).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'Your deposit of 0.00001000 BTC has been confirmed.'
        })
      );
    });
  });

  describe('Singleton Pattern', () => {
    it('returns the same instance', () => {
      const { NotificationService } = require('../notificationService');
      const instance1 = NotificationService.getInstance();
      const instance2 = NotificationService.getInstance();

      expect(instance1).toBe(instance2);
    });
  });

  describe('Multiple Callbacks', () => {
    it('calls all registered notification callbacks', () => {
      const secondCallback = jest.fn();
      notificationService.registerNotificationCallback(secondCallback);

      const txRecord = {
        txid: 'test-tx',
        user_id: 'user-123',
        tx_type: TxType.Deposit,
        amount_sats: 50000000n,
        fee_sats: 2500n,
        status: TxStatus.Confirmed,
        timestamp: Math.floor(Date.now() / 1000)
      };

      notificationService.notifyTransactionConfirmed(txRecord);

      expect(mockNotificationCallback).toHaveBeenCalled();
      expect(secondCallback).toHaveBeenCalled();
    });

    it('calls all registered alert callbacks', () => {
      const secondCallback = jest.fn();
      notificationService.registerAlertCallback(secondCallback);

      notificationService.notifyRiskThresholdBreach('user-123', 'drawdown', 15, 18.5);

      expect(mockAlertCallback).toHaveBeenCalled();
      expect(secondCallback).toHaveBeenCalled();
    });

    it('calls all registered log callbacks', () => {
      const secondCallback = jest.fn();
      notificationService.registerLogCallback(secondCallback);

      notificationService.notifySystemEvent('Test Agent', 'Test Action', 'user-123', {});

      expect(mockLogCallback).toHaveBeenCalled();
      expect(secondCallback).toHaveBeenCalled();
    });
  });
});