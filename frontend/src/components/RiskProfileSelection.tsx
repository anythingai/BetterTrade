import React, { useState, useEffect, useMemo } from 'react';
import { RiskLevel, StrategyPlan, UserId, PlanStatus } from '../types';
import { agentService } from '../services/agent';
import './RiskProfileSelection.css';

interface RiskProfileSelectionProps {
  userId: UserId;
  onRiskProfileSelected: (riskLevel: RiskLevel) => void;
  onStrategyApproved: (plan: StrategyPlan) => void;
}

interface MockStrategyTemplate {
  id: string;
  name: string;
  risk_level: RiskLevel;
  venues: string[];
  est_apy_band: [number, number];
  description: string;
  risk_score: number;
  liquidity_score: number;
  complexity: string;
}

const RiskProfileSelection: React.FC<RiskProfileSelectionProps> = ({
  userId,
  onRiskProfileSelected,
  onStrategyApproved
}) => {
  const [selectedRisk, setSelectedRisk] = useState<RiskLevel | null>(null);
  const [recommendedStrategy, setRecommendedStrategy] = useState<StrategyPlan | null>(null);
  const [availableStrategies, setAvailableStrategies] = useState<MockStrategyTemplate[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string>('');
  const [showApprovalDialog, setShowApprovalDialog] = useState(false);

  // Mock strategy templates for demo
  const mockStrategies: MockStrategyTemplate[] = useMemo(() => [
    {
      id: 'conservative-lending',
      name: 'Conservative Bitcoin Lending',
      risk_level: RiskLevel.Conservative,
      venues: ['Compound', 'Aave'],
      est_apy_band: [3.5, 6.2],
      description: 'Low-risk lending strategy focusing on established DeFi protocols with strong track records.',
      risk_score: 2.1,
      liquidity_score: 9.2,
      complexity: 'Simple'
    },
    {
      id: 'balanced-lp',
      name: 'Balanced Liquidity Provision',
      risk_level: RiskLevel.Balanced,
      venues: ['Uniswap V3', 'Curve'],
      est_apy_band: [8.5, 15.3],
      description: 'Moderate-risk strategy providing liquidity to BTC/stablecoin pairs with active management.',
      risk_score: 5.4,
      liquidity_score: 7.8,
      complexity: 'Moderate'
    },
    {
      id: 'aggressive-yield',
      name: 'Aggressive Yield Farming',
      risk_level: RiskLevel.Aggressive,
      venues: ['Convex', 'Yearn', 'Beefy'],
      est_apy_band: [18.2, 35.7],
      description: 'High-risk, high-reward strategy utilizing multiple yield farming protocols and leverage.',
      risk_score: 8.7,
      liquidity_score: 4.3,
      complexity: 'Complex'
    }
  ], []);

  useEffect(() => {
    setAvailableStrategies(mockStrategies);
  }, [mockStrategies]);

  const riskLevels = [
    {
      level: RiskLevel.Conservative,
      label: 'Conservative',
      description: 'Lower risk, stable returns',
      color: '#10B981',
      icon: '🛡️'
    },
    {
      level: RiskLevel.Balanced,
      label: 'Balanced',
      description: 'Moderate risk, balanced returns',
      color: '#F59E0B',
      icon: '⚖️'
    },
    {
      level: RiskLevel.Aggressive,
      label: 'Aggressive',
      description: 'Higher risk, potential for higher returns',
      color: '#EF4444',
      icon: '🚀'
    }
  ];

  const handleRiskSelection = async (riskLevel: RiskLevel) => {
    setSelectedRisk(riskLevel);
    setIsLoading(true);
    setError('');
    setRecommendedStrategy(null); // Clear previous recommendation

    try {
      // Add artificial delay to show loading state
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // Mock strategy recommendation
      const matchingStrategy = mockStrategies.find(s => s.risk_level === riskLevel);
      
      if (matchingStrategy) {
        // Create mock strategy plan
        const mockPlan: StrategyPlan = {
          id: `plan-${Date.now()}`,
          user_id: userId,
          template_id: matchingStrategy.id,
          allocations: [
            {
              venue_id: matchingStrategy.venues[0],
              amount_sats: BigInt(50000000), // 0.5 BTC
              percentage: 60
            },
            {
              venue_id: matchingStrategy.venues[1] || matchingStrategy.venues[0],
              amount_sats: BigInt(33333333), // ~0.33 BTC
              percentage: 40
            }
          ],
          created_at: Date.now(),
          status: PlanStatus.Pending,
          rationale: generateRationale(matchingStrategy, riskLevel)
        };

        setRecommendedStrategy(mockPlan);
        onRiskProfileSelected(riskLevel);
      }
    } catch (err) {
      setError(`Failed to get strategy recommendation: ${err instanceof Error ? err.message : 'Unknown error'}`);
    } finally {
      setIsLoading(false);
    }
  };

  const generateRationale = (strategy: MockStrategyTemplate, riskLevel: RiskLevel): string => {
    const riskDescriptions = {
      [RiskLevel.Conservative]: 'prioritizes capital preservation with steady, predictable returns',
      [RiskLevel.Balanced]: 'balances growth potential with manageable risk exposure',
      [RiskLevel.Aggressive]: 'maximizes yield potential while accepting higher volatility'
    };

    return `This ${strategy.name} strategy is recommended because it ${riskDescriptions[riskLevel]}. ` +
           `With an estimated APY of ${strategy.est_apy_band[0]}%-${strategy.est_apy_band[1]}% and a risk score of ${strategy.risk_score}/10, ` +
           `it aligns well with your ${riskLevel} risk profile. The strategy utilizes ${strategy.venues.join(' and ')} ` +
           `to provide ${strategy.complexity.toLowerCase()} execution with a liquidity score of ${strategy.liquidity_score}/10.`;
  };

  const handleApproveStrategy = async () => {
    if (!recommendedStrategy) return;

    setIsLoading(true);
    setError('');

    try {
      // Mock strategy approval
      await agentService.acceptPlan(userId, recommendedStrategy.id);
      
      // For demo, always succeed
      const approvedPlan = {
        ...recommendedStrategy,
        status: PlanStatus.Approved
      };
      
      onStrategyApproved(approvedPlan);
      setShowApprovalDialog(false);
    } catch (err) {
      setError(`Failed to approve strategy: ${err instanceof Error ? err.message : 'Unknown error'}`);
    } finally {
      setIsLoading(false);
    }
  };

  const formatSats = (sats: bigint): string => {
    return (Number(sats) / 100000000).toFixed(8);
  };

  const getRiskIcon = (riskLevel: RiskLevel): string => {
    return riskLevels.find(r => r.level === riskLevel)?.icon || '📊';
  };

  return (
    <div className="risk-profile-selection">
      <div className="section-header">
        <h3>📊 Select Your Risk Profile</h3>
        <p>Choose your preferred risk level to receive personalized strategy recommendations</p>
      </div>

      {error && (
        <div className="error-message">
          ❌ {error}
        </div>
      )}

      <div className="risk-slider-container">
        <div className="risk-options">
          {riskLevels.map((risk) => (
            <div
              key={risk.level}
              className={`risk-option ${risk.level.toLowerCase()} ${selectedRisk === risk.level ? 'selected' : ''}`}
              onClick={() => handleRiskSelection(risk.level)}
            >
              <div className="risk-icon">{risk.icon}</div>
              <div className="risk-content">
                <h4>{risk.label}</h4>
                <p>{risk.description}</p>
              </div>
              <div className="risk-selector">
                <div className="radio-button" />
              </div>
            </div>
          ))}
        </div>
      </div>

      {isLoading && (
        <div className="loading-state">
          <p>🔄 Analyzing strategies for your risk profile...</p>
        </div>
      )}

      {recommendedStrategy && !isLoading && (
        <div className="strategy-recommendation">
          <div className="recommendation-header">
            <h4>🎯 Recommended Strategy</h4>
            <div className={`strategy-badge ${selectedRisk!.toLowerCase()}`}>
              {getRiskIcon(selectedRisk!)} {selectedRisk}
            </div>
          </div>

          <div className="strategy-card">
            <div className="strategy-overview">
              <h5>{availableStrategies.find(s => s.id === recommendedStrategy.template_id)?.name}</h5>
              <div className="strategy-metrics">
                <div className="metric">
                  <span className="metric-label">Est. APY</span>
                  <span className="metric-value">
                    {availableStrategies.find(s => s.id === recommendedStrategy.template_id)?.est_apy_band[0]}% - 
                    {availableStrategies.find(s => s.id === recommendedStrategy.template_id)?.est_apy_band[1]}%
                  </span>
                </div>
                <div className="metric">
                  <span className="metric-label">Risk Score</span>
                  <span className="metric-value">
                    {availableStrategies.find(s => s.id === recommendedStrategy.template_id)?.risk_score}/10
                  </span>
                </div>
                <div className="metric">
                  <span className="metric-label">Liquidity</span>
                  <span className="metric-value">
                    {availableStrategies.find(s => s.id === recommendedStrategy.template_id)?.liquidity_score}/10
                  </span>
                </div>
              </div>
            </div>

            <div className="strategy-details">
              <div className="allocation-breakdown">
                <h6>Allocation Breakdown</h6>
                {recommendedStrategy.allocations.map((allocation, index) => (
                  <div key={index} className="allocation-item">
                    <span className="venue-name">{allocation.venue_id}</span>
                    <span className="allocation-amount">
                      {formatSats(allocation.amount_sats)} BTC ({allocation.percentage}%)
                    </span>
                  </div>
                ))}
              </div>

              <div className="strategy-rationale">
                <h6>Why This Strategy?</h6>
                <p>{recommendedStrategy.rationale}</p>
              </div>
            </div>

            <div className="strategy-actions">
              <button
                type="button"
                onClick={() => setShowApprovalDialog(true)}
                className="approve-btn"
                disabled={isLoading}
              >
                Approve & Execute Strategy
              </button>
              <button
                type="button"
                onClick={() => {
                  setSelectedRisk(null);
                  setRecommendedStrategy(null);
                  setError('');
                }}
                className="back-btn"
              >
                Choose Different Risk Level
              </button>
            </div>
          </div>
        </div>
      )}

      {showApprovalDialog && (
        <div className="approval-dialog-overlay">
          <div className="approval-dialog">
            <div className="dialog-header">
              <h4>⚠️ Confirm Strategy Approval</h4>
            </div>
            
            <div className="dialog-content">
              <p>You are about to approve and execute the following strategy:</p>
              
              <div className="strategy-summary">
                <h5>{availableStrategies.find(s => s.id === recommendedStrategy?.template_id)?.name}</h5>
                <div className="summary-details">
                  <div>Risk Level: <strong>{selectedRisk}</strong></div>
                  <div>Estimated APY: <strong>
                    {availableStrategies.find(s => s.id === recommendedStrategy?.template_id)?.est_apy_band[0]}% - 
                    {availableStrategies.find(s => s.id === recommendedStrategy?.template_id)?.est_apy_band[1]}%
                  </strong></div>
                  <div>Total Allocation: <strong>
                    {formatSats(recommendedStrategy?.allocations.reduce((sum, alloc) => sum + alloc.amount_sats, 0n) || 0n)} BTC
                  </strong></div>
                </div>
              </div>

              <div className="risk-warning">
                <p><strong>Important:</strong> This strategy involves DeFi protocols and carries inherent risks including:</p>
                <ul>
                  <li>Smart contract risk</li>
                  <li>Impermanent loss (for LP strategies)</li>
                  <li>Market volatility</li>
                  <li>Protocol governance changes</li>
                </ul>
                <p>Only invest what you can afford to lose.</p>
              </div>
            </div>

            <div className="dialog-actions">
              <button
                type="button"
                onClick={handleApproveStrategy}
                className="confirm-btn"
                disabled={isLoading}
              >
                {isLoading ? 'Approving...' : 'Confirm & Execute'}
              </button>
              <button
                type="button"
                onClick={() => setShowApprovalDialog(false)}
                className="cancel-btn"
                disabled={isLoading}
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default RiskProfileSelection;