// Mock implementation of AgentService for testing

export const agentService = {
  // User Registry methods
  register: jest.fn(),
  linkWallet: jest.fn(),
  getUser: jest.fn(),
  setRiskProfile: jest.fn(),
  getUserWallets: jest.fn(),

  // Portfolio State methods
  updateBalance: jest.fn(),
  getPortfolio: jest.fn(),
  recordTransaction: jest.fn(),
  getTransactionHistory: jest.fn(),
  updatePosition: jest.fn(),

  // Strategy Selector methods
  listStrategies: jest.fn(),
  recommend: jest.fn(),
  acceptPlan: jest.fn(),
  getPlan: jest.fn(),

  // Execution Agent methods
  executePlan: jest.fn(),
  getTxStatus: jest.fn(),
  cancelExecution: jest.fn(),

  // Risk Guard methods
  setGuard: jest.fn(),
  getGuard: jest.fn(),
  evaluatePortfolio: jest.fn(),
  triggerProtection: jest.fn(),
};