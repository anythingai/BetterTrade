import React, { act } from "react";
import {
  render,
  screen,
  fireEvent,
  waitFor,
} from "@testing-library/react";
import "@testing-library/jest-dom";
import { NotificationProvider, useNotifications } from "../NotificationContext";
import { NotificationType, AlertSeverity } from "../../types/notifications";

// Mock the notification service
jest.mock("../../services/notificationService", () => ({
  notificationService: {
    registerNotificationCallback: jest.fn(),
    registerAlertCallback: jest.fn(),
    registerLogCallback: jest.fn(),
  },
}));

// Test component that uses the notification context
const TestComponent: React.FC = () => {
  const {
    notifications,
    alerts,
    logs,
    addNotification,
    removeNotification,
    addAlert,
    acknowledgeAlert,
    addLogEntry,
    clearLogs,
  } = useNotifications();

  return (
    <div>
      <div data-testid="notification-count">{notifications.length}</div>
      <div data-testid="alert-count">{alerts.length}</div>
      <div data-testid="log-count">{logs.length}</div>

      <button
        type="button"
        onClick={() =>
          addNotification({
            type: NotificationType.Success,
            title: "Test Notification",
            message: "This is a test",
            duration: 5000,
          })
        }
      >
        Add Notification
      </button>

      <button
        type="button"
        onClick={() =>
          addAlert({
            severity: AlertSeverity.High,
            title: "Test Alert",
            message: "This is a test alert",
            user_id: "user-123",
          })
        }
      >
        Add Alert
      </button>

      <button
        type="button"
        onClick={() =>
          addLogEntry({
            agent: "Test Agent",
            action: "Test Action",
            user_id: "user-123",
            level: "info",
            details: { test: "data" },
          })
        }
      >
        Add Log
      </button>

      <button
        type="button"
        onClick={() => removeNotification(notifications[0]?.id)}
        disabled={notifications.length === 0}
      >
        Remove First Notification
      </button>

      <button
        type="button"
        onClick={() => acknowledgeAlert(alerts[0]?.id)}
        disabled={alerts.length === 0}
      >
        Acknowledge First Alert
      </button>

      <button type="button" onClick={clearLogs}>
        Clear Logs
      </button>

      {/* Display items for testing */}
      {notifications.map((notification) => (
        <div
          key={notification.id}
          data-testid={`notification-${notification.id}`}
        >
          {notification.title}: {notification.message}
        </div>
      ))}

      {alerts.map((alert) => (
        <div key={alert.id} data-testid={`alert-${alert.id}`}>
          {alert.title}: {alert.message} (Acknowledged:{" "}
          {alert.acknowledged.toString()})
        </div>
      ))}

      {logs.map((log) => (
        <div key={log.id} data-testid={`log-${log.id}`}>
          {log.agent}: {log.action}
        </div>
      ))}
    </div>
  );
};

