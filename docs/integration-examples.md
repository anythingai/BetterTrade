# BetterTrade Integration Examples

## Overview

This document provides practical examples for integrating with BetterTrade canisters. Whether you're building a frontend application, backend service, or mobile app, these examples will help you get started quickly.

---

## Frontend Integration

### React.js Setup

```typescript
// src/config/canisters.ts
import { Actor, HttpAgent } from '@dfinity/agent';
import { AuthClient } from '@dfinity/auth-client';

export class BitSightClient {
  private agent: HttpAgent;
  private authClient: AuthClient;
  public actors: any;

  constructor() {
    this.agent = new HttpAgent({
      host: process.env.REACT_APP_IC_HOST || 'http://127.0.0.1:4943'
    });

    if (process.env.NODE_ENV === 'development') {
      this.agent.fetchRootKey();
    }

    this.initializeActors();
  }

  private initializeActors() {
    // Initialize canister actors
    // this.actors = { userRegistry, portfolioState, ... };
  }

  async authenticate(): Promise<boolean> {
    this.authClient = await AuthClient.create();
    
    return new Promise((resolve) => {
      this.authClient.login({
        identityProvider: process.env.REACT_APP_II_URL,
        onSuccess: () => {
          const identity = this.authClient.getIdentity();
          this.agent.replaceIdentity(identity);
          this.initializeActors();
          resolve(true);
        },
        onError: () => resolve(false),
      });
    });
  }
}
```

### Portfolio Component

```typescript
// src/components/Portfolio.tsx
import React, { useState, useEffect } from 'react';
import { useAuth } from '../hooks/useAuth';

export const Portfolio: React.FC = () => {
  const { client, user } = useAuth();
  const [portfolio, setPortfolio] = useState(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (user) {
      loadPortfolio();
    }
  }, [user]);

  const loadPortfolio = async () => {
    setLoading(true);
    try {
      const result = await client.actors.portfolioState.get_portfolio(user.principal);
      if ('ok' in result) {
        setPortfolio(result.ok);
      }
    } catch (error) {
      console.error('Failed to load portfolio:', error);
    } finally {
      setLoading(false);
    }
  };

  const formatBTC = (sats: bigint): string => {
    return (Number(sats) / 100000000).toFixed(8) + ' BTC';
  };

  if (loading) return <div>Loading...</div>;

  return (
    <div className="portfolio">
      <h2>Portfolio Dashboard</h2>
      {portfolio && (
        <div className="balance-summary">
          <div className="balance-card">
            <h3>Total Balance</h3>
            <p>{formatBTC(portfolio.total_balance_sats)}</p>
          </div>
          <div className="balance-card">
            <h3>Available</h3>
            <p>{formatBTC(portfolio.available_balance_sats)}</p>
          </div>
          <div className="balance-card">
            <h3>P&L</h3>
            <p className={Number(portfolio.total_pnl_sats) >= 0 ? 'positive' : 'negative'}>
              {formatBTC(portfolio.total_pnl_sats)}
            </p>
          </div>
        </div>
      )}
    </div>
  );
};
```

---

## Backend Integration

### Node.js Express Server

```typescript
// src/server.ts
import express from 'express';
import { Actor, HttpAgent } from '@dfinity/agent';
import { Principal } from '@dfinity/principal';

const app = express();
app.use(express.json());

const agent = new HttpAgent({
  host: process.env.IC_HOST || 'http://127.0.0.1:4943'
});

if (process.env.NODE_ENV === 'development') {
  agent.fetchRootKey();
}

// Initialize canister actors
const userRegistry = Actor.createActor(userRegistryIdl, {
  agent,
  canisterId: userRegistryCanisterId,
});

app.get('/api/portfolio/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const userPrincipal = Principal.fromText(userId);

    const userResult = await userRegistry.get_user(userPrincipal);
    if ('err' in userResult) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ user: userResult.ok });
  } catch (error) {
    console.error('Portfolio API error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.listen(3001, () => {
  console.log('BetterTrade API server running on port 3001');
});
```

### Python Flask Integration

