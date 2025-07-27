import React, { useState, useEffect, useRef, useCallback } from 'react';
import { PortfolioSummary, TxRecord, UserId, TxStatus, TxType } from '../types';
import { agentService } from '../services/agent';
import { notificationService } from '../services/notificationService';

interface PortfolioDashboardProps {
  userId: UserId;
  onError?: (error: string) => void;
}

export const PortfolioDashboard: React.FC<PortfolioDashboardProps> = ({ 
  userId, 
  onError 
}) => {
  const [portfolio, setPortfolio] = useState<PortfolioSummary | null>(null);
  const [transactions, setTransactions] = useState<TxRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const previousTransactions = useRef<TxRecord[]>([]);

  // Format satoshis to BTC
  const formatBTC = (sats: bigint): string => {
    return (Number(sats) / 100000000).toFixed(8);
  };

  // Format USD values
  const formatUSD = (value: number): string => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(value);
  };

  // Format percentage
  const formatPercentage = (value: number): string => {
    const sign = value >= 0 ? '+' : '';
    return `${sign}${value.toFixed(2)}%`;
  };

  // Format timestamp
  const formatTimestamp = (timestamp: number): string => {
    return new Date(timestamp * 1000).toLocaleString();
  };

  // Get status badge class
  const getStatusBadgeClass = (status: TxStatus): string => {
    switch (status) {
      case TxStatus.Confirmed:
        return 'status-badge confirmed';
      case TxStatus.Pending:
        return 'status-badge pending';
      case TxStatus.Failed:
        return 'status-badge failed';
      default:
        return 'status-badge';
    }
  };

  // Get transaction type display
  const getTxTypeDisplay = (type: TxType): string => {
    switch (type) {
      case TxType.Deposit:
        return 'Deposit';
      case TxType.Withdraw:
        return 'Withdraw';
      case TxType.StrategyExecute:
        return 'Strategy Execute';
      case TxType.Rebalance:
        return 'Rebalance';
      default:
        return 'Unknown';
    }
  };

  // Load portfolio data
  const loadPortfolioData = useCallback(async (showRefreshing = false) => {
    try {
      if (showRefreshing) {
        setRefreshing(true);
      } else {
        setLoading(true);
      }

      // Load portfolio summary
      const portfolioResult = await agentService.getPortfolio(userId);
      if ('ok' in portfolioResult) {
        setPortfolio(portfolioResult.ok);
      } else {
        onError?.(`Failed to load portfolio: ${portfolioResult.err.message}`);
      }

      // Load transaction history
      const txResult = await agentService.getTransactionHistory(userId);
      if ('ok' in txResult) {
        const newTransactions = txResult.ok;
        
        // Check for new transactions and trigger notifications
        if (previousTransactions.current.length > 0) {
          const newTxIds = new Set(previousTransactions.current.map(tx => tx.txid));
          const addedTransactions = newTransactions.filter(tx => !newTxIds.has(tx.txid));
          
          // Check for status changes in existing transactions
          const existingTxMap = new Map(previousTransactions.current.map(tx => [tx.txid, tx]));
          const updatedTransactions = newTransactions.filter(tx => {
            const existing = existingTxMap.get(tx.txid);
            return existing && existing.status !== tx.status;
          });
          
          // Trigger notifications for new transactions
          addedTransactions.forEach(tx => {
            if (tx.status === TxStatus.Pending) {
              notificationService.notifyTransactionPending(tx);
            } else if (tx.status === TxStatus.Confirmed) {
              notificationService.notifyTransactionConfirmed(tx);
            } else if (tx.status === TxStatus.Failed) {
              notificationService.notifyTransactionFailed(tx);
            }
          });
          
          // Trigger notifications for status changes
          updatedTransactions.forEach(tx => {
            if (tx.status === TxStatus.Confirmed) {
              notificationService.notifyTransactionConfirmed(tx);
            } else if (tx.status === TxStatus.Failed) {
              notificationService.notifyTransactionFailed(tx);
            }
          });
        }
        
        previousTransactions.current = newTransactions;
        setTransactions(newTransactions);
      } else {
        onError?.(`Failed to load transactions: ${txResult.err.message}`);
      }
    } catch (error) {
      onError?.(`Error loading portfolio data: ${error}`);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [userId, onError]);

  // Initial load
  useEffect(() => {
    loadPortfolioData();
  }, [loadPortfolioData]);

  // Auto-refresh every 30 seconds
  useEffect(() => {
    const interval = setInterval(() => {
      loadPortfolioData(true);
    }, 30000);

    return () => clearInterval(interval);
  }, [loadPortfolioData]);

  // Manual refresh
  const handleRefresh = () => {
    loadPortfolioData(true);
  };

  if (loading) {
    return (
      <div className="portfolio-dashboard loading">
        <div className="loading-spinner">Loading portfolio...</div>
      </div>
    );
  }

  if (!portfolio) {
    return (
      <div className="portfolio-dashboard error">
        <p>Unable to load portfolio data</p>
        <button type="button" onClick={() => loadPortfolioData()} className="retry-btn">
          Retry
        </button>
      </div>
    );
  }

  return (
    <div className="portfolio-dashboard">
      {/* Portfolio Summary */}
      <div className="portfolio-summary">
        <div className="summary-header">
          <h2>Portfolio Overview</h2>
          <div className="dashboard-actions">
            <button 
              type="button"
              onClick={handleRefresh} 
              className={`refresh-btn ${refreshing ? 'refreshing' : ''}`}
              disabled={refreshing}
            >
              {refreshing ? '↻' : '⟳'} Refresh
            </button>
            
            {process.env.NODE_ENV === 'development' && (
              <div className="demo-actions">
                <button 
                  type="button"
                  onClick={() => notificationService.generateMockTransactionEvent(userId)}
                  className="demo-btn"
                  title="Generate mock transaction notification"
                >
                  📄 Mock TX
                </button>
                <button 
                  type="button"
                  onClick={() => notificationService.generateMockRiskAlert(userId)}
                  className="demo-btn"
                  title="Generate mock risk alert"
                >
                  ⚠️ Mock Alert
                </button>
              </div>
            )}
          </div>
        </div>

        <div className="balance-cards">
          <div className="balance-card primary">
            <h3>Total Balance</h3>
            <div className="balance-amount">
              <span className="btc-amount">{formatBTC(portfolio.total_balance_sats)} BTC</span>
              <span className="usd-amount">{formatUSD(portfolio.total_value_usd)}</span>
            </div>
          </div>

          <div className="balance-card">
            <h3>24h P&L</h3>
            <div className={`pnl-amount ${portfolio.pnl_24h >= 0 ? 'positive' : 'negative'}`}>
              <span className="pnl-value">{formatPercentage(portfolio.pnl_24h)}</span>
            </div>
          </div>

          <div className="balance-card">
            <h3>Active Strategy</h3>
            <div className="strategy-info">
              <span className="strategy-name">
                {portfolio.active_strategy || 'None'}
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* Positions */}
      {portfolio.positions.length > 0 && (
        <div className="positions-section">
          <h3>Active Positions</h3>
          <div className="positions-grid">
            {portfolio.positions.map((position, index) => (
              <div key={index} className="position-card">
                <div className="position-header">
                  <span className="venue-name">{position.venue_id}</span>
                  <span className={`position-pnl ${position.pnl >= 0 ? 'positive' : 'negative'}`}>
                    {formatPercentage((position.pnl / position.current_value) * 100)}
                  </span>
                </div>
                <div className="position-details">
                  <div className="position-amount">
                    <span className="label">Amount:</span>
                    <span className="value">{formatBTC(position.amount_sats)} BTC</span>
                  </div>
                  <div className="position-value">
                    <span className="label">Current Value:</span>
                    <span className="value">{formatUSD(position.current_value)}</span>
                  </div>
                  <div className="position-entry">
                    <span className="label">Entry Price:</span>
                    <span className="value">{formatUSD(position.entry_price)}</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Transaction History */}
      <div className="transaction-history">
        <h3>Transaction History</h3>
        {transactions.length === 0 ? (
          <div className="no-transactions">
            <p>No transactions yet</p>
          </div>
        ) : (
          <div className="transaction-table-container">
            <table className="transaction-table">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Type</th>
                  <th>Amount</th>
                  <th>Fee</th>
                  <th>Status</th>
                  <th>Transaction ID</th>
                </tr>
              </thead>
              <tbody>
                {transactions.map((tx) => (
                  <tr key={tx.txid}>
                    <td className="tx-date">
                      {formatTimestamp(tx.timestamp)}
                    </td>
                    <td className="tx-type">
                      {getTxTypeDisplay(tx.tx_type)}
                    </td>
                    <td className="tx-amount">
                      <span className={tx.tx_type === TxType.Withdraw ? 'negative' : 'positive'}>
                        {tx.tx_type === TxType.Withdraw ? '-' : '+'}
                        {formatBTC(tx.amount_sats)} BTC
                      </span>
                    </td>
                    <td className="tx-fee">
                      {formatBTC(tx.fee_sats)} BTC
                    </td>
                    <td className="tx-status">
                      <span className={getStatusBadgeClass(tx.status)}>
                        {tx.status}
                        {tx.status === TxStatus.Confirmed && tx.confirmed_height && (
                          <span className="block-height">#{tx.confirmed_height}</span>
                        )}
                      </span>
                    </td>
                    <td className="tx-id">
                      <a 
                        href={`https://blockstream.info/testnet/tx/${tx.txid}`}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="tx-link"
                      >
                        {tx.txid.substring(0, 8)}...{tx.txid.substring(tx.txid.length - 8)}
                      </a>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
};