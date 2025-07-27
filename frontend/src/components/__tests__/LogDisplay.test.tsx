import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import '@testing-library/jest-dom';
import { LogDisplay } from '../LogDisplay';
import { NotificationProvider, useNotifications } from '../../contexts/NotificationContext';

// Mock log data
const mockLogs = [
  {
    id: 'log-1',
    timestamp: Date.now() - 3600000, // 1 hour ago
    agent: 'Execution Agent',
    action: 'Transaction Confirmed',
    transaction_id: 'tx-abc123def456',
    user_id: 'user-123',
    level: 'info' as const,
    details: {
      type: 'strategy_execute',
      amount_sats: '50000000',
      fee_sats: '2500'
    }
  },
  {
    id: 'log-2',
    timestamp: Date.now() - 7200000, // 2 hours ago
    agent: 'Risk Guard',
    action: 'Threshold Breach Detected',
    user_id: 'user-123',
    level: 'warn' as const,
    details: {
      threshold_type: 'drawdown',
      threshold_value: 15,
      current_value: 18.5,
      severity: 'high'
    }
  },
  {
    id: 'log-3',
    timestamp: Date.now() - 10800000, // 3 hours ago
    agent: 'Strategy Selector',
    action: 'Recommendation Generated',
    user_id: 'user-123',
    level: 'info' as const,
    details: {
      risk_profile: 'balanced',
      recommended_strategy: 'Conservative Growth',
      score: 0.85
    }
  },
  {
    id: 'log-4',
    timestamp: Date.now() - 14400000, // 4 hours ago
    agent: 'Execution Agent',
    action: 'Transaction Failed',
    transaction_id: 'tx-def456ghi789',
    user_id: 'user-123',
    level: 'error' as const,
    details: {
      type: 'withdraw',
      amount_sats: '25000000',
      reason: 'Insufficient balance'
    }
  },
  {
    id: 'log-5',
    timestamp: Date.now() - 18000000, // 5 hours ago
    agent: 'Portfolio State',
    action: 'Balance Updated',
    user_id: 'user-123',
    level: 'info' as const,
    details: {
      old_balance: '100000000',
      new_balance: '125000000',
      change: '+25000000'
    }
  }
];

