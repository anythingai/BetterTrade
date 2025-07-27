import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import { AlertPanel } from '../AlertPanel';
import { AlertSeverity } from '../../types/notifications';
import { NotificationProvider, useNotifications } from '../../contexts/NotificationContext';

// Mock alerts data
const mockAlerts = [
  {
    id: 'alert-1',
    severity: AlertSeverity.Critical,
    title: 'Critical Risk Threshold Breached',
    message: 'Your portfolio has exceeded the maximum drawdown limit of 15%. Current drawdown: 18.5%.',
    timestamp: Date.now() - 3600000, // 1 hour ago
    acknowledged: false,
    user_id: 'user-123',
    threshold_value: 15,
    current_value: 18.5,
    related_tx_id: 'tx-abc123'
  },
  {
    id: 'alert-2',
    severity: AlertSeverity.High,
    title: 'High Volatility Detected',
    message: 'Market volatility has increased significantly. Consider reviewing your strategy.',
    timestamp: Date.now() - 7200000, // 2 hours ago
    acknowledged: false,
    user_id: 'user-123',
    threshold_value: 25,
    current_value: 28.2
  },
  {
    id: 'alert-3',
    severity: AlertSeverity.Medium,
    title: 'Strategy Recommendation Updated',
    message: 'Based on current market conditions, we recommend switching to a more conservative strategy.',
    timestamp: Date.now() - 10800000, // 3 hours ago
    acknowledged: true,
    user_id: 'user-123'
  },
  {
    id: 'alert-4',
    severity: AlertSeverity.Low,
    title: 'Portfolio Milestone Reached',
    message: 'Congratulations! Your portfolio has reached 10% profit.',
    timestamp: Date.now() - 14400000, // 4 hours ago
    acknowledged: false,
    user_id: 'user-123'
  }
];

