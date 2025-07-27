import React, { useState, useEffect, useCallback } from 'react';
import { Network, WalletStatus, Wallet } from '../types';
import { agentService } from '../services/agent';
import './WalletConnection.css';

interface WalletConnectionProps {
  onWalletConnected: (wallet: Wallet) => void;
  onDepositDetected: (amount: bigint, confirmations: number) => void;
}

interface SupportedWallet {
  name: string;
  id: string;
  icon: string;
  isInstalled: boolean;
  connect: () => Promise<string>;
}

// Define wallet API interfaces
interface UnisatWallet {
  requestAccounts: () => Promise<string[]>;
}

interface XverseProvider {
  connect: () => Promise<{ addresses: Array<{ address: string }> }>;
}

interface XverseProviders {
  BitcoinProvider: XverseProvider;
}

interface LeatherProvider {
  request: (method: string) => Promise<{ result: { addresses: Array<{ type: string; address: string }> } }>;
}

declare global {
  interface Window {
    unisat?: UnisatWallet;
    XverseProviders?: XverseProviders;
    LeatherProvider?: LeatherProvider;
  }
}

const WalletConnection: React.FC<WalletConnectionProps> = ({
  onWalletConnected,
  onDepositDetected
}) => {
  const [isConnecting, setIsConnecting] = useState(false);
  const [connectedWallet, setConnectedWallet] = useState<Wallet | null>(null);
  const [depositAddress, setDepositAddress] = useState<string>('');
  const [depositAmount, setDepositAmount] = useState<bigint>(0n);
  const [confirmations, setConfirmations] = useState<number>(0);
  const [error, setError] = useState<string>('');
  const [supportedWallets, setSupportedWallets] = useState<SupportedWallet[]>([]);

  // Mock wallet implementations for testnet
  const mockWalletConnectors = useCallback(() => ({
    unisat: async (): Promise<string> => {
      // Mock UniSat wallet connection
      if (typeof window !== 'undefined' && window.unisat) {
        const accounts = await window.unisat.requestAccounts();
        return accounts[0];
      }
      // Generate mock testnet address for demo
      return 'tb1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh';
    },
    
    xverse: async (): Promise<string> => {
      // Mock Xverse wallet connection
      if (typeof window !== 'undefined' && window.XverseProviders) {
        const provider = window.XverseProviders.BitcoinProvider;
        const response = await provider.connect();
        return response.addresses[0].address;
      }
      // Generate mock testnet address for demo
      return 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx';
    },
    
    leather: async (): Promise<string> => {
      // Mock Leather wallet connection
      if (typeof window !== 'undefined' && window.LeatherProvider) {
        const response = await window.LeatherProvider.request('getAddresses');
        return response.result.addresses.find((addr) => addr.type === 'p2wpkh')?.address || '';
      }
      // Generate mock testnet address for demo
      return 'tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sL5k7';
    }
  }), []);

  // Detect supported wallets on component mount
  useEffect(() => {
    const detectWallets = () => {
      const connectors = mockWalletConnectors();
      const wallets: SupportedWallet[] = [
        {
          name: 'UniSat',
          id: 'unisat',
          icon: '🦄',
          isInstalled: typeof window !== 'undefined' && !!window.unisat,
          connect: connectors.unisat
        },
        {
          name: 'Xverse',
          id: 'xverse',
          icon: '⚡',
          isInstalled: typeof window !== 'undefined' && !!window.XverseProviders,
          connect: connectors.xverse
        },
        {
          name: 'Leather',
          id: 'leather',
          icon: '🔐',
          isInstalled: typeof window !== 'undefined' && !!window.LeatherProvider,
          connect: connectors.leather
        }
      ];
      
      setSupportedWallets(wallets);
    };

    detectWallets();
  }, [mockWalletConnectors]);

  // Mock deposit detection polling
  useEffect(() => {
    if (!depositAddress) return;

    const pollForDeposits = async () => {
      // Mock deposit detection logic
      // In real implementation, this would query Bitcoin network or ICP Bitcoin API
      const mockDeposit = Math.random() > 0.95; // 5% chance per poll
      
      if (mockDeposit && depositAmount === 0n) {
        const amount = BigInt(Math.floor(Math.random() * 1000000) + 100000); // 0.001 - 0.01 BTC in sats
        setDepositAmount(amount);
        setConfirmations(1);
        onDepositDetected(amount, 1);
      } else if (depositAmount > 0n && confirmations < 6) {
        const newConfirmations = confirmations + 1;
        setConfirmations(newConfirmations);
        onDepositDetected(depositAmount, newConfirmations);
      }
    };

    const interval = setInterval(
      pollForDeposits,
      process.env.NODE_ENV === 'test' ? 100 : 5000 // Poll interval depends on environment
    );
    return () => clearInterval(interval);
  }, [depositAddress, depositAmount, confirmations, onDepositDetected]);

  const handleWalletConnect = async (wallet: SupportedWallet) => {
    setIsConnecting(true);
    setError('');

    try {
      const address = await wallet.connect();
      
      // Link wallet via agent service
      // Link wallet via agent service
      const result = await agentService.linkWallet(address, Network.Testnet);
      if ('ok' in result) {
        const walletId = result.ok;
        const newWallet: Wallet = {
          user_id: walletId.toString(),
          btc_address: address,
          network: Network.Testnet,
          status: WalletStatus.Active
        };
        setConnectedWallet(newWallet);
        setDepositAddress(address);
        onWalletConnected(newWallet);
      } else {
        setError(`Wallet linking failed: ${result.err.message}`);
      }
    } catch (err) {
      setError(`Failed to connect ${wallet.name}: ${err instanceof Error ? err.message : 'Unknown error'}`);
    } finally {
      setIsConnecting(false);
    }
  };

  const handleDisconnect = () => {
    setConnectedWallet(null);
    setDepositAddress('');
    setDepositAmount(0n);
    setConfirmations(0);
  };

  const copyToClipboard = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text);
      // Could add a toast notification here
    } catch {
      // Failed to copy to clipboard
    }
  };

  const formatSats = (sats: bigint): string => {
    return (Number(sats) / 100000000).toFixed(8);
  };

  const getProgressClass = (confirmations: number): string => {
    const progressMap: { [key: number]: string } = {
      0: '0',
      1: '17',
      2: '33',
      3: '50',
      4: '67',
      5: '83',
      6: '100'
    };
    return progressMap[confirmations] || '100';
  };

  if (connectedWallet) {
    return (
      <div className="wallet-connection connected">
        <div className="wallet-header">
          <h3>🔗 Wallet Connected</h3>
          <button type="button" onClick={handleDisconnect} className="disconnect-btn">
            Disconnect
          </button>
        </div>
        
        <div className="wallet-info">
          <div className="address-section">
            <label>Testnet Bitcoin Address:</label>
            <div className="address-display">
              <code>{depositAddress}</code>
              <button 
                type="button"
                onClick={() => copyToClipboard(depositAddress)}
                className="copy-btn"
                title="Copy address"
              >
                📋
              </button>
            </div>
          </div>

          {depositAmount > 0n && (
            <div className="deposit-status">
              <h4>💰 Deposit Detected</h4>
              <div className="deposit-info">
                <p><strong>Amount:</strong> {formatSats(depositAmount)} BTC</p>
                <p><strong>Confirmations:</strong> {confirmations}/6</p>
                <div className="confirmation-bar">
                  <div 
                    className={`confirmation-progress progress-${getProgressClass(confirmations)}`}
                  />
                </div>
                {confirmations >= 6 ? (
                  <p className="confirmed">✅ Fully Confirmed</p>
                ) : (
                  <p className="pending">⏳ Waiting for confirmations...</p>
                )}
              </div>
            </div>
          )}

          {depositAmount === 0n && (
            <div className="deposit-instructions">
              <h4>📥 Send Bitcoin to Start</h4>
              <p>Send testnet Bitcoin to the address above to begin using BetterTrade</p>
              <p><small>Minimum deposit: 0.001 BTC</small></p>
            </div>
          )}
        </div>
      </div>
    );
  }

  return (
    <div className="wallet-connection">
      <h3>🔗 Connect Your Bitcoin Wallet</h3>
      <p>Connect a supported Bitcoin wallet to start using BetterTrade</p>
      
      {error && (
        <div className="error-message">
          ❌ {error}
        </div>
      )}

      <div className="wallet-options">
        {supportedWallets.map((wallet) => (
          <div key={wallet.id} className="wallet-option">
            <button
              type="button"
              onClick={() => handleWalletConnect(wallet)}
              disabled={isConnecting || !wallet.isInstalled}
              className={`wallet-btn ${!wallet.isInstalled ? 'not-installed' : ''}`}
            >
              <span className="wallet-icon">{wallet.icon}</span>
              <span className="wallet-name">{wallet.name}</span>
              {!wallet.isInstalled && <span className="not-installed-text">Not Installed</span>}
            </button>
          </div>
        ))}
      </div>

      {isConnecting && (
        <div className="connecting-status">
          <p>🔄 Connecting wallet...</p>
        </div>
      )}

      <div className="wallet-help">
        <h4>Need a Bitcoin Wallet?</h4>
        <p>For testnet development, we recommend:</p>
        <ul>
          <li><a href="https://unisat.io" target="_blank" rel="noopener noreferrer">UniSat Wallet</a></li>
          <li><a href="https://www.xverse.app" target="_blank" rel="noopener noreferrer">Xverse Wallet</a></li>
          <li><a href="https://leather.io" target="_blank" rel="noopener noreferrer">Leather Wallet</a></li>
        </ul>
      </div>
    </div>
  );
};

export default WalletConnection;