```python
# app.py
from flask import Flask, request, jsonify
from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent

app = Flask(__name__)

# Initialize IC client
client = Client(url="http://127.0.0.1:4943")
identity = Identity()
agent = Agent(identity, client)

class BitSightClient:
    def __init__(self):
        self.user_registry = agent.get_canister("rdmx6-jaaaa-aaaah-qdrya-cai")
        self.portfolio_state = agent.get_canister("rrkah-fqaaa-aaaah-qdrya-cai")
    
    async def get_user_portfolio(self, user_id: str):
        try:
            user_result = await self.user_registry.call("get_user", user_id)
            if "err" in user_result:
                return None, user_result["err"]
            
            portfolio_result = await self.portfolio_state.call("get_portfolio", user_id)
            if "err" in portfolio_result:
                return None, portfolio_result["err"]
            
            return {
                "user": user_result["ok"],
                "portfolio": portfolio_result["ok"]
            }, None
            
        except Exception as e:
            return None, str(e)

bitsight = BitSightClient()

@app.route('/api/portfolio/<user_id>', methods=['GET'])
async def get_portfolio(user_id):
    try:
        portfolio_data, error = await bitsight.get_user_portfolio(user_id)
        
        if error:
            return jsonify({"error": error}), 404 if "not_found" in error else 500
        
        return jsonify(portfolio_data)
        
    except Exception as e:
        return jsonify({"error": "Internal server error"}), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
```

---

## Mobile Integration

### React Native Service

```typescript
// src/services/BitSightService.ts
import { Actor, HttpAgent } from '@dfinity/agent';
import { AuthClient } from '@dfinity/auth-client';
import AsyncStorage from '@react-native-async-storage/async-storage';

export class BitSightMobileService {
  private agent: HttpAgent;
  private authClient: AuthClient | null = null;
  private actors: any = {};

  constructor() {
    this.agent = new HttpAgent({
      host: 'https://ic0.app'
    });
  }

  async initialize(): Promise<void> {
    this.authClient = await AuthClient.create({
      storage: {
        get: async (key: string) => await AsyncStorage.getItem(key),
        set: async (key: string, value: string) => await AsyncStorage.setItem(key, value),
        remove: async (key: string) => await AsyncStorage.removeItem(key)
      }
    });

    if (this.authClient.isAuthenticated()) {
      const identity = this.authClient.getIdentity();
      this.agent.replaceIdentity(identity);
      await this.initializeActors();
    }
  }

  async login(): Promise<boolean> {
    if (!this.authClient) {
      throw new Error('Service not initialized');
    }

    return new Promise((resolve) => {
      this.authClient!.login({
        identityProvider: 'https://identity.ic0.app',
        onSuccess: async () => {
          const identity = this.authClient!.getIdentity();
          this.agent.replaceIdentity(identity);
          await this.initializeActors();
          resolve(true);
        },
        onError: () => resolve(false)
      });
    });
  }

  async getPortfolio(): Promise<any> {
    if (!this.isAuthenticated()) {
      throw new Error('Not authenticated');
    }

    const identity = this.authClient!.getIdentity();
    const principal = identity.getPrincipal();

    const result = await this.actors.portfolioState.get_portfolio(principal);
    
    if ('ok' in result) {
      return result.ok;
    } else {
      throw new Error(result.err);
    }
  }

  isAuthenticated(): boolean {
    return this.authClient?.isAuthenticated() || false;
  }

  private async initializeActors(): Promise<void> {
    // Initialize canister actors
  }
}

export const bitSightService = new BitSightMobileService();
```

---

## WebSocket Integration

### Real-time Updates

```typescript
// src/services/WebSocketService.ts
export class BitSightWebSocketService {
  private ws: WebSocket | null = null;
  private listeners: Map<string, Function[]> = new Map();

  constructor(private wsUrl: string) {}

  connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(this.wsUrl);

      this.ws.onopen = () => {
        console.log('WebSocket connected');
        resolve();
      };

      this.ws.onmessage = (event) => {
        const data = JSON.parse(event.data);
        this.handleMessage(data);
      };

      this.ws.onerror = reject;
    });
  }

  private handleMessage(data: any): void {
    const { type, payload } = data;
    const listeners = this.listeners.get(type) || [];
    
    listeners.forEach(listener => listener(payload));
  }

  subscribe(eventType: string, callback: Function): () => void {
    if (!this.listeners.has(eventType)) {
      this.listeners.set(eventType, []);
    }
    
    this.listeners.get(eventType)!.push(callback);

    this.send({
      type: 'subscribe',
      eventType: eventType
    });

    return () => {
      const listeners = this.listeners.get(eventType) || [];
      const index = listeners.indexOf(callback);
      if (index > -1) {
        listeners.splice(index, 1);
      }
    };
  }

  private send(data: any): void {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(data));
    }
  }
}

// Usage
const wsService = new BitSightWebSocketService('wss://api.bitsight-plus-plus.com/ws');

wsService.subscribe('portfolio_update', (data) => {
  console.log('Portfolio updated:', data);
});

wsService.subscribe('transaction_confirmed', (data) => {
  console.log('Transaction confirmed:', data);
});
```