describe('AlertPanel', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  const renderWithContext = (alerts: typeof mockAlerts = mockAlerts) => {
    // Create a test component that adds alerts to the context
    const TestComponent = () => {
      const { addAlert, acknowledgeAlert, alerts: contextAlerts } = useNotifications();
      
      React.useEffect(() => {
        alerts.forEach(alert => {
          addAlert({
            severity: alert.severity,
            title: alert.title,
            message: alert.message,
            user_id: alert.user_id,
            threshold_value: alert.threshold_value,
            current_value: alert.current_value,
            related_tx_id: alert.related_tx_id
          });
        });
      }, [addAlert]);

      // Acknowledge alerts that should be acknowledged
      React.useEffect(() => {
        const acknowledgedAlerts = alerts.filter(alert => alert.acknowledged);
        acknowledgedAlerts.forEach(acknowledgedAlert => {
          const contextAlert = contextAlerts.find(ca => ca.title === acknowledgedAlert.title);
          if (contextAlert && !contextAlert.acknowledged) {
            acknowledgeAlert(contextAlert.id);
          }
        });
      }, [contextAlerts, acknowledgeAlert]);

      return <AlertPanel />;
    };

    return render(
      <NotificationProvider>
        <TestComponent />
      </NotificationProvider>
    );
  };

  it('renders alert panel with correct header', () => {
    renderWithContext();

    expect(screen.getByText('Risk Alerts')).toBeInTheDocument();
    expect(screen.getByText('3')).toBeInTheDocument(); // Unacknowledged count badge
  });

  it('displays unacknowledged alerts by default', () => {
    renderWithContext();

    expect(screen.getByText('Critical Risk Threshold Breached')).toBeInTheDocument();
    expect(screen.getByText('High Volatility Detected')).toBeInTheDocument();
    expect(screen.getByText('Portfolio Milestone Reached')).toBeInTheDocument();
    // The acknowledged alert should not be shown by default (it's filtered out)
    expect(screen.queryByText('Strategy Recommendation Updated')).not.toBeInTheDocument();
  });

  it('shows acknowledged alerts when toggle is checked', () => {
    renderWithContext();

    const toggle = screen.getByRole('checkbox', { name: /show acknowledged/i });
    fireEvent.click(toggle);

    expect(screen.getByText('Strategy Recommendation Updated')).toBeInTheDocument();
  });

  it('displays correct severity icons and colors', () => {
    renderWithContext();

    // Check for severity icons
    expect(screen.getByText('🚨')).toBeInTheDocument(); // Critical
    expect(screen.getByText('⚠️')).toBeInTheDocument(); // High
    expect(screen.getByText('ℹ️')).toBeInTheDocument(); // Low
  });

  it('sorts alerts by severity and timestamp', () => {
    renderWithContext();

    const alertItems = screen.getAllByText(/CRITICAL|HIGH|MEDIUM|LOW/);
    
    // Critical should come first
    expect(alertItems[0]).toHaveTextContent('CRITICAL');
    // High should come second
    expect(alertItems[1]).toHaveTextContent('HIGH');
    // Low should come third (Medium is acknowledged and filtered out by default)
    expect(alertItems[2]).toHaveTextContent('LOW');
  });

  it('displays threshold values when available', () => {
    renderWithContext();

    expect(screen.getByText('Threshold: 15.00%')).toBeInTheDocument();
    expect(screen.getByText('Current: 18.50%')).toBeInTheDocument();
  });

  it('displays related transaction ID when available', () => {
    renderWithContext();

    expect(screen.getByText(/Related TX:/)).toBeInTheDocument();
    expect(screen.getByText('tx-abc123...')).toBeInTheDocument();
  });

  it('calls acknowledgeAlert when acknowledge button is clicked', () => {
    renderWithContext();

    const acknowledgeButtons = screen.getAllByRole('button', { name: /acknowledge/i });
    fireEvent.click(acknowledgeButtons[0]);

    // After clicking acknowledge, the alert should be marked as acknowledged
    // We can check this by looking for the acknowledged class or checking if the button disappears
    expect(acknowledgeButtons[0]).not.toBeInTheDocument();
  });

  it('does not show acknowledge button for already acknowledged alerts', async () => {
    renderWithContext();

    const toggle = screen.getByRole('checkbox', { name: /show acknowledged/i });
    fireEvent.click(toggle);

    // Wait for the acknowledged alert to appear
    await waitFor(() => {
      expect(screen.getByText('Strategy Recommendation Updated')).toBeInTheDocument();
    });

    // Find the acknowledged alert (now visible after toggling)
    const acknowledgedAlert = screen.getByText('Strategy Recommendation Updated').closest('.alert-item');
    expect(acknowledgedAlert).toHaveClass('acknowledged');
    
    // Should not have acknowledge button for acknowledged alert
    const acknowledgeButtons = screen.getAllByRole('button', { name: /acknowledge/i });
    expect(acknowledgeButtons).toHaveLength(3); // Only for unacknowledged alerts
  });

  it('displays empty state when no alerts', () => {
    renderWithContext([]);

    expect(screen.getByText('No active alerts')).toBeInTheDocument();
  });

  it('displays empty state when no unacknowledged alerts', async () => {
    const acknowledgedAlerts = mockAlerts.map(alert => ({ ...alert, acknowledged: true }));
    renderWithContext(acknowledgedAlerts);

    // Wait for the acknowledgment to take effect
    await waitFor(() => {
      expect(screen.getByText('No active alerts')).toBeInTheDocument();
    });
  });

  it('formats timestamps correctly', () => {
    renderWithContext();

    // Check that timestamps are displayed (format may vary by locale)
    const timeElements = screen.getAllByText(/\d{1,2}:\d{2}/);
    expect(timeElements.length).toBeGreaterThan(0);
  });

  it('applies correct CSS classes for severity levels', () => {
    const { container } = renderWithContext();

    expect(container.querySelector('.alert-critical')).toBeInTheDocument();
    expect(container.querySelector('.alert-high')).toBeInTheDocument();
    expect(container.querySelector('.alert-low')).toBeInTheDocument();
  });

  it('applies custom className prop', () => {
    const TestComponent = () => {
      const { addAlert } = useNotifications();
      
      React.useEffect(() => {
        addAlert(mockAlerts[0]);
      }, [addAlert]);

      return <AlertPanel className="custom-alert-panel" />;
    };

    const { container } = render(
      <NotificationProvider>
        <TestComponent />
      </NotificationProvider>
    );

    expect(container.querySelector('.custom-alert-panel')).toBeInTheDocument();
  });

  it('handles missing optional fields gracefully', () => {
    const minimalAlert = {
      id: 'minimal-alert',
      severity: AlertSeverity.Medium,
      title: 'Minimal Alert',
      message: 'This alert has minimal fields',
      timestamp: Date.now(),
      acknowledged: false,
      user_id: 'user-123'
    };

    renderWithContext([minimalAlert]);

    expect(screen.getByText('Minimal Alert')).toBeInTheDocument();
    expect(screen.getByText('This alert has minimal fields')).toBeInTheDocument();
    expect(screen.queryByText(/Threshold:/)).not.toBeInTheDocument();
    expect(screen.queryByText(/Related TX:/)).not.toBeInTheDocument();
  });
});