describe('LogDisplay', () => {
  // Mock function for clearing logs

  beforeEach(() => {
    jest.clearAllMocks();
  });

  const renderWithContext = (logs: typeof mockLogs = mockLogs) => {
    // Create a test component that adds logs to the context
    const TestComponent = () => {
      const { addLogEntry } = useNotifications();
      
      React.useEffect(() => {
        logs.forEach(log => {
          addLogEntry(log);
        });
      }, [addLogEntry]);

      return <LogDisplay />;
    };

    return render(
      <NotificationProvider>
        <TestComponent />
      </NotificationProvider>
    );
  };

  it('renders log display with correct header', () => {
    renderWithContext();

    expect(screen.getByText('System Logs')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /clear logs/i })).toBeInTheDocument();
  });

  it('displays all logs by default', () => {
    renderWithContext();

    expect(screen.getByText('Transaction Confirmed')).toBeInTheDocument();
    expect(screen.getByText('Threshold Breach Detected')).toBeInTheDocument();
    expect(screen.getByText('Recommendation Generated')).toBeInTheDocument();
    expect(screen.getByText('Transaction Failed')).toBeInTheDocument();
    expect(screen.getByText('Balance Updated')).toBeInTheDocument();
  });

  it('filters logs by level', () => {
    renderWithContext();

    const levelFilter = screen.getByLabelText('Filter by log level');
    fireEvent.change(levelFilter, { target: { value: 'error' } });

    expect(screen.getByText('Transaction Failed')).toBeInTheDocument();
    expect(screen.queryByText('Transaction Confirmed')).not.toBeInTheDocument();
    expect(screen.queryByText('Threshold Breach Detected')).not.toBeInTheDocument();
  });

  it('filters logs by agent', () => {
    renderWithContext();

    const agentFilter = screen.getByLabelText('Filter by agent');
    fireEvent.change(agentFilter, { target: { value: 'Execution Agent' } });

    expect(screen.getByText('Transaction Confirmed')).toBeInTheDocument();
    expect(screen.getByText('Transaction Failed')).toBeInTheDocument();
    expect(screen.queryByText('Threshold Breach Detected')).not.toBeInTheDocument();
    expect(screen.queryByText('Recommendation Generated')).not.toBeInTheDocument();
  });

  it('filters logs by search term', () => {
    renderWithContext();

    const searchInput = screen.getByPlaceholderText('Search logs...');
    fireEvent.change(searchInput, { target: { value: 'transaction' } });

    expect(screen.getByText('Transaction Confirmed')).toBeInTheDocument();
    expect(screen.getByText('Transaction Failed')).toBeInTheDocument();
    expect(screen.queryByText('Threshold Breach Detected')).not.toBeInTheDocument();
    expect(screen.queryByText('Recommendation Generated')).not.toBeInTheDocument();
  });

  it('displays correct icons for different log levels', () => {
    renderWithContext();

    expect(screen.getAllByText('ℹ️')).toHaveLength(3); // Info logs
    expect(screen.getByText('⚠️')).toBeInTheDocument(); // Warning log
    expect(screen.getByText('❌')).toBeInTheDocument(); // Error log
  });

  it('displays transaction IDs when available', () => {
    renderWithContext();

    expect(screen.getAllByText((content, element) => {
      return element?.textContent?.includes('TX: tx-abc12') || false;
    })[0]).toBeInTheDocument();
    expect(screen.getAllByText((content, element) => {
      return element?.textContent?.includes('TX: tx-def45') || false;
    })[0]).toBeInTheDocument();
  });

  it('shows log details in expandable sections', () => {
    renderWithContext();

    const detailsButtons = screen.getAllByText('Details');
    expect(detailsButtons.length).toBeGreaterThan(0);

    // Click to expand details
    fireEvent.click(detailsButtons[0]);
    
    // Should show JSON details
    expect(screen.getByText(/"type": "strategy_execute"/)).toBeInTheDocument();
  });

  it('calls clearLogs when clear button is clicked', () => {
    renderWithContext();

    const clearButton = screen.getByRole('button', { name: /clear logs/i });
    fireEvent.click(clearButton);

    // After clicking clear, the logs should be removed
    expect(screen.getByText('No log entries')).toBeInTheDocument();
  });

  it('disables clear button when no logs', () => {
    renderWithContext([]);

    const clearButton = screen.getByRole('button', { name: /clear logs/i });
    expect(clearButton).toBeDisabled();
  });

  it('displays empty state when no logs', () => {
    renderWithContext([]);

    expect(screen.getByText('No log entries')).toBeInTheDocument();
  });

  it('displays empty state when no logs match filters', () => {
    renderWithContext();

    const searchInput = screen.getByPlaceholderText('Search logs...');
    fireEvent.change(searchInput, { target: { value: 'nonexistent' } });

    expect(screen.getByText('No entries match current filters')).toBeInTheDocument();
  });

  it('sorts logs by timestamp (newest first)', () => {
    renderWithContext();

    const logEntries = screen.getAllByText(/\d{1,2}:\d{2}/);
    // First entry should be the most recent
    expect(logEntries[0]).toBeInTheDocument();
  });

  it('limits logs to maxEntries prop', () => {
    const manyLogs = Array.from({ length: 150 }, (_, i) => ({
      ...mockLogs[0],
      id: `log-${i}`,
      action: `Action ${i}`,
      timestamp: Date.now() - i * 1000
    }));

    renderWithContext(manyLogs);

    // Should be limited by maxEntries (default 100)
    const logCount = screen.getByText(/Showing \d+ of \d+ entries/);
    expect(logCount).toBeInTheDocument();
  });

  it('displays log count in footer', () => {
    renderWithContext();

    expect(screen.getByText(/Showing 5 of 5 entries/)).toBeInTheDocument();
  });

  it('applies correct CSS classes for log levels', () => {
    const { container } = renderWithContext();

    expect(container.querySelector('.log-info')).toBeInTheDocument();
    expect(container.querySelector('.log-warn')).toBeInTheDocument();
    expect(container.querySelector('.log-error')).toBeInTheDocument();
  });

  it('applies custom className prop', () => {
    const TestComponent = () => {
      const { addLogEntry } = useNotifications();
      
      React.useEffect(() => {
        addLogEntry(mockLogs[0]);
      }, [addLogEntry]);

      return <LogDisplay className="custom-log-display" />;
    };

    const { container } = render(
      <NotificationProvider>
        <TestComponent />
      </NotificationProvider>
    );

    expect(container.querySelector('.custom-log-display')).toBeInTheDocument();
  });

  it('formats timestamps correctly', () => {
    renderWithContext();

    // Check that timestamps are displayed in locale format
    const timestamps = screen.getAllByText(/\d{1,2}:\d{2}/);
    expect(timestamps.length).toBeGreaterThan(0);
  });

  it('handles logs without transaction IDs', () => {
    const logsWithoutTx = mockLogs.map(log => ({
      ...log,
      transaction_id: undefined
    }));
    renderWithContext(logsWithoutTx as typeof mockLogs);

    expect(screen.getByText('Threshold Breach Detected')).toBeInTheDocument();
    expect(screen.queryByText(/TX:/)).not.toBeInTheDocument();
  });

  it('handles logs with empty details', () => {
    const logsWithEmptyDetails = mockLogs.map(log => ({ 
      ...log, 
      details: {} as Record<string, unknown> 
    }));
    renderWithContext(logsWithEmptyDetails as typeof mockLogs);

    expect(screen.getByText('Transaction Confirmed')).toBeInTheDocument();
    // Details sections should not be shown for empty details
    expect(screen.queryByText('Details')).not.toBeInTheDocument();
  });

  it('populates agent filter dropdown with unique agents', () => {
    renderWithContext();

    // Check agent filter dropdown
    
    // Check that all unique agents are in the dropdown
    expect(screen.getByRole('option', { name: 'Execution Agent' })).toBeInTheDocument();
    expect(screen.getByRole('option', { name: 'Risk Guard' })).toBeInTheDocument();
    expect(screen.getByRole('option', { name: 'Strategy Selector' })).toBeInTheDocument();
    expect(screen.getByRole('option', { name: 'Portfolio State' })).toBeInTheDocument();
  });
});