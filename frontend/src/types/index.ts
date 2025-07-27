// Frontend type definitions that mirror the Motoko types

export type UserId = string;
export type WalletId = string;
export type PlanId = string;
export type TxId = string;

export enum RiskLevel {
  Conservative = 'conservative',
  Balanced = 'balanced',
  Aggressive = 'aggressive'
}

export enum Network {
  Mainnet = 'mainnet',
  Testnet = 'testnet'
}

export enum WalletStatus {
  Active = 'active',
  Inactive = 'inactive'
}

export interface User {
  principal_id: string;
  display_name: string;
  created_at: number;
  risk_profile: RiskLevel;
}

export interface Wallet {
  user_id: UserId;
  btc_address: string;
  network: Network;
  status: WalletStatus;
}

export interface StrategyTemplate {
  id: string;
  name: string;
  risk_level: RiskLevel;
  venues: string[];
  est_apy_band: [number, number];
  params_schema: string;
}

export enum PlanStatus {
  Pending = 'pending',
  Approved = 'approved',
  Executed = 'executed',
  Failed = 'failed'
}

export interface Allocation {
  venue_id: string;
  amount_sats: bigint;
  percentage: number;
}

export interface StrategyPlan {
  id: PlanId;
  user_id: UserId;
  template_id: string;
  allocations: Allocation[];
  created_at: number;
  status: PlanStatus;
  rationale: string;
}

export interface Position {
  user_id: UserId;
  venue_id: string;
  amount_sats: bigint;
  entry_price: number;
  current_value: number;
  pnl: number;
}

export interface PortfolioSummary {
  user_id: UserId;
  total_balance_sats: bigint;
  total_value_usd: number;
  positions: Position[];
  pnl_24h: number;
  active_strategy?: string;
}

export enum TxType {
  Deposit = 'deposit',
  Withdraw = 'withdraw',
  StrategyExecute = 'strategy_execute',
  Rebalance = 'rebalance'
}

export enum TxStatus {
  Pending = 'pending',
  Confirmed = 'confirmed',
  Failed = 'failed'
}

export interface TxRecord {
  txid: string;
  user_id: UserId;
  tx_type: TxType;
  amount_sats: bigint;
  fee_sats: bigint;
  status: TxStatus;
  confirmed_height?: number;
  timestamp: number;
}

export interface RiskGuardConfig {
  user_id: UserId;
  max_drawdown_pct: number;
  liquidity_exit_threshold: bigint;
  notify_only: boolean;
}

export enum ProtectiveAction {
  Pause = 'pause',
  Unwind = 'unwind',
  ReduceExposure = 'reduce_exposure'
}

export interface ProtectiveIntent {
  user_id: UserId;
  action: ProtectiveAction;
  reason: string;
  triggered_at: number;
}

export interface UserSummary {
  user_id: UserId;
  display_name: string;
  risk_profile: RiskLevel;
  wallet_count: number;
  portfolio_value_sats: bigint;
}

export enum ApiErrorType {
  NotFound = 'not_found',
  Unauthorized = 'unauthorized',
  InvalidInput = 'invalid_input',
  InternalError = 'internal_error'
}

export interface ApiError {
  type: ApiErrorType;
  message?: string;
}

export type ApiResult<T> = {
  ok: T;
} | {
  err: ApiError;
};

// Re-export notification types
export * from './notifications';