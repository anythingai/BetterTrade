# BetterTrade Demo Script
## Hackathon MVP Demonstration

### Overview
This demo showcases the BetterTrade Bitcoin DeFi copilot system, featuring specialized AI agents that automate yield strategies across Bitcoin-enabled protocols. The demonstration follows a complete user journey from wallet connection to active yield generation.

### Demo Environment Setup
- **Network**: Bitcoin Testnet
- **Duration**: 10-15 minutes
- **Audience**: Technical and non-technical stakeholders
- **Prerequisites**: Demo data pre-loaded, canisters deployed

---

## Demo Flow

### Step 1: Introduction and System Overview (2 minutes)

**Presenter Actions:**
- Open BetterTrade application
- Show system architecture diagram
- Explain multi-agent approach

**Key Points to Emphasize:**
- "BetterTrade is composed of specialized AI agents running as ICP canisters"
- "Each agent has a specific role: Strategy Selection, Execution, Risk Management"
- "The system uses ICP's native Bitcoin integration and threshold ECDSA for secure, trustless operations"

**Demo User:** Alice (Conservative Profile)

---

### Step 2: User Onboarding and Wallet Connection (2 minutes)

**Presenter Actions:**
1. Click "Connect Wallet" button
2. Show wallet connection interface
3. Register user with display name "Alice (Conservative)"
4. Generate testnet Bitcoin address

**Script:**
> "Let's start by connecting Alice's wallet. BetterTrade supports multiple wallet types and automatically generates a secure testnet Bitcoin address using ICP's threshold ECDSA technology."

**Expected Results:**
- User registration successful
- Testnet address generated: `tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx`
- Dashboard shows 0 BTC balance
- Wallet status: Connected

**Technical Details to Mention:**
- No private keys stored locally
- Threshold ECDSA provides institutional-grade security
- Multi-signature protection without complexity

---

### Step 3: Bitcoin Deposit and Detection (2 minutes)

**Presenter Actions:**
1. Show pre-funded testnet transaction
2. Demonstrate deposit detection
3. Display balance update in real-time
4. Show transaction confirmation tracking

**Script:**
> "Alice has sent 0.5 BTC to her generated address. Watch as BetterTrade automatically detects the deposit and updates her portfolio balance. The system tracks confirmations in real-time using ICP's Bitcoin API."

**Expected Results:**
- Deposit detected after 1 confirmation
- Portfolio balance: 0.5 BTC
- Transaction appears in history with status
- UTXOs available for strategy execution

**Demo Data:**
```
Deposit Transaction: demo_deposit_alice
Amount: 0.5 BTC (50,000,000 sats)
Confirmations: 6/6
Status: Confirmed
```

---

### Step 4: Risk Profile Selection and Strategy Recommendation (3 minutes)

**Presenter Actions:**
1. Navigate to risk profile selection
2. Show risk slider with three options
3. Select "Conservative" profile
4. Display strategy recommendations with scoring

**Script:**
> "Now Alice needs to select her risk profile. BetterTrade offers three levels: Conservative, Balanced, and Aggressive. Each profile gets tailored strategy recommendations based on APY potential, risk factors, and liquidity considerations."

**Expected Results:**
- Conservative strategies displayed
- Top recommendation: "Conservative Bitcoin Lending"
- Expected APY: 4.5% - 6.2%
- Venues: BlockFi, Celsius, Nexo
- Detailed scoring breakdown shown

**Strategy Scoring Explanation:**
- APY Score: 65/100
- Risk Alignment: 95/100 (perfect match)
- Liquidity Score: 80/100
- **Overall Score: 82/100**

**Rationale Display:**
> "Recommended for your conservative risk profile. Expected APY: 4.5% - 6.2%. Available on 3 venues: BlockFi, Celsius, Nexo. Overall score: 82/100. Perfect match for conservative investors seeking capital preservation."

---

### Step 5: Strategy Approval and Execution (3 minutes)

**Presenter Actions:**
1. Review strategy details and allocations
2. Click "Approve Strategy" button
3. Show transaction construction process
4. Display signing and broadcasting steps
5. Provide transaction ID for tracking

**Script:**
> "Alice reviews the strategy details and approves the plan. BetterTrade now constructs a Bitcoin transaction to execute the strategy. The Execution Agent builds the transaction, signs it using threshold ECDSA, and broadcasts it to the Bitcoin network."

**Expected Results:**
- Strategy plan approved and locked
- Transaction constructed with proper allocations
- Signing successful using t-ECDSA
- Transaction broadcast to testnet
- Transaction ID: `demo_tx_alice_conservative-lending`

**Technical Process Shown:**
1. **Plan Approval**: Strategy locked to prevent conflicts
2. **UTXO Selection**: Optimal UTXO selection for transaction
3. **Transaction Construction**: Multi-output transaction created
4. **Threshold Signing**: Secure signing without private key exposure
5. **Network Broadcast**: Transaction submitted to Bitcoin testnet

**Allocation Display:**
- BlockFi: 0.133 BTC (33.3%)
- Celsius: 0.133 BTC (33.3%)
- Nexo: 0.134 BTC (33.4%)
- **Total Allocated**: 0.4 BTC (80% of balance)
- **Reserved**: 0.1 BTC (20% for fees and flexibility)

---

### Step 6: Portfolio Monitoring and Performance (2 minutes)

**Presenter Actions:**
1. Show updated portfolio dashboard
2. Display active strategy status
3. Show position breakdown across venues
4. Demonstrate real-time performance tracking

**Script:**
> "Alice's strategy is now active! The portfolio dashboard shows her positions across three lending venues. BetterTrade continuously monitors performance and provides real-time updates on yield generation and position status."

