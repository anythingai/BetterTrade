import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import { NotificationToast, NotificationContainer } from '../NotificationToast';
import { NotificationProvider, useNotifications } from '../../contexts/NotificationContext';
import { NotificationType } from '../../types/notifications';

// Mock notification data
const mockNotification = {
  id: 'test-notification-1',
  type: NotificationType.Success,
  title: 'Test Notification',
  message: 'This is a test notification message',
  timestamp: Date.now(),
  duration: 5000
};

const mockNotificationWithAction = {
  ...mockNotification,
  id: 'test-notification-2',
  actionLabel: 'View Details',
  onAction: jest.fn()
};

describe('NotificationToast', () => {
  // Mock function for removing notifications

  beforeEach(() => {
    jest.clearAllMocks();
  });

  const renderWithContext = (notification: typeof mockNotification) => {
    return render(
      <NotificationProvider>
        <NotificationToast notification={notification} />
      </NotificationProvider>
    );
  };

  it('renders notification with correct content', () => {
    renderWithContext(mockNotification);

    expect(screen.getByText('Test Notification')).toBeInTheDocument();
    expect(screen.getByText('This is a test notification message')).toBeInTheDocument();
    expect(screen.getByText('✅')).toBeInTheDocument(); // Success icon
  });

  it('displays correct icon for different notification types', () => {
    const warningNotification = { ...mockNotification, type: NotificationType.Warning };
    renderWithContext(warningNotification);
    expect(screen.getByText('⚠️')).toBeInTheDocument();

    const errorNotification = { ...mockNotification, type: NotificationType.Error };
    renderWithContext(errorNotification);
    expect(screen.getByText('❌')).toBeInTheDocument();

    const infoNotification = { ...mockNotification, type: NotificationType.Info };
    renderWithContext(infoNotification);
    expect(screen.getByText('ℹ️')).toBeInTheDocument();
  });

  it('calls removeNotification when close button is clicked', () => {
    const TestComponent = () => {
      const { addNotification, notifications } = useNotifications();
      
      React.useEffect(() => {
        addNotification(mockNotification);
      }, [addNotification]);

      return (
        <div>
          {notifications.map(notification => (
            <NotificationToast key={notification.id} notification={notification} />
          ))}
        </div>
      );
    };

    render(
      <NotificationProvider>
        <TestComponent />
      </NotificationProvider>
    );

    const closeButton = screen.getByRole('button', { name: /close notification/i });
    fireEvent.click(closeButton);

    // After clicking close, the notification should be removed
    expect(screen.queryByText('Test Notification')).not.toBeInTheDocument();
  });

  it('renders action button when provided', () => {
    renderWithContext(mockNotificationWithAction);

    const actionButton = screen.getByRole('button', { name: 'View Details' });
    expect(actionButton).toBeInTheDocument();

    fireEvent.click(actionButton);
    expect(mockNotificationWithAction.onAction).toHaveBeenCalled();
  });

  it('formats timestamp correctly', () => {
    const testTime = new Date('2023-01-01T12:00:00Z').getTime();
    const notificationWithTime = { ...mockNotification, timestamp: testTime };
    
    renderWithContext(notificationWithTime);
    
    // Check that time is displayed (format may vary by locale)
    expect(screen.getByText(/\d{1,2}:\d{2}/)).toBeInTheDocument();
  });

  it('applies correct CSS class for notification type', () => {
    const { container } = renderWithContext(mockNotification);
    
    const toastElement = container.querySelector('.notification-toast');
    expect(toastElement).toHaveClass('notification-success');
  });
});

describe('NotificationContainer', () => {
  const renderWithNotifications = (notifications: typeof mockNotification[]) => {
    // Create a test component that adds notifications to the context
    const TestComponent = () => {
      const { addNotification } = useNotifications();
      
      React.useEffect(() => {
        notifications.forEach(notification => {
          addNotification(notification);
        });
      }, [addNotification]);

      return <NotificationContainer />;
    };

    return render(
      <NotificationProvider>
        <TestComponent />
      </NotificationProvider>
    );
  };

  it('renders nothing when no notifications', () => {
    const { container } = renderWithNotifications([]);
    expect(container.firstChild).toBeNull();
  });

  it('renders multiple notifications', () => {
    const notifications = [
      { ...mockNotification, id: 'notification-1', title: 'First Notification' },
      { ...mockNotification, id: 'notification-2', title: 'Second Notification' }
    ];

    renderWithNotifications(notifications);

    expect(screen.getByText('First Notification')).toBeInTheDocument();
    expect(screen.getByText('Second Notification')).toBeInTheDocument();
  });

  it('has correct container structure', () => {
    const { container } = renderWithNotifications([mockNotification]);
    
    const containerElement = container.querySelector('.notification-container');
    expect(containerElement).toBeInTheDocument();
  });
});

describe('NotificationContainer Integration', () => {
  it('integrates properly with NotificationProvider', async () => {
    const TestComponent = () => {
      const { addNotification } = require('../../contexts/NotificationContext').useNotifications();
      
      const handleAddNotification = () => {
        addNotification({
          type: NotificationType.Info,
          title: 'Integration Test',
          message: 'This is an integration test',
          duration: 1000
        });
      };

      return (
        <div>
          <button onClick={handleAddNotification}>Add Notification</button>
          <NotificationContainer />
        </div>
      );
    };

    render(
      <NotificationProvider>
        <TestComponent />
      </NotificationProvider>
    );

    const addButton = screen.getByRole('button', { name: 'Add Notification' });
    fireEvent.click(addButton);

    expect(screen.getByText('Integration Test')).toBeInTheDocument();
    expect(screen.getByText('This is an integration test')).toBeInTheDocument();

    // Wait for auto-dismiss
    await waitFor(() => {
      expect(screen.queryByText('Integration Test')).not.toBeInTheDocument();
    }, { timeout: 2000 });
  });
});