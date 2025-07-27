import React, { act } from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import { PortfolioDashboard } from '../PortfolioDashboard';
import { agentService } from '../../services/agent';
import { PortfolioSummary, TxRecord, TxStatus, TxType, ApiErrorType } from '../../types';

// Mock the agent service
jest.mock('../../services/agent');
const mockAgentService = agentService as jest.Mocked<typeof agentService>;

describe('PortfolioDashboard', () => {
  const mockUserId = 'test-user-123';
  const mockOnError = jest.fn();

  const mockPortfolio: PortfolioSummary = {
    user_id: mockUserId,
    total_balance_sats: 50000000n, // 0.5 BTC
    total_value_usd: 25000,
    positions: [
      {
        user_id: mockUserId,
        venue_id: 'lending-protocol-1',
        amount_sats: 30000000n, // 0.3 BTC
        entry_price: 45000,
        current_value: 15000,
        pnl: 1500
      },
      {
        user_id: mockUserId,
        venue_id: 'liquidity-pool-1',
        amount_sats: 20000000n, // 0.2 BTC
        entry_price: 50000,
        current_value: 10000,
        pnl: -500
      }
    ],
    pnl_24h: 2.5,
    active_strategy: 'balanced-strategy'
  };

  const mockTransactions: TxRecord[] = [
    {
      txid: 'tx123456789abcdef',
      user_id: mockUserId,
      tx_type: TxType.Deposit,
      amount_sats: 50000000n,
      fee_sats: 1000n,
      status: TxStatus.Confirmed,
      confirmed_height: 800000,
      timestamp: 1640995200 // 2022-01-01 00:00:00
    },
    {
      txid: 'tx987654321fedcba',
      user_id: mockUserId,
      tx_type: TxType.StrategyExecute,
      amount_sats: 30000000n,
      fee_sats: 2000n,
      status: TxStatus.Pending,
      timestamp: 1641081600 // 2022-01-02 00:00:00
    }
  ];

  beforeEach(() => {
    jest.clearAllMocks();
    mockAgentService.getPortfolio.mockResolvedValue({ ok: mockPortfolio });
    mockAgentService.getTransactionHistory.mockResolvedValue({ ok: mockTransactions });
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  describe('Loading State', () => {
    it('should show loading spinner initially', () => {
      mockAgentService.getPortfolio.mockImplementation(() => new Promise(() => {}));
      mockAgentService.getTransactionHistory.mockImplementation(() => new Promise(() => {}));

      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      expect(screen.getByText('Loading portfolio...')).toBeInTheDocument();
    });
  });

  describe('Portfolio Summary Display', () => {
    it('should display portfolio balance correctly', async () => {
      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        expect(screen.getByText('0.50000000 BTC')).toBeInTheDocument();
        expect(screen.getByText('$25,000.00')).toBeInTheDocument();
      });
    });

    it('should display 24h P&L with correct styling', async () => {
      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        const pnlElement = screen.getByText('+2.50%');
        expect(pnlElement).toBeInTheDocument();
        expect(pnlElement).toHaveClass('pnl-value');
        expect(pnlElement.parentElement).toHaveClass('positive');
      });
    });

    it('should display negative P&L with correct styling', async () => {
      const portfolioWithNegativePnL = {
        ...mockPortfolio,
        pnl_24h: -1.5
      };
      mockAgentService.getPortfolio.mockResolvedValue({ ok: portfolioWithNegativePnL });

      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        const pnlElement = screen.getByText('-1.50%');
        expect(pnlElement).toBeInTheDocument();
        expect(pnlElement.parentElement).toHaveClass('negative');
      });
    });

    it('should display active strategy', async () => {
      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        expect(screen.getByText('balanced-strategy')).toBeInTheDocument();
      });
    });

    it('should display "None" when no active strategy', async () => {
      const portfolioWithoutStrategy = {
        ...mockPortfolio,
        active_strategy: undefined
      };
      mockAgentService.getPortfolio.mockResolvedValue({ ok: portfolioWithoutStrategy });

      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        expect(screen.getByText('None')).toBeInTheDocument();
      });
    });
  });

  describe('Positions Display', () => {
    it('should display all positions', async () => {
      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        expect(screen.getByText('lending-protocol-1')).toBeInTheDocument();
        expect(screen.getByText('liquidity-pool-1')).toBeInTheDocument();
      });
    });

    it('should display position amounts and values correctly', async () => {
      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        expect(screen.getByText('0.30000000 BTC')).toBeInTheDocument();
        expect(screen.getByText('0.20000000 BTC')).toBeInTheDocument();
        expect(screen.getByText('$15,000.00')).toBeInTheDocument();
        expect(screen.getByText('$10,000.00')).toBeInTheDocument();
      });
    });

    it('should display position P&L with correct styling', async () => {
      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        // Positive P&L: 1500/15000 * 100 = 10%
        const positivePnL = screen.getByText('+10.00%');
        expect(positivePnL).toBeInTheDocument();
        expect(positivePnL).toHaveClass('positive');

        // Negative P&L: -500/10000 * 100 = -5%
        const negativePnL = screen.getByText('-5.00%');
        expect(negativePnL).toBeInTheDocument();
        expect(negativePnL).toHaveClass('negative');
      });
    });

    it('should not display positions section when no positions', async () => {
      const portfolioWithoutPositions = {
        ...mockPortfolio,
        positions: []
      };
      mockAgentService.getPortfolio.mockResolvedValue({ ok: portfolioWithoutPositions });

      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        expect(screen.queryByText('Active Positions')).not.toBeInTheDocument();
      });
    });
  });

  describe('Transaction History', () => {
    it('should display transaction history table', async () => {
      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        expect(screen.getByText('Transaction History')).toBeInTheDocument();
        expect(screen.getByText('Date')).toBeInTheDocument();
        expect(screen.getByText('Type')).toBeInTheDocument();
        expect(screen.getByText('Amount')).toBeInTheDocument();
        expect(screen.getByText('Status')).toBeInTheDocument();
      });
    });

    it('should display transactions with correct formatting', async () => {
      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        expect(screen.getByText('Deposit')).toBeInTheDocument();
        expect(screen.getByText('Strategy Execute')).toBeInTheDocument();
        expect(screen.getByText('+0.50000000 BTC')).toBeInTheDocument();
        expect(screen.getByText('+0.30000000 BTC')).toBeInTheDocument();
      });
    });

    it('should display transaction status badges correctly', async () => {
      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        const confirmedStatus = screen.getByText('confirmed');
        expect(confirmedStatus).toBeInTheDocument();
        expect(confirmedStatus).toHaveClass('status-badge', 'confirmed');

        const pendingStatus = screen.getByText('pending');
        expect(pendingStatus).toBeInTheDocument();
        expect(pendingStatus).toHaveClass('status-badge', 'pending');
      });
    });

    it('should display block height for confirmed transactions', async () => {
      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        expect(screen.getByText('#800000')).toBeInTheDocument();
      });
    });

    it('should display transaction links correctly', async () => {
      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        const txLink = screen.getByText('tx123456...89abcdef');
        expect(txLink).toBeInTheDocument();
        expect(txLink.closest('a')).toHaveAttribute(
          'href',
          'https://blockstream.info/testnet/tx/tx123456789abcdef'
        );
      });
    });

    it('should show "No transactions yet" when transaction list is empty', async () => {
      mockAgentService.getTransactionHistory.mockResolvedValue({ ok: [] });

      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        expect(screen.getByText('No transactions yet')).toBeInTheDocument();
      });
    });
  });

  describe('Refresh Functionality', () => {
    beforeEach(() => {
      jest.useFakeTimers();
    });

    it('should have a refresh button', async () => {
      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        expect(screen.getByText('⟳ Refresh')).toBeInTheDocument();
      });
    });

    it('should refresh data when refresh button is clicked', async () => {
      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        expect(mockAgentService.getPortfolio).toHaveBeenCalledTimes(1);
        expect(mockAgentService.getTransactionHistory).toHaveBeenCalledTimes(1);
      });

      const refreshButton = screen.getByText('⟳ Refresh');
      fireEvent.click(refreshButton);

      await waitFor(() => {
        expect(mockAgentService.getPortfolio).toHaveBeenCalledTimes(2);
        expect(mockAgentService.getTransactionHistory).toHaveBeenCalledTimes(2);
      });
    });

    it('should show refreshing state when refreshing', async () => {
      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        expect(screen.getByText('⟳ Refresh')).toBeInTheDocument();
      });

      // Mock a slow response
      mockAgentService.getPortfolio.mockImplementation(() => new Promise(resolve => 
        setTimeout(() => resolve({ ok: mockPortfolio }), 1000)
      ));

      const refreshButton = screen.getByText('⟳ Refresh');
      fireEvent.click(refreshButton);

      expect(screen.getByText('↻ Refresh')).toBeInTheDocument();
      expect(refreshButton).toBeDisabled();
    });

    it('should auto-refresh every 30 seconds', async () => {
      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        expect(mockAgentService.getPortfolio).toHaveBeenCalledTimes(1);
      });

      // Fast-forward 30 seconds
      await act(async () => {
        jest.advanceTimersByTime(30000);
      });

      await waitFor(() => {
        expect(mockAgentService.getPortfolio).toHaveBeenCalledTimes(2);
        expect(mockAgentService.getTransactionHistory).toHaveBeenCalledTimes(2);
      });
    });
  });

  describe('Error Handling', () => {
    it('should call onError when portfolio loading fails', async () => {
      mockAgentService.getPortfolio.mockResolvedValue({
        err: { type: ApiErrorType.InternalError, message: 'Portfolio load failed' }
      });

      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        expect(mockOnError).toHaveBeenCalledWith('Failed to load portfolio: Portfolio load failed');
      });
    });

    it('should call onError when transaction history loading fails', async () => {
      mockAgentService.getTransactionHistory.mockResolvedValue({
        err: { type: ApiErrorType.InternalError, message: 'Transaction load failed' }
      });

      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        expect(mockOnError).toHaveBeenCalledWith('Failed to load transactions: Transaction load failed');
      });
    });

    it('should show error state when portfolio is null', async () => {
      mockAgentService.getPortfolio.mockResolvedValue({
        err: { type: ApiErrorType.NotFound, message: 'Portfolio not found' }
      });

      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        expect(screen.getByText('Unable to load portfolio data')).toBeInTheDocument();
        expect(screen.getByText('Retry')).toBeInTheDocument();
      });
    });

    it('should retry loading when retry button is clicked', async () => {
      mockAgentService.getPortfolio.mockResolvedValueOnce({
        err: { type: ApiErrorType.NotFound, message: 'Portfolio not found' }
      });

      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        expect(screen.getByText('Retry')).toBeInTheDocument();
      });

      // Mock successful retry
      mockAgentService.getPortfolio.mockResolvedValue({ ok: mockPortfolio });

      const retryButton = screen.getByText('Retry');
      fireEvent.click(retryButton);

      await waitFor(() => {
        expect(screen.getByText('Portfolio Overview')).toBeInTheDocument();
      });
    });
  });

  describe('Data Accuracy', () => {
    it('should format BTC amounts correctly', async () => {
      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        // 50000000 satoshis = 0.5 BTC
        expect(screen.getByText('0.50000000 BTC')).toBeInTheDocument();
        // 30000000 satoshis = 0.3 BTC
        expect(screen.getByText('0.30000000 BTC')).toBeInTheDocument();
        // 20000000 satoshis = 0.2 BTC
        expect(screen.getByText('0.20000000 BTC')).toBeInTheDocument();
      });
    });

    it('should format USD amounts correctly', async () => {
      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        expect(screen.getByText('$25,000.00')).toBeInTheDocument();
        expect(screen.getByText('$15,000.00')).toBeInTheDocument();
        expect(screen.getByText('$10,000.00')).toBeInTheDocument();
      });
    });

    it('should format timestamps correctly', async () => {
      render(<PortfolioDashboard userId={mockUserId} onError={mockOnError} />);

      await waitFor(() => {
        // Check that timestamps are formatted as locale strings
        const dateElements = screen.getAllByText(/1\/1\/2022|1\/2\/2022/);
        expect(dateElements.length).toBeGreaterThan(0);
      });
    });
  });
});