**Expected Results:**
- Active strategy: Conservative Bitcoin Lending
- Positions across 3 venues displayed
- Current performance: +2.1% (simulated)
- Transaction history with confirmations
- Estimated annual yield: 5.3%

**Portfolio Summary:**
```
Total Balance: 0.5 BTC
Active Strategy: Conservative Bitcoin Lending
Allocated Amount: 0.4 BTC (80%)
Available Balance: 0.1 BTC (20%)
Current Performance: +2.1%
Estimated Annual Yield: 5.3%
```

**Position Breakdown:**
- **BlockFi**: 0.133 BTC → 0.136 BTC (+2.3%)
- **Celsius**: 0.133 BTC → 0.135 BTC (+1.5%)
- **Nexo**: 0.134 BTC → 0.137 BTC (+2.2%)

---

### Step 7: Risk Guard Demonstration (2 minutes)

**Presenter Actions:**
1. Show risk guard configuration
2. Set maximum drawdown limit (5% for conservative)
3. Simulate market downturn scenario
4. Display alert and protective actions

**Script:**
> "BetterTrade includes a Risk Guard agent that continuously monitors Alice's portfolio. Let's configure a 5% maximum drawdown limit and see how the system responds to market volatility."

**Expected Results:**
- Risk guard configured: 5% max drawdown
- Continuous monitoring active
- Simulated market drop triggers alert
- Protective actions recommended (pause/unwind)

**Risk Guard Configuration:**
```
Maximum Drawdown: 5%
Liquidity Exit Threshold: 0.05 BTC
Action Mode: Automatic Protection
Monitoring Status: Active
```

**Simulated Alert:**
> "⚠️ RISK ALERT: Portfolio down 5.2% from peak. Maximum drawdown threshold breached. Recommended action: Pause new allocations and consider partial position unwinding."

---

## Demo Variations

### Quick Demo (5 minutes)
Focus on steps 2, 4, and 5 for time-constrained presentations.

### Technical Deep Dive (20 minutes)
Include detailed explanations of:
- Inter-canister communication
- Threshold ECDSA implementation
- Bitcoin transaction construction
- Strategy scoring algorithms

### Multi-User Demo
Show all three demo users (Alice, Bob, Charlie) with different risk profiles executing simultaneously.

---

## Demo Reset Instructions

### Before Each Presentation:
1. Run demo reset script: `./demo/reset_demo.sh`
2. Verify canister deployment status
3. Pre-load demo data using: `dfx canister call demo_scenario load_demo_data`
4. Confirm Bitcoin testnet connectivity

### Reset Commands:
```bash
# Reset all demo data
dfx canister call user_registry reset_demo_users
dfx canister call portfolio_state reset_demo_portfolios  
dfx canister call strategy_selector reset_demo_plans
dfx canister call execution_agent reset_demo_executions

# Reload demo data
dfx canister call demo_scenario load_demo_data
```

---

## Troubleshooting

### Common Issues:

**Issue**: Deposit not detected
**Solution**: Check Bitcoin testnet connectivity, verify address generation

**Issue**: Strategy recommendation fails
**Solution**: Ensure user has sufficient balance, check risk profile setting

**Issue**: Transaction signing fails
**Solution**: Verify t-ECDSA subnet availability, check user authorization

**Issue**: Portfolio not updating
**Solution**: Check inter-canister communication, verify transaction confirmation

### Demo Fallbacks:
- Pre-recorded transaction confirmations
- Mock data for network issues
- Simplified explanations for technical failures

---

## Key Messages

### For Technical Audience:
- "BetterTrade leverages ICP's unique Bitcoin integration capabilities"
- "Threshold ECDSA eliminates single points of failure"
- "Multi-agent architecture enables specialized, auditable decision-making"
- "Inter-canister communication provides transparent agent coordination"

### For Business Audience:
- "Automated yield generation without giving up custody"
- "Institutional-grade security with user-friendly interface"
- "Transparent, explainable AI decision-making"
- "Built-in risk protection and continuous monitoring"

### For Investors:
- "Addresses the $1.2T idle Bitcoin market opportunity"
- "Reduces complexity barrier for Bitcoin DeFi participation"
- "Scalable architecture for future protocol integrations"
- "Regulatory-friendly approach with full audit trails"

---

## Post-Demo Q&A Preparation

### Expected Questions:

**Q**: "How does this compare to existing Bitcoin DeFi solutions?"
**A**: "BetterTrade is unique in its multi-agent approach and use of ICP's native Bitcoin integration. Unlike wrapped Bitcoin solutions, users maintain direct custody while accessing DeFi yields."

**Q**: "What happens if a venue fails or gets hacked?"
**A**: "The system diversifies across multiple venues and includes risk monitoring. The Risk Guard can automatically trigger protective actions based on venue-specific risk signals."

**Q**: "How do you ensure the AI agents make good decisions?"
**A**: "All agent decisions are explainable and auditable. The system uses transparent scoring algorithms and maintains complete audit trails of all actions and rationales."

**Q**: "What's the roadmap for additional features?"
**A**: "Phase 2 includes Market Monitor and Sentiment agents for real-time strategy adaptation. Phase 3 adds cross-protocol arbitrage and advanced hedging strategies."

---

## Demo Success Metrics

### Engagement Indicators:
- Questions about technical implementation
- Requests for follow-up demonstrations
- Interest in integration possibilities
- Feedback on user experience

### Technical Validation:
- All demo steps complete without errors
- Real-time transaction confirmations
- Accurate portfolio calculations
- Responsive user interface

### Business Impact:
- Clear value proposition understanding
- Competitive advantage recognition
- Market opportunity validation
- Investment interest generation