describe("NotificationContext", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.runOnlyPendingTimers();
    jest.useRealTimers();
  });

  const renderWithProvider = () => {
    return render(
      <NotificationProvider>
        <TestComponent />
      </NotificationProvider>
    );
  };

  it("provides initial empty state", () => {
    renderWithProvider();

    expect(screen.getByTestId("notification-count")).toHaveTextContent("0");
    expect(screen.getByTestId("alert-count")).toHaveTextContent("0");
    expect(screen.getByTestId("log-count")).toHaveTextContent("0");
  });

  it("throws error when used outside provider", () => {
    // Suppress console.error for this test
    const consoleSpy = jest
      .spyOn(console, "error")
      .mockImplementation(() => {});

    expect(() => {
      render(<TestComponent />);
    }).toThrow("useNotifications must be used within a NotificationProvider");

    consoleSpy.mockRestore();
  });

  describe("Notifications", () => {
    it("adds notifications correctly", () => {
      renderWithProvider();

      const addButton = screen.getByText("Add Notification");
      fireEvent.click(addButton);

      expect(screen.getByTestId("notification-count")).toHaveTextContent("1");
      expect(
        screen.getByText("Test Notification: This is a test")
      ).toBeInTheDocument();
    });

    it("generates unique IDs for notifications", () => {
      renderWithProvider();

      const addButton = screen.getByText("Add Notification");
      fireEvent.click(addButton);
      fireEvent.click(addButton);

      expect(screen.getByTestId("notification-count")).toHaveTextContent("2");

      const notifications = screen.getAllByText(
        /Test Notification: This is a test/
      );
      expect(notifications).toHaveLength(2);
    });

    it("removes notifications correctly", () => {
      renderWithProvider();

      const addButton = screen.getByText("Add Notification");
      const removeButton = screen.getByText("Remove First Notification");

      fireEvent.click(addButton);
      expect(screen.getByTestId("notification-count")).toHaveTextContent("1");

      fireEvent.click(removeButton);
      expect(screen.getByTestId("notification-count")).toHaveTextContent("0");
    });

    it("auto-removes notifications after duration", async () => {
      renderWithProvider();

      const addButton = screen.getByText("Add Notification");
      fireEvent.click(addButton);

      expect(screen.getByTestId("notification-count")).toHaveTextContent("1");

      // Fast-forward time by 5 seconds (duration)
      await act(async () => {
        jest.advanceTimersByTime(5000);
        jest.runOnlyPendingTimers();
      });

      await waitFor(() => {
        expect(screen.getByTestId("notification-count")).toHaveTextContent("0");
      });
    });

    it("does not auto-remove notifications with duration 0", async () => {
      const TestComponentPersistent: React.FC = () => {
        const { addNotification, notifications } = useNotifications();

        return (
          <div>
            <div data-testid="notification-count">{notifications.length}</div>
            <button
              type="button"
              onClick={() =>
                addNotification({
                  type: NotificationType.Error,
                  title: "Persistent Notification",
                  message: "This should persist",
                  duration: 0,
                })
              }
            >
              Add Persistent Notification
            </button>
          </div>
        );
      };

      render(
        <NotificationProvider>
          <TestComponentPersistent />
        </NotificationProvider>
      );

      const addButton = screen.getByText("Add Persistent Notification");
      fireEvent.click(addButton);

      expect(screen.getByTestId("notification-count")).toHaveTextContent("1");

      // Fast-forward time
      await act(async () => {
        jest.advanceTimersByTime(10000);
        jest.runOnlyPendingTimers();
      });

      // Should still be there
      expect(screen.getByTestId("notification-count")).toHaveTextContent("1");
    });

    it("does not auto-remove notifications with undefined duration", async () => {
      const TestComponentUndefined: React.FC = () => {
        const { addNotification, notifications } = useNotifications();

        return (
          <div>
            <div data-testid="notification-count">{notifications.length}</div>
            <button
              type="button"
              onClick={() =>
                addNotification({
                  type: NotificationType.Info,
                  title: "Undefined Duration",
                  message: "This should persist",
                  duration: undefined,
                })
              }
            >
              Add Undefined Duration Notification
            </button>
          </div>
        );
      };

      render(
        <NotificationProvider>
          <TestComponentUndefined />
        </NotificationProvider>
      );

      const addButton = screen.getByText("Add Undefined Duration Notification");
      fireEvent.click(addButton);

      expect(screen.getByTestId("notification-count")).toHaveTextContent("1");

      // Fast-forward time
      await act(async () => {
        jest.advanceTimersByTime(10000);
        jest.runOnlyPendingTimers();
      });

      // Should still be there
      expect(screen.getByTestId("notification-count")).toHaveTextContent("1");
    });
  });

  describe("Alerts", () => {
    it("adds alerts correctly", () => {
      renderWithProvider();

      const addButton = screen.getByText("Add Alert");
      fireEvent.click(addButton);

      expect(screen.getByTestId("alert-count")).toHaveTextContent("1");
      expect(
        screen.getByText(
          "Test Alert: This is a test alert (Acknowledged: false)"
        )
      ).toBeInTheDocument();
    });

    it("generates unique IDs for alerts", () => {
      renderWithProvider();

      const addButton = screen.getByText("Add Alert");
      fireEvent.click(addButton);
      fireEvent.click(addButton);

      expect(screen.getByTestId("alert-count")).toHaveTextContent("2");

      // Only check for alert elements, not notifications or counts
      const alerts = screen.getAllByTestId(/^alert-alert-/);
      expect(alerts).toHaveLength(2);
    });

    it("acknowledges alerts correctly", () => {
      renderWithProvider();

      const addButton = screen.getByText("Add Alert");
      const acknowledgeButton = screen.getByText("Acknowledge First Alert");

      fireEvent.click(addButton);
      expect(screen.getByText(/Acknowledged: false/)).toBeInTheDocument();

      fireEvent.click(acknowledgeButton);
      expect(screen.getByText(/Acknowledged: true/)).toBeInTheDocument();
    });

    it("creates notification when alert is added", () => {
      renderWithProvider();

      const addButton = screen.getByText("Add Alert");
      fireEvent.click(addButton);

      // Should have both alert and notification
      expect(screen.getByTestId("alert-count")).toHaveTextContent("1");
      expect(screen.getByTestId("notification-count")).toHaveTextContent("1");
    });

    it("creates error notification for critical alerts", () => {
      const TestComponentCritical: React.FC = () => {
        const { addAlert, notifications } = useNotifications();

        return (
          <div>
            <div data-testid="notification-count">{notifications.length}</div>
            <button
              type="button"
              onClick={() =>
                addAlert({
                  severity: AlertSeverity.Critical,
                  title: "Critical Alert",
                  message: "This is critical",
                  user_id: "user-123",
                })
              }
            >
              Add Critical Alert
            </button>
            {notifications.map((notification) => (
              <div
                key={notification.id}
                data-testid={`notification-type-${notification.type}`}
              >
                {notification.title}
              </div>
            ))}
          </div>
        );
      };

      render(
        <NotificationProvider>
          <TestComponentCritical />
        </NotificationProvider>
      );

      const addButton = screen.getByText("Add Critical Alert");
      fireEvent.click(addButton);

      expect(screen.getByTestId("notification-type-error")).toBeInTheDocument();
    });

    it("creates persistent notification for critical alerts", async () => {
      const TestComponentCritical: React.FC = () => {
        const { addAlert, notifications } = useNotifications();

        return (
          <div>
            <div data-testid="notification-count">{notifications.length}</div>
            <button
              type="button"
              onClick={() =>
                addAlert({
                  severity: AlertSeverity.Critical,
                  title: "Critical Alert",
                  message: "This is critical",
                  user_id: "user-123",
                })
              }
            >
              Add Critical Alert
            </button>
          </div>
        );
      };

      render(
        <NotificationProvider>
          <TestComponentCritical />
        </NotificationProvider>
      );

      const addButton = screen.getByText("Add Critical Alert");
      fireEvent.click(addButton);

      expect(screen.getByTestId("notification-count")).toHaveTextContent("1");

      // Fast-forward time - critical alerts should persist
      await act(async () => {
        jest.advanceTimersByTime(10000);
      });

      expect(screen.getByTestId("notification-count")).toHaveTextContent("1");
    });
  });

  describe("Logs", () => {
    it("adds log entries correctly", () => {
      renderWithProvider();

      const addButton = screen.getByText("Add Log");
      fireEvent.click(addButton);

      expect(screen.getByTestId("log-count")).toHaveTextContent("1");
      expect(screen.getByText("Test Agent: Test Action")).toBeInTheDocument();
    });

    it("generates unique IDs for log entries", () => {
      renderWithProvider();

      const addButton = screen.getByText("Add Log");
      fireEvent.click(addButton);
      fireEvent.click(addButton);

      expect(screen.getByTestId("log-count")).toHaveTextContent("2");

      const logs = screen.getAllByText(/Test Agent: Test Action/);
      expect(logs).toHaveLength(2);
    });

    it("clears logs correctly", () => {
      renderWithProvider();

      const addButton = screen.getByText("Add Log");
      const clearButton = screen.getByText("Clear Logs");

      fireEvent.click(addButton);
      fireEvent.click(addButton);
      expect(screen.getByTestId("log-count")).toHaveTextContent("2");

      fireEvent.click(clearButton);
      expect(screen.getByTestId("log-count")).toHaveTextContent("0");
    });

    it("limits log entries to 1000", () => {
      const TestComponentManyLogs: React.FC = () => {
        const { addLogEntry, logs } = useNotifications();

        const addManyLogs = () => {
          for (let i = 0; i < 1100; i++) {
            addLogEntry({
              agent: "Test Agent",
              action: `Action ${i}`,
              user_id: "user-123",
              level: "info",
              details: { index: i },
            });
          }
        };

        return (
          <div>
            <div data-testid="log-count">{logs.length}</div>
            <button type="button" onClick={addManyLogs}>
              Add Many Logs
            </button>
          </div>
        );
      };

      render(
        <NotificationProvider>
          <TestComponentManyLogs />
        </NotificationProvider>
      );

      const addButton = screen.getByText("Add Many Logs");
      fireEvent.click(addButton);

      // Should be limited to 1000
      expect(screen.getByTestId("log-count")).toHaveTextContent("1000");
    });
  });

  describe("Service Integration", () => {
    it("registers callbacks with notification service on mount", () => {
      const {
        notificationService,
      } = require("../../services/notificationService");

      renderWithProvider();

      expect(
        notificationService.registerNotificationCallback
      ).toHaveBeenCalled();
      expect(notificationService.registerAlertCallback).toHaveBeenCalled();
      expect(notificationService.registerLogCallback).toHaveBeenCalled();
    });
  });

  describe("Timestamp Generation", () => {
    it("adds timestamps to notifications", () => {
      const TestComponentTimestamp: React.FC = () => {
        const { addNotification, notifications } = useNotifications();

        return (
          <div>
            <button
              type="button"
              onClick={() =>
                addNotification({
                  type: NotificationType.Info,
                  title: "Timestamp Test",
                  message: "Test message",
                })
              }
            >
              Add Notification
            </button>
            {notifications.map((notification) => (
              <div
                key={notification.id}
                data-testid={`timestamp-${notification.id}`}
              >
                {notification.timestamp}
              </div>
            ))}
          </div>
        );
      };

      render(
        <NotificationProvider>
          <TestComponentTimestamp />
        </NotificationProvider>
      );

      const beforeTime = Date.now();
      const addButton = screen.getByText("Add Notification");
      fireEvent.click(addButton);
      const afterTime = Date.now();

      const timestampElement = screen.getByTestId(/timestamp-/);
      const timestamp = parseInt(timestampElement.textContent || "0");

      expect(timestamp).toBeGreaterThanOrEqual(beforeTime);
      expect(timestamp).toBeLessThanOrEqual(afterTime);
    });

    it("adds timestamps to alerts", () => {
      const TestComponentTimestamp: React.FC = () => {
        const { addAlert, alerts } = useNotifications();

        return (
          <div>
            <button
              type="button"
              onClick={() =>
                addAlert({
                  severity: AlertSeverity.Medium,
                  title: "Timestamp Test",
                  message: "Test message",
                  user_id: "user-123",
                })
              }
            >
              Add Alert
            </button>
            {alerts.map((alert) => (
              <div key={alert.id} data-testid={`timestamp-${alert.id}`}>
                {alert.timestamp}
              </div>
            ))}
          </div>
        );
      };

      render(
        <NotificationProvider>
          <TestComponentTimestamp />
        </NotificationProvider>
      );

      const beforeTime = Date.now();
      const addButton = screen.getByText("Add Alert");
      fireEvent.click(addButton);
      const afterTime = Date.now();

      const timestampElement = screen.getByTestId(/timestamp-/);
      const timestamp = parseInt(timestampElement.textContent || "0");

      expect(timestamp).toBeGreaterThanOrEqual(beforeTime);
      expect(timestamp).toBeLessThanOrEqual(afterTime);
    });

    it("adds timestamps to log entries", () => {
      const TestComponentTimestamp: React.FC = () => {
        const { addLogEntry, logs } = useNotifications();

        return (
          <div>
            <button
              type="button"
              onClick={() =>
                addLogEntry({
                  agent: "Test Agent",
                  action: "Timestamp Test",
                  user_id: "user-123",
                  level: "info",
                  details: {},
                })
              }
            >
              Add Log
            </button>
            {logs.map((log) => (
              <div key={log.id} data-testid={`timestamp-${log.id}`}>
                {log.timestamp}
              </div>
            ))}
          </div>
        );
      };

      render(
        <NotificationProvider>
          <TestComponentTimestamp />
        </NotificationProvider>
      );

      const beforeTime = Date.now();
      const addButton = screen.getByText("Add Log");
      fireEvent.click(addButton);
      const afterTime = Date.now();

      const timestampElement = screen.getByTestId(/timestamp-/);
      const timestamp = parseInt(timestampElement.textContent || "0");

      expect(timestamp).toBeGreaterThanOrEqual(beforeTime);
      expect(timestamp).toBeLessThanOrEqual(afterTime);
    });
  });
});