---

## Error Handling

### Comprehensive Error Management

```typescript
// src/utils/errorHandling.ts
export enum BitSightErrorType {
  NETWORK_ERROR = 'NETWORK_ERROR',
  AUTHENTICATION_ERROR = 'AUTHENTICATION_ERROR',
  VALIDATION_ERROR = 'VALIDATION_ERROR',
  CANISTER_ERROR = 'CANISTER_ERROR',
  UNKNOWN_ERROR = 'UNKNOWN_ERROR'
}

export class BitSightError extends Error {
  constructor(
    public type: BitSightErrorType,
    message: string,
    public originalError?: any,
    public canRetry: boolean = false
  ) {
    super(message);
    this.name = 'BitSightError';
  }
}

export function handleCanisterError(error: any): BitSightError {
  if (typeof error === 'object' && error !== null) {
    if ('not_found' in error) {
      return new BitSightError(
        BitSightErrorType.VALIDATION_ERROR,
        'Resource not found',
        error,
        false
      );
    }
    
    if ('unauthorized' in error) {
      return new BitSightError(
        BitSightErrorType.AUTHENTICATION_ERROR,
        'Unauthorized access',
        error,
        false
      );
    }
    
    if ('invalid_input' in error) {
      return new BitSightError(
        BitSightErrorType.VALIDATION_ERROR,
        error.invalid_input,
        error,
        false
      );
    }
    
    if ('internal_error' in error) {
      return new BitSightError(
        BitSightErrorType.CANISTER_ERROR,
        error.internal_error,
        error,
        true
      );
    }
  }
  
  return new BitSightError(
    BitSightErrorType.UNKNOWN_ERROR,
    'An unknown error occurred',
    error,
    true
  );
}

export async function withRetry<T>(
  operation: () => Promise<T>,
  maxRetries: number = 3,
  delay: number = 1000
): Promise<T> {
  let lastError: Error;
  
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error as Error;
      
      if (error instanceof BitSightError && !error.canRetry) {
        throw error;
      }
      
      if (attempt === maxRetries) {
        break;
      }
      
      await new Promise(resolve => setTimeout(resolve, delay * attempt));
    }
  }
  
  throw lastError!;
}
```

---

## Testing

### Jest Testing Examples

```typescript
// src/__tests__/BitSightService.test.ts
import { BitSightClient } from '../config/canisters';
import { Principal } from '@dfinity/principal';

jest.mock('@dfinity/agent');
jest.mock('@dfinity/auth-client');

describe('BitSightClient', () => {
  let client: BitSightClient;
  let mockUserRegistry: any;

  beforeEach(() => {
    mockUserRegistry = {
      get_user: jest.fn(),
      register: jest.fn(),
    };

    client = new BitSightClient();
    client.actors = { userRegistry: mockUserRegistry };
  });

  it('should fetch user successfully', async () => {
    const mockUserId = Principal.fromText('rdmx6-jaaaa-aaaah-qdrya-cai');
    const mockUser = {
      user_id: mockUserId,
      display_name: 'Test User',
      risk_profile: { conservative: null }
    };

    mockUserRegistry.get_user.mockResolvedValue({ ok: mockUser });

    const result = await client.actors.userRegistry.get_user(mockUserId);

    expect(result).toEqual({ ok: mockUser });
    expect(mockUserRegistry.get_user).toHaveBeenCalledWith(mockUserId);
  });

  it('should handle user fetch errors', async () => {
    const mockUserId = Principal.fromText('rdmx6-jaaaa-aaaah-qdrya-cai');
    
    mockUserRegistry.get_user.mockResolvedValue({
      err: { not_found: null }
    });

    const result = await client.actors.userRegistry.get_user(mockUserId);

    expect(result).toEqual({ err: { not_found: null } });
  });
});
```

---

This integration guide provides practical examples for building applications with BetterTrade. For more specific use cases, refer to the full API documentation.