import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import '@testing-library/jest-dom';
import { NotificationDemo } from '../NotificationDemo';
import { NotificationProvider } from '../../contexts/NotificationContext';

describe('NotificationDemo', () => {
  const renderWithProvider = () => {
    return render(
      <NotificationProvider>
        <NotificationDemo />
      </NotificationProvider>
    );
  };

  it('renders notification demo interface', () => {
    renderWithProvider();

    expect(screen.getByText('Notification System Demo')).toBeInTheDocument();
    expect(screen.getByText('Toast Notifications')).toBeInTheDocument();
    expect(screen.getByText('Risk Alerts')).toBeInTheDocument();
    expect(screen.getByText('System Logs')).toBeInTheDocument();
    expect(screen.getByText('Service Integration')).toBeInTheDocument();
  });

  it('has all notification type buttons', () => {
    renderWithProvider();

    expect(screen.getByRole('button', { name: 'Success Notification' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Error Notification' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Warning Notification' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Info Notification' })).toBeInTheDocument();
  });

  it('has all alert severity buttons', () => {
    renderWithProvider();

    expect(screen.getByRole('button', { name: 'Critical Alert' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'High Alert' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Medium Alert' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Low Alert' })).toBeInTheDocument();
  });

  it('has all log level buttons', () => {
    renderWithProvider();

    expect(screen.getByRole('button', { name: 'Info Log' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Warning Log' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Error Log' })).toBeInTheDocument();
  });

  it('has service integration buttons', () => {
    renderWithProvider();

    expect(screen.getByRole('button', { name: 'Mock Transaction Event' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Mock Risk Alert' })).toBeInTheDocument();
  });

  it('buttons are clickable', () => {
    renderWithProvider();

    const successButton = screen.getByRole('button', { name: 'Success Notification' });
    fireEvent.click(successButton);

    const criticalButton = screen.getByRole('button', { name: 'Critical Alert' });
    fireEvent.click(criticalButton);

    const infoLogButton = screen.getByRole('button', { name: 'Info Log' });
    fireEvent.click(infoLogButton);

    // Buttons should be clickable without errors
    expect(successButton).toBeInTheDocument();
    expect(criticalButton).toBeInTheDocument();
    expect(infoLogButton).toBeInTheDocument();
  });

  it('applies custom className', () => {
    const { container } = render(
      <NotificationProvider>
        <NotificationDemo className="custom-demo" />
      </NotificationProvider>
    );

    expect(container.querySelector('.custom-demo')).toBeInTheDocument();
  });
});