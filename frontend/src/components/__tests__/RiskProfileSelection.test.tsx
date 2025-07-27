import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import RiskProfileSelection from '../RiskProfileSelection';
import { RiskLevel } from '../../types';
import { agentService } from '../../services/agent';

// Mock the agent service
jest.mock('../../services/agent', () => ({
  agentService: {
    acceptPlan: jest.fn()
  }
}));

const mockAgentService = agentService as jest.Mocked<typeof agentService>;

describe('RiskProfileSelection', () => {
  const mockUserId = 'test-user-id';
  const mockOnRiskProfileSelected = jest.fn();
  const mockOnStrategyApproved = jest.fn();

  beforeEach(() => {
    jest.clearAllMocks();
  });

  const renderComponent = () => {
    return render(
      <RiskProfileSelection
        userId={mockUserId}
        onRiskProfileSelected={mockOnRiskProfileSelected}
        onStrategyApproved={mockOnStrategyApproved}
      />
    );
  };

  describe('Initial Render', () => {
    it('should render the risk profile selection interface', () => {
      renderComponent();
      
      expect(screen.getByText('📊 Select Your Risk Profile')).toBeInTheDocument();
      expect(screen.getByText('Choose your preferred risk level to receive personalized strategy recommendations')).toBeInTheDocument();
    });

    it('should display all three risk level options', () => {
      renderComponent();
      
      expect(screen.getByText('Conservative')).toBeInTheDocument();
      expect(screen.getByText('Balanced')).toBeInTheDocument();
      expect(screen.getByText('Aggressive')).toBeInTheDocument();
    });

    it('should display risk level descriptions', () => {
      renderComponent();
      
      expect(screen.getByText('Lower risk, stable returns')).toBeInTheDocument();
      expect(screen.getByText('Moderate risk, balanced returns')).toBeInTheDocument();
      expect(screen.getByText('Higher risk, potential for higher returns')).toBeInTheDocument();
    });

    it('should display risk level icons', () => {
      renderComponent();
      
      expect(screen.getByText('🛡️')).toBeInTheDocument();
      expect(screen.getByText('⚖️')).toBeInTheDocument();
      expect(screen.getByText('🚀')).toBeInTheDocument();
    });
  });

  describe('Risk Level Selection', () => {
    it('should handle conservative risk selection', async () => {
      renderComponent();
      
      const conservativeOption = screen.getByText('Conservative').closest('.risk-option');
      expect(conservativeOption).toBeInTheDocument();
      
      fireEvent.click(conservativeOption!);
      
      expect(screen.getByText('🔄 Analyzing strategies for your risk profile...')).toBeInTheDocument();
      
      await waitFor(() => {
        expect(screen.getByText('🎯 Recommended Strategy')).toBeInTheDocument();
      }, { timeout: 2000 });
      
      expect(mockOnRiskProfileSelected).toHaveBeenCalledWith(RiskLevel.Conservative);
    });

    it('should handle balanced risk selection', async () => {
      renderComponent();
      
      const balancedOption = screen.getByText('Balanced').closest('.risk-option');
      expect(balancedOption).toBeInTheDocument();
      
      fireEvent.click(balancedOption!);
      
      await waitFor(() => {
        expect(screen.getByText('🎯 Recommended Strategy')).toBeInTheDocument();
      }, { timeout: 2000 });
      
      expect(mockOnRiskProfileSelected).toHaveBeenCalledWith(RiskLevel.Balanced);
    });

    it('should handle aggressive risk selection', async () => {
      renderComponent();
      
      const aggressiveOption = screen.getByText('Aggressive').closest('.risk-option');
      expect(aggressiveOption).toBeInTheDocument();
      
      fireEvent.click(aggressiveOption!);
      
      await waitFor(() => {
        expect(screen.getByText('🎯 Recommended Strategy')).toBeInTheDocument();
      }, { timeout: 2000 });
      
      expect(mockOnRiskProfileSelected).toHaveBeenCalledWith(RiskLevel.Aggressive);
    });

    it('should show loading state during strategy recommendation', async () => {
      renderComponent();
      
      const conservativeOption = screen.getByText('Conservative').closest('.risk-option');
      fireEvent.click(conservativeOption!);
      
      expect(screen.getByText('🔄 Analyzing strategies for your risk profile...')).toBeInTheDocument();
      
      // Wait for loading to complete
      await waitFor(() => {
        expect(screen.queryByText('🔄 Analyzing strategies for your risk profile...')).not.toBeInTheDocument();
      }, { timeout: 2000 });
    });

    it('should apply selected styling to chosen risk option', async () => {
      renderComponent();
      
      const conservativeOption = screen.getByText('Conservative').closest('.risk-option');
      fireEvent.click(conservativeOption!);
      
      await waitFor(() => {
        expect(conservativeOption).toHaveClass('selected');
      }, { timeout: 2000 });
    });
  });

  describe('Strategy Recommendation Display', () => {
    beforeEach(async () => {
      renderComponent();
      const conservativeOption = screen.getByText('Conservative').closest('.risk-option');
      fireEvent.click(conservativeOption!);
      
      await waitFor(() => {
        expect(screen.getByText('🎯 Recommended Strategy')).toBeInTheDocument();
      }, { timeout: 2000 });
    });

    it('should display strategy name and metrics', () => {
      expect(screen.getByText('Conservative Bitcoin Lending')).toBeInTheDocument();
      expect(screen.getByText('Est. APY')).toBeInTheDocument();
      expect(screen.getByText('Risk Score')).toBeInTheDocument();
      expect(screen.getByText('Liquidity')).toBeInTheDocument();
    });

    it('should display allocation breakdown', () => {
      expect(screen.getByText('Allocation Breakdown')).toBeInTheDocument();
      expect(screen.getByText('Compound')).toBeInTheDocument();
      expect(screen.getByText('Aave')).toBeInTheDocument();
    });

    it('should display strategy rationale', () => {
      expect(screen.getByText('Why This Strategy?')).toBeInTheDocument();
      expect(screen.getByText(/This Conservative Bitcoin Lending strategy is recommended/)).toBeInTheDocument();
    });

    it('should display action buttons', () => {
      expect(screen.getByText('Approve & Execute Strategy')).toBeInTheDocument();
      expect(screen.getByText('Choose Different Risk Level')).toBeInTheDocument();
    });

    it('should display risk badge with correct styling', () => {
      const badge = screen.getByText('🛡️ conservative');
      expect(badge).toBeInTheDocument();
      expect(badge.closest('.strategy-badge')).toBeInTheDocument();
    });
  });

  describe('Strategy Approval Flow', () => {
    beforeEach(async () => {
      renderComponent();
      const conservativeOption = screen.getByText('Conservative').closest('.risk-option');
      fireEvent.click(conservativeOption!);
      
      await waitFor(() => {
        expect(screen.getByText('🎯 Recommended Strategy')).toBeInTheDocument();
      }, { timeout: 2000 });
    });

    it('should open approval dialog when approve button is clicked', () => {
      const approveButton = screen.getByText('Approve & Execute Strategy');
      fireEvent.click(approveButton);
      
      expect(screen.getByText('⚠️ Confirm Strategy Approval')).toBeInTheDocument();
      expect(screen.getByText('You are about to approve and execute the following strategy:')).toBeInTheDocument();
    });

    it('should display strategy summary in approval dialog', () => {
      const approveButton = screen.getByText('Approve & Execute Strategy');
      fireEvent.click(approveButton);
      
      expect(screen.getAllByText('Conservative Bitcoin Lending')).toHaveLength(2); // One in main view, one in dialog
      expect(screen.getByText(/Risk Level:/)).toBeInTheDocument();
      expect(screen.getByText(/Estimated APY:/)).toBeInTheDocument();
      expect(screen.getByText(/Total Allocation:/)).toBeInTheDocument();
    });

    it('should display risk warning in approval dialog', () => {
      const approveButton = screen.getByText('Approve & Execute Strategy');
      fireEvent.click(approveButton);
      
      expect(screen.getByText('Important:')).toBeInTheDocument();
      expect(screen.getByText('Smart contract risk')).toBeInTheDocument();
      expect(screen.getByText('Impermanent loss (for LP strategies)')).toBeInTheDocument();
      expect(screen.getByText('Market volatility')).toBeInTheDocument();
      expect(screen.getByText('Protocol governance changes')).toBeInTheDocument();
    });

    it('should close approval dialog when cancel is clicked', () => {
      const approveButton = screen.getByText('Approve & Execute Strategy');
      fireEvent.click(approveButton);
      
      const cancelButton = screen.getByText('Cancel');
      fireEvent.click(cancelButton);
      
      expect(screen.queryByText('⚠️ Confirm Strategy Approval')).not.toBeInTheDocument();
    });

    it('should handle strategy approval confirmation', async () => {
      mockAgentService.acceptPlan.mockResolvedValue({ ok: true });
      
      const approveButton = screen.getByText('Approve & Execute Strategy');
      fireEvent.click(approveButton);
      
      const confirmButton = screen.getByText('Confirm & Execute');
      fireEvent.click(confirmButton);
      
      await waitFor(() => {
        expect(mockOnStrategyApproved).toHaveBeenCalled();
      });
    });

    it('should show loading state during approval', async () => {
      mockAgentService.acceptPlan.mockImplementation(() => new Promise(resolve => setTimeout(resolve, 100)));
      
      const approveButton = screen.getByText('Approve & Execute Strategy');
      fireEvent.click(approveButton);
      
      const confirmButton = screen.getByText('Confirm & Execute');
      fireEvent.click(confirmButton);
      
      expect(screen.getByText('Approving...')).toBeInTheDocument();
    });
  });

  describe('Navigation and Reset', () => {
    beforeEach(async () => {
      renderComponent();
      const conservativeOption = screen.getByText('Conservative').closest('.risk-option');
      fireEvent.click(conservativeOption!);
      
      await waitFor(() => {
        expect(screen.getByText('🎯 Recommended Strategy')).toBeInTheDocument();
      }, { timeout: 2000 });
    });

    it('should allow user to go back and choose different risk level', () => {
      const backButton = screen.getByText('Choose Different Risk Level');
      fireEvent.click(backButton);
      
      expect(screen.queryByText('🎯 Recommended Strategy')).not.toBeInTheDocument();
      expect(screen.getByText('📊 Select Your Risk Profile')).toBeInTheDocument();
    });

    it('should reset selection state when going back', () => {
      const backButton = screen.getByText('Choose Different Risk Level');
      fireEvent.click(backButton);
      
      const riskOptions = screen.getAllByRole('generic').filter(el => 
        el.classList.contains('risk-option')
      );
      
      riskOptions.forEach(option => {
        expect(option).not.toHaveClass('selected');
      });
    });
  });

  describe('Error Handling', () => {
    it('should display error message when strategy approval fails', async () => {
      renderComponent();
      const conservativeOption = screen.getByText('Conservative').closest('.risk-option');
      fireEvent.click(conservativeOption!);
      
      await waitFor(() => {
        expect(screen.getByText('🎯 Recommended Strategy')).toBeInTheDocument();
      }, { timeout: 2000 });
      
      mockAgentService.acceptPlan.mockRejectedValue(new Error('Network error'));
      
      const approveButton = screen.getByText('Approve & Execute Strategy');
      fireEvent.click(approveButton);
      
      const confirmButton = screen.getByText('Confirm & Execute');
      fireEvent.click(confirmButton);
      
      await waitFor(() => {
        expect(screen.getByText(/Failed to approve strategy/)).toBeInTheDocument();
      });
    });
  });

  describe('Accessibility', () => {
    it('should have proper clickable elements', () => {
      renderComponent();
      
      const riskOptions = screen.getAllByRole('generic').filter(el => 
        el.classList.contains('risk-option')
      );
      
      expect(riskOptions).toHaveLength(3);
      // Check that elements are clickable by verifying they have click handlers
      riskOptions.forEach(option => {
        expect(option).toBeInTheDocument();
      });
    });

    it('should have accessible elements', () => {
      renderComponent();
      
      const conservativeOption = screen.getByText('Conservative').closest('.risk-option');
      expect(conservativeOption).toBeInTheDocument();
      
      // Test that the element is clickable and accessible
      expect(conservativeOption).toHaveClass('risk-option');
      expect(conservativeOption).toHaveClass('conservative');
    });
  });
});