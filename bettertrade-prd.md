# BetterTrade Product Requirements Document

> **Version:** Draft v0.9\
> **Date:** July 21, 2025\
> **Owner:** \<Your Name / Team>\
> **Project:** BetterTrade — Modular Multi‑Agent AI Copilot for Bitcoin DeFi on ICP

---

## Document Purpose

This PRD defines the vision, scope, requirements, architecture, UX, success metrics, and delivery milestones for **BetterTrade**, a **multi‑agent, Bitcoin‑native DeFi copilot built on the Internet Computer Protocol (ICP)**. It is optimized both for **hackathon deliverability** (scoped MVP) and a **post‑hackathon roadmap** toward production readiness.

The document is intended for product, engineering, design, AI/ML, DevOps, security, go‑to‑market, and hackathon judges.

---

## Quick Links (TOC)

- [BetterTrade Product Requirements Document](#bitsight-product-requirements-document)
  - [Document Purpose](#document-purpose)
  - [Quick Links (TOC)](#quick-links-toc)
  - [1. Executive Summary](#1-executive-summary)
  - [2. Problem Statement](#2-problem-statement)
  - [3. Goals \& Non‑Goals](#3-goals--nongoals)
    - [3.1 Product Goals](#31-product-goals)
    - [3.2 Non‑Goals (Initial MVP)](#32-nongoals-initial-mvp)
  - [4. Target Users \& Personas](#4-target-users--personas)
  - [5. Value Proposition by Persona](#5-value-proposition-by-persona)
    - [BTC Retail Holder](#btc-retail-holder)
    - [DeFi Power User](#defi-power-user)
    - [DAO / Treasury](#dao--treasury)
    - [Wallet / Custodian Integrator](#wallet--custodian-integrator)
  - [6. Competitive Landscape \& Differentiators](#6-competitive-landscape--differentiators)
  - [7. Use Cases \& User Stories](#7-use-cases--user-stories)
    - [7.1 Core MVP Stories](#71-core-mvp-stories)
    - [7.2 Extended Stories (Phase 2+)](#72-extended-stories-phase-2)
    - [7.3 Edge / Failure Stories](#73-edge--failure-stories)
  - [8. User Experience Overview](#8-user-experience-overview)
    - [8.1 High‑Level UX Flow (Retail MVP)](#81-highlevel-ux-flow-retail-mvp)
    - [8.2 Screens (MVP)](#82-screens-mvp)
    - [8.3 Accessibility \& Localization](#83-accessibility--localization)
  - [9. System Overview \& Multi‑Agent Architecture](#9-system-overview--multiagent-architecture)
    - [9.1 Agent Roles](#91-agent-roles)
    - [9.2 Data + Control Flow](#92-data--control-flow)
    - [9.3 Deployment Topology](#93-deployment-topology)
  - [10. Functional Requirements](#10-functional-requirements)
    - [10.1 Account \& Wallet](#101-account--wallet)
    - [10.2 Portfolio Dashboard](#102-portfolio-dashboard)
    - [10.3 Strategy Selector Agent](#103-strategy-selector-agent)
    - [10.4 Execution Agent](#104-execution-agent)
    - [10.5 Sentiment Agent (Phase 2)](#105-sentiment-agent-phase-2)
    - [10.6 Market Monitor Agent](#106-market-monitor-agent)
    - [10.7 Risk Guard Agent](#107-risk-guard-agent)
    - [10.8 Notifications \& Alerts](#108-notifications--alerts)
    - [10.9 Governance \& Parameters](#109-governance--parameters)
  - [11. Non‑Functional Requirements](#11-nonfunctional-requirements)
  - [12. Data Model](#12-data-model)
    - [12.1 Entities](#121-entities)
    - [12.2 Relationships](#122-relationships)
    - [12.3 Storage Considerations](#123-storage-considerations)
  - [13. Smart Contract / Canister Interfaces](#13-smart-contract--canister-interfaces)
    - [13.1 User Registry Canister](#131-user-registry-canister)
    - [13.2 Strategy Selector Canister](#132-strategy-selector-canister)
    - [13.3 Execution Agent Canister](#133-execution-agent-canister)
    - [13.4 Market Monitor Canister](#134-market-monitor-canister)
    - [13.5 Sentiment Agent Canister](#135-sentiment-agent-canister)
    - [13.6 Risk Guard Canister](#136-risk-guard-canister)
    - [13.7 Event Bus / PubSub Pattern (Optional)](#137-event-bus--pubsub-pattern-optional)
  - [14. AI / ML Components](#14-ai--ml-components)
    - [14.1 Levels of Intelligence (Progressive Disclosure)](#141-levels-of-intelligence-progressive-disclosure)
    - [14.2 Sentiment Scoring Baseline](#142-sentiment-scoring-baseline)
    - [14.3 Strategy Ranking Heuristic (MVP)](#143-strategy-ranking-heuristic-mvp)
    - [14.4 Explainability Hooks](#144-explainability-hooks)
  - [15. Security, Trust \& Compliance](#15-security-trust--compliance)
    - [15.1 Key Management](#151-key-management)
    - [15.2 Transaction Safety](#152-transaction-safety)
    - [15.3 Permissioning](#153-permissioning)
    - [15.4 Data Integrity](#154-data-integrity)
    - [15.5 Compliance Considerations (Deferred)](#155-compliance-considerations-deferred)
  - [16. Risk Management \& Failsafes](#16-risk-management--failsafes)
  - [17. Metrics \& KPIs](#17-metrics--kpis)
    - [17.1 Adoption Metrics](#171-adoption-metrics)
- [Connected wallets](#connected-wallets)
- [Active depositors](#active-depositors)
    - [17.2 Performance Metrics](#172-performance-metrics)
    - [17.3 Safety Metrics](#173-safety-metrics)
- [Risk Guard interventions triggered](#risk-guard-interventions-triggered)
    - [17.4 System Health](#174-system-health)
  - [18. Milestones \& Roadmap](#18-milestones--roadmap)
    - [18.1 Hackathon (T0 → Demo Day ~2 weeks example)](#181-hackathon-t0--demo-day-2-weeks-example)
    - [18.2 Post‑Hackathon Alpha (Month 1‑2)](#182-posthackathon-alpha-month-12)
    - [18.3 Beta (Month 3‑6)](#183-beta-month-36)
    - [18.4 GA (Month 6+)](#184-ga-month-6)
  - [19. Demo Script (Hackathon)](#19-demo-script-hackathon)
  - [20. Open Questions \& Assumptions](#20-open-questions--assumptions)
  - [21. Appendix](#21-appendix)
    - [21.1 Glossary](#211-glossary)
    - [21.2 Example Strategy Template JSON](#212-example-strategy-template-json)
    - [21.3 Protective Intent Enum](#213-protective-intent-enum)
    - [21.4 Sample Data Flow Timing Diagram (ASCII)](#214-sample-data-flow-timing-diagram-ascii)
    - [21.5 Regulatory Surface Notes (for later legal review)](#215-regulatory-surface-notes-for-later-legal-review)
    - [21.6 Hackathon Team Roles Template](#216-hackathon-team-roles-template)

---

## 1. Executive Summary

**BetterTrade** is a **Bitcoin DeFi copilot composed of specialized, cooperating on‑chain AI agents** deployed as **ICP canisters**. It automates yield strategies (lending, liquidity provision, hedged vaults, basis trades) across Bitcoin‑enabled protocols, while continuously ingesting **market data, on‑chain signals, and sentiment feeds** to adapt positions in near‑real time. A dedicated **Risk Guard** enforces user‑defined capital protections.

**Why now?** Bitcoin’s expansion into DeFi (via wrapped BTC, Layer‑2s, and native integrations) has created yield opportunities that remain opaque and operationally complex for most users. Simultaneously, the **Internet Computer’s Bitcoin integration + t‑ECDSA** enables trust‑minimized, programmatic Bitcoin transactions *without custodial bridges*. BetterTrade marries these innovations with **AI‑driven decisioning** to unlock smart, automated participation.

**Hackathon MVP Scope:** Deliver a **two‑agent vertical slice**: (1) **Strategy Selector** suggesting one of a few pre‑coded strategies; (2) **Execution Agent** that submits a Bitcoin transaction (mock or live testnet) using ICP’s Bitcoin API + threshold ECDSA signing. Minimal dashboard shows status, logs, and PnL simulation.

**Expansion Path:** Add Market Monitor, Sentiment, and Risk Guard agents; broaden supported strategies; expose SDK so external dApps can call agents as services.

---

## 2. Problem Statement

Bitcoin holders face three core frictions when trying to earn yield across emerging Bitcoin DeFi venues:

1. **Discovery Complexity:** Dozens of protocols (lending markets, yield vaults, RWA‑backed loans, liquidity pools on BTC L2s) with rapidly changing rates.
2. **Operational Overhead:** Moving BTC across layers, signing transactions, rebalancing collateral ratios, harvesting rewards.
3. **Risk Blindspots:** Volatility spikes, liquidity droughts, protocol hacks, custodial / bridge risk, liquidation thresholds.

As a result, most holders either remain idle (opportunity cost) or rely on centralized yield products (custodial risk, opaque fees).

**We need an autonomous, transparent, user‑governable system that actively manages Bitcoin DeFi positions for risk‑adjusted yield.**

---

## 3. Goals & Non‑Goals

### 3.1 Product Goals

| #  | Goal                                                                         | Success Signal                                                       |
| -- | ---------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| G1 | Make Bitcoin yield strategies **accessible & automated** for non‑experts.    | Users deposit BTC and opt into auto strategies within minutes.       |
| G2 | Demonstrate **multi‑agent orchestration on ICP** with real transaction flow. | Agents exchange intents via inter‑canister calls; audit log visible. |
| G3 | Provide **risk controls** users actually trust.                              | Users set max drawdown / stop loss; Risk Guard enforces.             |
| G4 | Deliver a **judge‑impressive hackathon demo**.                               | Smooth scripted walkthrough that shows real or simulated PnL delta.  |
| G5 | Enable **extensibility** so DAOs / wallets can integrate specific agents.    | Documented canister APIs + SDK example.                              |

### 3.2 Non‑Goals (Initial MVP)

- Fully generalized autonomous hedge fund.
- Integration with every Bitcoin L2 / sidechain at launch.
- Complex derivatives (perps, options) beyond illustrative hedging mock.
- Regulatory jurisdictional tailoring at MVP (tracked for later).

---

## 4. Target Users & Personas

| Persona                             | Description                                               | Pain Today                            | What They Want                                | Risk Appetite | Segment Priority        |
| ----------------------------------- | --------------------------------------------------------- | ------------------------------------- | --------------------------------------------- | ------------- | ----------------------- |
| **BTC Long‑Term Holder (Retail)**   | Self‑custody user holding idle BTC; basic DeFi curiosity. | Low / no yield; bridging risk fear.   | Simple “earn on my BTC” with safety bounds.   | Low‑Medium    | High (MVP)              |
| **Crypto Power User / DeFi Farmer** | Already chases yields across chains.                      | Fragmented tooling; manual mgmt; gas. | Automation + cross‑venue optimizer.           | Medium‑High   | Medium                  |
| **Treasury / DAO**                  | Holds BTC on balance sheet; risk committee.               | Idle capital; governance overhead.    | Programmatic mandates; reporting; guardrails. | Low           | Medium (post‑MVP pilot) |
| **Custodians / Wallet Apps**        | Provide BTC services to end users.                        | Need differentiated yield offering.   | Embedded agent module via API/license.        | Varies        | Medium (B2B)            |

---

## 5. Value Proposition by Persona

### BTC Retail Holder

- 3‑click BTC deposit → auto yield.
- Transparent risk sliders (conservative / balanced / aggressive).
- Withdraw anytime.

### DeFi Power User

- Advanced strategy editor (alloc % / leverage / rebal freq).
- Performance analytics vs HODL baseline.

### DAO / Treasury

- Policy‑driven mandates (min collateralization, whitelisted venues).
- Automated compliance alerts & downloadable reports.

### Wallet / Custodian Integrator

- Drop‑in SDK; co‑brand agent UI.
- Revenue share on yield fees.

---

## 6. Competitive Landscape & Differentiators

**Landscape Buckets:**

- Centralized BTC yield (exchanges, CeFi lenders) — opaque, custodial.
- Wrapped BTC DeFi (Ethereum, Solana, etc.) — bridge risk & UX friction.
- Vault aggregators (Yearn‑style) — mostly non‑Bitcoin native.
- Copy trading / social bots — off‑chain, trust gaps.

**BetterTrade Differentiators:**

1. **Bitcoin‑native execution via ICP Bitcoin API** (no trusted bridge).
2. **Multi‑agent AI orchestration** improving adaptability & transparency.
3. **User‑set hard risk guards enforced on‑chain**.
4. **Composable canister APIs** — agents as services embeddable in other dApps.
5. **Explainable strategy logs**: what changed, why, timestamped.

---

## 7. Use Cases & User Stories

### 7.1 Core MVP Stories

1. *As a BTC holder*, I connect my wallet, deposit testnet BTC, and select **Conservative Yield**. The Strategy Selector recommends lending to Protocol A; I approve; Execution Agent signs and submits tx.
2. *As a user*, I want to see current APY and my position value vs initial deposit.
3. *As a user*, I want to withdraw my BTC at any time.
4. *As a user*, I want to set a **max 10% drawdown stop**; if breached, system auto‑unwinds.

### 7.2 Extended Stories (Phase 2+)

5. Market Monitor detects better rate at Protocol B → Strategy Selector proposes rebalance; user auto‑approve rules; Execution executes.
6. Sentiment Agent flags negative news; Risk Guard tightens exposure band.
7. DAO admin uploads mandate JSON; system constrains strategies accordingly.
8. Power user scripts custom allocation and backtests against historical data.

### 7.3 Edge / Failure Stories

9. Bitcoin network fee spike: Execution Agent delays non‑urgent moves; notifies user.
10. Strategy contract fails: Risk Guard withdraws to cold address fallback.

---

## 8. User Experience Overview

### 8.1 High‑Level UX Flow (Retail MVP)

```
Landing → Connect Wallet → Deposit BTC → Pick Risk Profile → Review Strategy Recommendation → Approve → Monitor Dashboard → Alerts / Withdraw
```

### 8.2 Screens (MVP)

1. **Landing / Connect**: short value prop; connect supported wallet(s).
2. **Deposit & Risk Slider**: user chooses Conservative / Balanced / Aggressive; shows indicative APY band + risk notes.
3. **Strategy Recommendation Modal**: shows selected protocol, est APY, est fees, risk score; log link.
4. **Execution Status**: pending, confirmed block height, txid.
5. **Portfolio Dashboard**: balance, realized yield, PnL vs HODL, active strategies.
6. **Alerts Panel**: threshold breaches, pending rebalances, sentiment warnings.

### 8.3 Accessibility & Localization

- Mobile‑first responsive layout.
- Support dark/light modes.
- Localize number formats; user timezone aware (default Asia/Kolkata in demo; auto detect when prod).

---

## 9. System Overview & Multi‑Agent Architecture

BetterTrade is implemented as **cooperating ICP canisters** (one per agent class + shared registry/state) plus a frontend canister. Agents communicate via **inter‑canister calls** and may also perform **HTTP outcalls** for off‑chain data (rate feeds, sentiment, news). Bitcoin transactions are constructed and signed using **ICP’s Threshold ECDSA (t‑ECDSA)** and broadcast via the **Bitcoin API**.

### 9.1 Agent Roles

| Agent                     | Phase | Description                                                                                     | Key Inputs                                            | Key Outputs                               |
| ------------------------- | ----- | ----------------------------------------------------------------------------------------------- | ----------------------------------------------------- | ----------------------------------------- |
| **Strategy Selector**     | MVP   | Maps user risk profile + market data to a recommended strategy template.                        | Risk settings, market rates snapshot.                 | Strategy plan object; confidence score.   |
| **Execution Agent**       | MVP   | Builds, signs, and submits Bitcoin & protocol tx; tracks confirmations; updates position state. | Strategy plan; user approvals; t‑ECDSA key.           | Tx receipts; position states.             |
| **Market Monitor**        | P2    | Polls lending rates, liquidity, spreads across supported venues; normalizes data.               | HTTP outcalls; on‑chain reads.                        | Market snapshot events; anomalies.        |
| **Sentiment Agent**       | P2    | NLP + scoring on curated feeds (X, Reddit, CoinDesk, GitHub commits).                           | Text streams, news API.                               | Sentiment index; risk flags.              |
| **Risk Guard**            | P2    | Evaluates portfolio vs user guardrails + real‑time risk signals; can pause or unwind.           | Position state; sentiment; volatility; price oracles. | Action intents: pause, rebalance, unwind. |
| **Analytics / Reporting** | P3    | Historical PnL, tax lots, DAO reports.                                                          | Position history, price data.                         | CSV / API exports.                        |

### 9.2 Data + Control Flow

```
[External Data Feeds] ─▶ Market Monitor ─┐
                                       │
[Sentiment Feeds] ─▶ Sentiment Agent ──┤
                                       ▼
                                Strategy Selector
                                       │
                               Strategy Plan JSON
                                       ▼
                                Execution Agent ──▶ Bitcoin API / Protocol Calls
                                       ▼
                                    State Store
                                       ▼
                                    Risk Guard ──▶ protective actions
                                       ▼
                                  Frontend / Alerts
```

### 9.3 Deployment Topology

- **Frontend Canister**: UI + minimal state.
- **User Registry Canister**: account metadata, permissions, notification prefs.
- **Portfolio State Canister**: normalized holdings, tx history, strategy params.
- **Agent Canisters**: one per role (may be merged for MVP due to time).
- **Oracle / Data Cache Canister**: caches market & sentiment snapshots to reduce outcall costs.

---

## 10. Functional Requirements

Functional requirements are tagged by **Priority**: `MVP`, `P2` (post‑MVP, near‑term), `P3` (future / nice‑to‑have). Each also lists **Owner Agent(s)**.

### 10.1 Account & Wallet

**FR-A1 (MVP):** User can connect a supported Bitcoin wallet (testnet in hackathon) OR generate a managed t‑ECDSA subaccount controlled by BetterTrade canisters. **FR-A2 (MVP):** Display deposit address; detect inbound BTC deposit after N confirmations. **FR-A3 (MVP):** Map user principal to BTC UTXOs in state store. **FR-A4 (P2):** Support multiple wallets per user. **FR-A5 (P2):** Hardware wallet interaction / PSBT export.

### 10.2 Portfolio Dashboard

**FR-P1 (MVP):** Show total BTC deposited, current strategy, and est APY. **FR-P2 (MVP):** Show tx history (hash, date, status, amount). **FR-P3 (P2):** Show PnL vs HODL baseline since deposit. **FR-P4 (P2):** Chart historical allocations over time. **FR-P5 (P3):** Downloadable CSV.

### 10.3 Strategy Selector Agent

**FR-S1 (MVP):** Accept user risk profile → return recommended strategy from predefined catalog (Conservative Lending, Balanced LP, Aggressive Yield Farming Simulated). **FR-S2 (MVP):** Provide human‑readable explanation of recommendation. **FR-S3 (MVP):** Provide est APY band and risk score (static heuristics in MVP; dynamic later). **FR-S4 (P2):** Incorporate live market rates (via Market Monitor) into recommendation ranking. **FR-S5 (P2):** Support user overrides: choose manual strategy. **FR-S6 (P3):** Reinforcement learning policy tuning from historical performance.

### 10.4 Execution Agent

**FR-E1 (MVP):** Accept Strategy Plan JSON; construct required Bitcoin tx (e.g., send to lending protocol gateway address or ICP wrapper canister). **FR-E2 (MVP):** Use t‑ECDSA to sign transaction; broadcast via ICP Bitcoin API. **FR-E3 (MVP):** Track confirmations; update Portfolio State. **FR-E4 (MVP):** Surface txid + status in UI. **FR-E5 (P2):** Batch multiple user tx to reduce fees. **FR-E6 (P2):** Gas/fee estimation + user max fee setting. **FR-E7 (P3):** Multi‑venue atomic rebalances (time‑boxed best effort).

### 10.5 Sentiment Agent (Phase 2)

**FR-SE1:** Pull curated RSS/news feeds; basic NLP polarity scoring. **FR-SE2:** Track BTC keyword velocity spikes (social chatter). **FR-SE3:** Publish rolling Sentiment Index [-1, +1]. **FR-SE4:** Threshold crossing → Risk Guard advisory.

### 10.6 Market Monitor Agent

**FR-MM1 (P2):** Poll supported protocols’ public APIs for lending rates, TVL, liquidity depth. **FR-MM2 (P2):** Normalize APR/fee units; cache snapshots. **FR-MM3 (P2):** Detect rate deltas > configurable %; alert Strategy Selector. **FR-MM4 (P3):** Support on‑chain price / oracle aggregation.

### 10.7 Risk Guard Agent

**FR-RG1 (P2):** Users set max % drawdown; monitor vs market price. **FR-RG2 (P2):** Users set liquidity exit threshold (e.g., withdraw if pool depth < X BTC). **FR-RG3 (P2):** On trigger, generate **Protective Intent** (pause / unwind) → Execution Agent. **FR-RG4 (P3):** Multi‑factor VaR style risk scoring.

### 10.8 Notifications & Alerts

**FR-N1 (MVP):** In‑app toast + log entries for tx events. **FR-N2 (P2):** Email / push / webhook notifications (UTC + user‑local timestamp; e.g., Asia/Kolkata default demo timezone). **FR-N3 (P3):** Slack/Discord bot integration.

### 10.9 Governance & Parameters

**FR-G1 (P2):** Admin panel to add/edit strategy templates. **FR-G2 (P2):** Whitelist / blacklist protocols. **FR-G3 (P3):** Token‑weighted community voting (DAO path).

---

## 11. Non‑Functional Requirements

| Category                     | Requirement                                                                | Target / Notes                                        | Priority |
| ---------------------------- | -------------------------------------------------------------------------- | ----------------------------------------------------- | -------- |
| **Performance**              | Strategy recommendation latency                                            | < 2s for cached rates; < 10s when pulling fresh data. | MVP      |
| **Tx Confirmation Tracking** | Detect Bitcoin confirmation updates within 1 block of finality poll.       | MVP                                                   |          |
| **Scalability**              | Support 10K light users (read‑heavy) and 1K active depositors in demo env. | P2                                                    |          |
| **Reliability**              | Core agents must recover from canister upgrade without state loss.         | MVP                                                   |          |
| **Observability**            | Structured logs with timestamp, agent, action, txid.                       | MVP                                                   |          |
| **Security**                 | t‑ECDSA keys never leave ICP; role‑scoped signing.                         | MVP                                                   |          |
| **Privacy**                  | Map user principals pseudonymously; avoid plaintext emails on‑chain.       | P2                                                    |          |
| **Compliance**               | Exportable transaction history for tax/reg reporting.                      | P3                                                    |          |

---

## 12. Data Model

Below is the conceptual data model; implementation may shard across canisters.

### 12.1 Entities

- **User**: {principal\_id, display\_name, notification\_prefs, KYC\_hash?}
- **Wallet**: {user\_id, btc\_address, network (mainnet/testnet), status}
- **DepositUTXO**: {wallet\_id, txid, vout, amount\_sats, confirmations}
- **StrategyTemplate**: {id, name, risk\_level, venues[], est\_apy\_band, params\_schema}
- **StrategyPlan**: {id, user\_id, template\_id, allocs[], created\_at, status}
- **Position**: {user\_id, venue\_id, amount\_sats, entry\_price, current\_value, pnl}
- **RiskGuardConfig**: {user\_id, max\_drawdown\_pct, liq\_exit\_threshold, notify\_only?}
- **SentimentSnapshot**: {timestamp, score, source\_breakdown}
- **MarketSnapshot**: {timestamp, venue\_id, rate, tvl, liquidity, fees}
- **TxRecord**: {txid, user\_id, type, amount\_sats, fee\_sats, status, confirmed\_height}

### 12.2 Relationships

- User 1‑N Wallet
- User 1‑N StrategyPlan (active=1 for MVP)
- StrategyPlan 1‑N Position
- MarketSnapshot N‑1 Venue

### 12.3 Storage Considerations

- Hot state (current positions) in stable memory for fast reads.
- Historical time‑series chunked & compressed in archival canisters or off‑chain bucket w/ hash commit.

---

## 13. Smart Contract / Canister Interfaces

*Notation:* Motoko/Rust pseudo‑IDL.

### 13.1 User Registry Canister

```motoko
// Register new user
public shared(msg) func register(display_name : Text, email_opt : ?Text) : async UserId;

// Link BTC wallet
public shared(msg) func link_wallet(addr : Text, network : {#mainnet; #testnet}) : async WalletId;

// Get user summary
public query func get_user(uid : UserId) : async UserSummary;
```

### 13.2 Strategy Selector Canister

```motoko
public query func list_strategies() : async [StrategyTemplate];

public shared(msg) func recommend(uid : UserId, risk : RiskLevel) : async StrategyPlan; // returns plan + rationale

public shared(msg) func accept_plan(uid : UserId, plan_id : PlanId) : async Bool; // locks plan & emits event
```

### 13.3 Execution Agent Canister

```motoko
// Called after user accepts plan
public shared(msg) func execute_plan(plan_id : PlanId) : async [TxId];

// Internal: construct + sign Bitcoin tx
private func build_and_sign_tx(...) : TxRaw;

// Query tx status
public query func get_tx_status(txid : TxId) : async TxStatus;
```

### 13.4 Market Monitor Canister

```motoko
public shared(msg) func refresh_rates() : async MarketSnapshotId; // triggers HTTP outcalls
public query func latest_rates() : async [MarketRate];
```

### 13.5 Sentiment Agent Canister

```motoko
public shared(msg) func refresh_sentiment() : async SentimentSnapshotId;
public query func latest_sentiment() : async SentimentScore;
```

### 13.6 Risk Guard Canister

```motoko
public shared(msg) func set_guard(uid : UserId, cfg : RiskGuardConfig) : async Bool;
public query func get_guard(uid : UserId) : async ?RiskGuardConfig;
// Called on timer or data event
private func evaluate(uid : UserId) : async [ProtectiveIntent];
```

### 13.7 Event Bus / PubSub Pattern (Optional)

Emit typed events between canisters; consumers subscribe by callback or polling.

---

## 14. AI / ML Components

### 14.1 Levels of Intelligence (Progressive Disclosure)

| Level | Description                                                 | Implementation State |
| ----- | ----------------------------------------------------------- | -------------------- |
| L0    | Static rules / hardcoded strategies.                        | MVP.                 |
| L1    | Heuristic scoring from live market data.                    | P2.                  |
| L2    | Lightweight ML regression (rate forecasting, volatility).   | P2/P3.               |
| L3    | Multi‑agent reinforcement learning; simulation environment. | Future.              |

### 14.2 Sentiment Scoring Baseline

- Tokenize text; dictionary of bullish/bearish terms.
- Weighted sources (news > Reddit > X noise).
- Time‑decay scoring window (e.g., 6h half‑life).

### 14.3 Strategy Ranking Heuristic (MVP)

```
score = w1 * normalized_rate + w2 * (1 - risk_factor) + w3 * liquidity_score
```

Where weights tied to user risk slider.

### 14.4 Explainability Hooks

Each recommendation returns: input snapshot hash, top 3 scoring factors, human summary string.

---

## 15. Security, Trust & Compliance

### 15.1 Key Management

- Use ICP **t‑ECDSA** for Bitcoin signing; no single private key.
- Scoped keys: user‑level vs system treasury.

### 15.2 Transaction Safety

- Preflight simulation: validate outputs, fee rate, change address.
- Anti‑replay / sequence tracking.

### 15.3 Permissioning

- User approval required before first strategy execution (MVP interactive consent).
- Future: policy delegation (auto‑approve under conditions).

### 15.4 Data Integrity

- Hash logs of market data snapshots; anchor to ICP ledger for auditability.

### 15.5 Compliance Considerations (Deferred)

- Optional KYC attestation hash for regulated users.
- Exportable tax lot CSV.

---

## 16. Risk Management & Failsafes

| Risk                                 | Mitigation                                                       | Owner             |
| ------------------------------------ | ---------------------------------------------------------------- | ----------------- |
| Extreme BTC volatility → liquidation | User max drawdown + Risk Guard auto unwind.                      | Risk Guard        |
| Protocol exploit                     | Whitelist vetted venues; sentiment/news alerts; multi‑sig pause. | Admin + Sentiment |
| Fee spikes                           | Execution batches; user fee ceilings; delayed non‑critical tx.   | Execution         |
| Data feed outage                     | Use cached snapshot + degrade gracefully; mark as stale.         | Market Monitor    |
| Smart contract bug                   | Upgradeable canisters w/ state migration + bug bounty.           | Eng               |

---

## 17. Metrics & KPIs

### 17.1 Adoption Metrics

-

# Connected wallets

-

# Active depositors

- Total BTC under management (TBUM)

### 17.2 Performance Metrics

- Net APY vs benchmark (HODL, CeFi yield avg)
- % time funds deployed vs idle
- Slippage / fee efficiency vs manual routes

### 17.3 Safety Metrics

-

# Risk Guard interventions triggered

- Max realized drawdown per user vs configured threshold
- Time to alert (seconds) after breach condition

### 17.4 System Health

- Agent uptime %
- Avg inter‑canister call latency
- Failed tx rate

---

## 18. Milestones & Roadmap

### 18.1 Hackathon (T0 → Demo Day \~2 weeks example)

**M0 (Day 0‑2):** Repo scaffold; canister templates; BTC testnet plumbing.\
**M1 (Day 3‑5):** Strategy Selector (static templates) + UI risk slider.\
**M2 (Day 6‑8):** Execution Agent signing & broadcast to BTC testnet; tx status.\
**M3 (Day 9‑10):** Minimal dashboard (balances, tx log).\
**M4 (Day 11‑12):** Risk Guard stub (manual trigger).\
**M5 (Day 13‑14):** Demo polish, script, video.

### 18.2 Post‑Hackathon Alpha (Month 1‑2)

- Live Market Monitor integration (top 1‑2 venues).
- Basic Sentiment index from news feeds.
- User configurable drawdown.

### 18.3 Beta (Month 3‑6)

- Multi‑venue allocations.
- Auto rebalance.
- Email/push notifications.
- DAO / treasury pilot.

### 18.4 GA (Month 6+)

- Security audit.
- Mainnet BTC support w/ real funds (jurisdictional gating).
- Governance token optional.

---

## 19. Demo Script (Hackathon)

**Goal:** In <5 minutes show end‑to‑end autonomous BTC strategy execution + transparency + risk guard.

**Narrative Beats:**

1. *Problem slide:* Idle BTC; DeFi complexity.
2. *Solution slide:* Multi‑agent AI on ICP (diagram).
3. *Live demo:* Connect wallet → deposit → choose risk profile.
4. Strategy Selector recommends Conservative Lending; explanation popover shows scoring factors.
5. Approve & Execute → show signed BTC testnet txid; block confirmation countdown.
6. Dashboard updates allocated amount & est APY.
7. Trigger simulated rate drop; Strategy Selector proposes move; show user auto‑approval rule.
8. Trip drawdown guard; system auto unwinds to safe address.
9. Close with metrics + extensibility (agents as a service).

---

## 20. Open Questions & Assumptions

- Which Bitcoin DeFi venues will be demo‑integrated? (Need API stability + permissive ToS.)
- Is hackathon judging environment online mainnet or local sandbox? (Affects signing cost.)
- Will we support only testnet BTC or synthetic mock UTXOs for faster demo resets?
- Legal posture for user deposits during hackathon — demo funds only? capped? insured?
- Source of price oracle (CoinGecko, Chainlink, custom aggregator)?
- Latency & cost limits for HTTP outcalls on ICP during event.

---

## 21. Appendix

### 21.1 Glossary

- **ICP**: Internet Computer Protocol, a decentralized compute platform supporting canisters (smart contracts) with native Bitcoin integration.
- **t‑ECDSA**: Threshold ECDSA; distributed signing where no single node holds the full private key.
- **UTXO**: Unspent Transaction Output — Bitcoin accounting model primitive.
- **APY**: Annual Percentage Yield; standardized compounding return metric.
- **Drawdown**: Peak‑to‑trough % decline in portfolio value.

### 21.2 Example Strategy Template JSON

```json
{
  "id": "conservative_lend_v1",
  "name": "Conservative Lending",
  "risk_level": "low",
  "venues": ["btc_lend_protocol_a"],
  "target_allocation_pct": 1.0,
  "min_lock_days": 0,
  "est_apy_band": [0.02, 0.04],
  "liquidity_score": 0.9,
  "params": {
    "auto_compound": true,
    "rebalance_trigger_delta_pct": 10
  }
}
```

### 21.3 Protective Intent Enum

```rust
enum ProtectiveIntent {
  Pause,            // stop new deployments
  UnwindPartial(f32), // withdraw %
  UnwindFull,       // withdraw all funds to user safe addr
  RaiseCollateral(f32),
  NotifyOnly,
}
```

### 21.4 Sample Data Flow Timing Diagram (ASCII)

```
User ─┬─▶ Strategy Selector (risk input)
     │        │
     │        ├─query Market Monitor snapshot
     │        └─return plan + rationale
     │
     ├─Approve───────────────────────▶ Execution Agent
     │                                 │
     │                                 ├─t‑ECDSA sign tx
     │                                 ├─broadcast BTC
     │                                 └─update Portfolio State
     │
     └─Dashboard polls / receives events
```

### 21.5 Regulatory Surface Notes (for later legal review)

- If non‑custodial & user keys sign all moves → lower custody burden.
- If pooled funds / auto re‑allocation without per‑tx user signature → may trigger fund management classification in some jurisdictions.

### 21.6 Hackathon Team Roles Template

| Role            | Name | Responsibilities                      |
| --------------- | ---- | ------------------------------------- |
| PM / Pitch Lead | TBD  | PRD, slides, demo script              |
| Protocol Eng    | TBD  | t‑ECDSA, BTC calls                    |
| AI Eng          | TBD  | Strategy scoring, sentiment prototype |
| Frontend        | TBD  | UI, dashboard, wallet connect         |
| DevOps          | TBD  | Deploy canisters, test harness        |

---

**End of PRD**
