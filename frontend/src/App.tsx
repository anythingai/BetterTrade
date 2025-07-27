import React, { useState, useEffect } from 'react';
import { WalletConnection, RiskProfileSelection, PortfolioDashboard, NotificationContainer, AlertPanel, LogDisplay, NotificationDemo } from './components';
import { Wallet, RiskLevel, StrategyPlan } from './types';
import { NotificationProvider } from './contexts/NotificationContext';
import { agentService } from './services/agent';
import './styles/WalletConnection.css';
import './styles/RiskProfileSelection.css';
import './styles/PortfolioDashboard.css';
import './styles/NotificationSystem.css';

export type UserState = 
  | 'disconnected' 
  | 'connecting' 
  | 'connected' 
  | 'depositing'
  | 'selecting_risk' 
  | 'viewing_recommendation' 
  | 'executing' 
  | 'active_strategy' 
  | 'error';

const App: React.FC = () => {
  const [userState, setUserState] = useState<UserState>('disconnected');
  const [demoMode, setDemoMode] = useState(false);
  const [connectedWallet, setConnectedWallet] = useState<Wallet | null>(null);
  const [depositAmount, setDepositAmount] = useState<bigint>(0n);
  const [confirmations, setConfirmations] = useState<number>(0);
  const [selectedRiskLevel, setSelectedRiskLevel] = useState<RiskLevel | null>(null);
  const [approvedStrategy, setApprovedStrategy] = useState<StrategyPlan | null>(null);
  const [showRiskSelection, setShowRiskSelection] = useState(false);
  const [showDashboard, setShowDashboard] = useState(false);
  const [showNotifications, setShowNotifications] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [executionStatus, setExecutionStatus] = useState<any>(null);

  // Initialize demo mode from URL params
  useEffect(() => {
    const urlParams = new URLSearchParams(window.location.search);
    const demo = urlParams.get('demo') === 'true';
    setDemoMode(demo);
    
    if (demo) {
      handleDemoSetup();
    }
  }, []);

  const handleDemoSetup = async () => {
    try {
      setUserState('connecting');
      
      // Create demo wallet
      const demoWallet: Wallet = {
        user_id: 'demo_user_' + Date.now(),
        btc_address: 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx',
        network: 'testnet',
        status: 'active'
      };
      
      setConnectedWallet(demoWallet);
      setDepositAmount(100000000n); // 1 BTC
      setConfirmations(6);
      setUserState('connected');
    } catch (err) {
      setError('Failed to setup demo mode');
      setUserState('error');
    }
  };

  const handleWalletConnected = async (wallet: Wallet) => {
    setConnectedWallet(wallet);
    setUserState('connected');
    
    if (demoMode) {
      // Auto-setup demo data
      setDepositAmount(100000000n);
      setConfirmations(6);
    }
  };

  const handleDepositDetected = (amount: bigint, confirmations: number) => {
    setDepositAmount(amount);
    setConfirmations(confirmations);
    
    if (confirmations >= 6) {
      setUserState('connected');
    } else {
      setUserState('depositing');
    }
  };

  const handleRiskProfileSelected = (riskLevel: RiskLevel) => {
    setSelectedRiskLevel(riskLevel);
    setUserState('viewing_recommendation');
  };

  const handleStrategyApproved = async (plan: StrategyPlan) => {
    try {
      setUserState('executing');
      setApprovedStrategy(plan);
      
      // Simulate execution process
      setExecutionStatus({ status: 'pending', message: 'Preparing transaction...' });
      
      if (demoMode) {
        // Demo execution simulation
        setTimeout(() => {
          setExecutionStatus({ status: 'broadcasting', message: 'Broadcasting to Bitcoin network...' });
        }, 1000);
        
        setTimeout(() => {
          setExecutionStatus({ 
            status: 'confirmed', 
            message: 'Strategy executed successfully!',
            txid: 'demo_tx_' + Date.now()
          });
          setUserState('active_strategy');
          setShowDashboard(true);
        }, 3000);
      } else {
        // Real execution would go here
        const result = await agentService.executeStrategy(plan.id);
        if (result.success) {
          setExecutionStatus(result);
          setUserState('active_strategy');
          setShowDashboard(true);
        } else {
          throw new Error(result.error || 'Execution failed');
        }
      }
      
      setShowRiskSelection(false);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Strategy execution failed');
      setUserState('error');
    }
  };

  const handleStartRiskSelection = () => {
    setShowRiskSelection(true);
    setUserState('selecting_risk');
  };

  const handleViewDashboard = () => {
    setShowDashboard(true);
    setUserState('active_strategy');
  };

  const handleError = (errorMessage: string) => {
    setError(errorMessage);
    setUserState('error');
    setTimeout(() => {
      setError(null);
      setUserState('disconnected');
    }, 5000);
  };

  const handleReset = () => {
    setUserState('disconnected');
    setConnectedWallet(null);
    setDepositAmount(0n);
    setConfirmations(0);
    setSelectedRiskLevel(null);
    setApprovedStrategy(null);
    setShowRiskSelection(false);
    setShowDashboard(false);
    setError(null);
    setExecutionStatus(null);
  };

  const handleWithdraw = async () => {
    try {
      if (!connectedWallet) return;
      
      if (demoMode) {
        // Demo withdrawal
        setUserState('connected');
        setApprovedStrategy(null);
        setShowDashboard(false);
      } else {
        const result = await agentService.withdrawFunds(connectedWallet.user_id);
        if (result.success) {
          setUserState('connected');
          setApprovedStrategy(null);
          setShowDashboard(false);
        } else {
          throw new Error(result.error || 'Withdrawal failed');
        }
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Withdrawal failed');
    }
  };

  const formatSats = (sats: bigint): string => {
    return (Number(sats) / 100000000).toFixed(8);
  };

  return (
    <NotificationProvider>
      <div className="app">
        <NotificationContainer />
        
        {error && (
          <div className="error-banner">
            <span>⚠️ {error}</span>
            <button type="button" onClick={() => setError(null)}>×</button>
          </div>
        )}
        
        {showDashboard && connectedWallet ? (
          <div>
            <div className="dashboard-header">
              <h1>BetterTrade Dashboard</h1>
              <div className="dashboard-controls">
                <button 
                  type="button"
                  onClick={() => setShowNotifications(!showNotifications)}
                  className="notifications-toggle-btn"
                >
                  {showNotifications ? 'Hide' : 'Show'} Notifications
                </button>
                <button 
                  type="button"
                  onClick={() => setShowDashboard(false)}
                  className="back-btn"
                >
                  ← Back to Overview
                </button>
              </div>
            </div>
            
            {showNotifications && (
              <div className="notifications-panel">
                <NotificationDemo className="notification-demo-card" />
                <div className="notifications-grid">
                  <AlertPanel className="alert-panel-card" />
                  <LogDisplay className="log-display-card" maxEntries={50} />
                </div>
              </div>
            )}
            
            <PortfolioDashboard 
              userId={connectedWallet.user_id}
              onError={handleError}
            />
          </div>
        ) : (
        <div className="card">
          <h2>Welcome to BetterTrade</h2>
          <p>Your Bitcoin DeFi Copilot - Automated yield strategies for your Bitcoin</p>
          
          <WalletConnection 
            onWalletConnected={handleWalletConnected}
            onDepositDetected={handleDepositDetected}
          />

          {connectedWallet && !showRiskSelection && (
            <div className="card next-steps">
              <h3>🎯 Next Steps</h3>
              {approvedStrategy ? (
                <div>
                  <p>✅ Strategy approved and executing!</p>
                  <p>Your {selectedRiskLevel} strategy is now active with an estimated APY of up to 15%.</p>
                  <div className="strategy-status">
                    <p><strong>Active Strategy:</strong> {approvedStrategy.template_id}</p>
                    <p><strong>Status:</strong> {approvedStrategy.status}</p>
                  </div>
                  <button 
                    type="button"
                    className="primary-btn"
                    onClick={handleViewDashboard}
                  >
                    View Portfolio Dashboard →
                  </button>
                </div>
              ) : depositAmount > 0n && confirmations >= 6 ? (
                <div>
                  <p>✅ Your deposit of {formatSats(depositAmount)} BTC is confirmed!</p>
                  <p>You can now proceed to select your risk profile and start earning yield.</p>
                  <button 
                    type="button"
                    className="primary-btn"
                    onClick={handleStartRiskSelection}
                  >
                    Select Risk Profile →
                  </button>
                </div>
              ) : depositAmount > 0n ? (
                <div>
                  <p>⏳ Waiting for your deposit to confirm ({confirmations}/6 confirmations)</p>
                  <p>Once confirmed, you&apos;ll be able to select your risk profile and start earning yield.</p>
                </div>
              ) : (
                <div>
                  <p>📥 Send testnet Bitcoin to your connected wallet address to get started</p>
                  <p>Minimum deposit: 0.001 BTC</p>
                </div>
              )}
            </div>
          )}

          {showRiskSelection && connectedWallet && (
            <div className="card">
              <RiskProfileSelection
                userId={connectedWallet.user_id}
                onRiskProfileSelected={handleRiskProfileSelected}
                onStrategyApproved={handleStrategyApproved}
              />
            </div>
          )}

          <div className="card system-status">
            <h3>System Status</h3>
            <ul>
              <li>✅ Project structure initialized</li>
              <li>✅ User Registry implemented</li>
              <li>✅ Portfolio State implemented</li>
              <li>✅ Strategy Selector implemented</li>
              <li>✅ Execution Agent implemented</li>
              <li>✅ Risk Guard implemented</li>
              <li>{connectedWallet ? '✅' : '⏳'} Wallet Connection</li>
            </ul>
          </div>
        </div>
      )}
      </div>
    </NotificationProvider>
  );
};

export default App;