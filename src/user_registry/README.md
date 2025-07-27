# User Registry Canister

The User Registry canister manages user accounts, wallet associations, and user preferences for the BetterTrade system. It serves as the central identity and profile management service for all users.

## Features

### Core Functionality

- **User Registration**: Register new users with principal ID mapping
- **Wallet Management**: Link Bitcoin addresses (testnet and mainnet) to user accounts
- **Risk Profile Management**: Set and retrieve user risk preferences
- **User Queries**: Lookup user information and summaries
- **Wallet Status Management**: Activate/deactivate linked wallets
- **System Administration**: Query system statistics and user lists

### Security Features

- **Principal-based Authentication**: Uses ICP principal IDs for user identification
- **Ownership Validation**: Users can only modify their own profiles and wallets
- **Input Validation**: Validates Bitcoin addresses and user input
- **Error Handling**: Comprehensive error responses with appropriate error types

## API Reference

### User Management

#### `register(display_name: Text, email_opt: ?Text) -> Result<UserId, ApiError>`
Registers a new user with the system.

**Parameters:**
- `display_name`: User's display name (1-50 characters)
- `email_opt`: Optional email address

**Returns:** User ID (Principal) on success

**Errors:**
- `invalid_input`: Invalid display name or user already exists
- `internal_error`: System error

#### `get_user(uid: UserId) -> Result<UserSummary, ApiError>`
Retrieves user summary information.

**Parameters:**
- `uid`: User ID (Principal)

**Returns:** UserSummary containing display name, risk profile, and wallet count

**Errors:**
- `not_found`: User does not exist

#### `set_risk_profile(uid: UserId, profile: RiskLevel) -> Result<Bool, ApiError>`
Updates user's risk profile preference.

**Parameters:**
- `uid`: User ID (Principal)
- `profile`: Risk level (#conservative, #balanced, #aggressive)

**Returns:** Boolean success indicator

**Errors:**
- `unauthorized`: User can only update their own profile
- `not_found`: User does not exist

### Wallet Management

#### `link_wallet(addr: Text, network: Network) -> Result<WalletId, ApiError>`
Links a Bitcoin address to the caller's account.

**Parameters:**
- `addr`: Bitcoin address
- `network`: Network type (#testnet or #mainnet)

**Returns:** Wallet ID on success

**Errors:**
- `not_found`: User not registered
- `invalid_input`: Invalid Bitcoin address or wallet already linked

#### `get_user_wallets(uid: UserId) -> Result<[Wallet], ApiError>`
Retrieves all wallets associated with a user.

**Parameters:**
- `uid`: User ID (Principal)

**Returns:** Array of Wallet objects

**Errors:**
- `not_found`: User does not exist

#### `update_wallet_status(wallet_id: WalletId, status: WalletStatus) -> Result<Bool, ApiError>`
Updates the status of a wallet.

**Parameters:**
- `wallet_id`: Wallet identifier
- `status`: New status (#active or #inactive)

**Returns:** Boolean success indicator

**Errors:**
- `unauthorized`: Only wallet owner can update status
- `not_found`: Wallet does not exist

#### `get_wallet(wallet_id: WalletId) -> Result<Wallet, ApiError>`
Retrieves wallet information by ID.

**Parameters:**
- `wallet_id`: Wallet identifier

**Returns:** Wallet object

**Errors:**
- `not_found`: Wallet does not exist

### System Administration

#### `get_all_users() -> Result<[UserSummary], ApiError>`
Retrieves summaries of all registered users.

**Returns:** Array of UserSummary objects

#### `get_system_stats() -> {user_count: Nat; wallet_count: Nat; active_wallet_count: Nat}`
Retrieves system statistics.

**Returns:** Object containing user and wallet counts

## Data Types

### User
```motoko
type User = {
    principal_id: Principal;
    display_name: Text;
    created_at: Time.Time;
    risk_profile: RiskLevel;
};
```

### Wallet
```motoko
type Wallet = {
    user_id: UserId;
    btc_address: Text;
    network: Network;
    status: WalletStatus;
};
```

### UserSummary
```motoko
type UserSummary = {
    user_id: UserId;
    display_name: Text;
    risk_profile: RiskLevel;
    wallet_count: Nat;
    portfolio_value_sats: Nat64;
};
```

### Enums

#### RiskLevel
- `#conservative`: Low-risk strategies
- `#balanced`: Medium-risk strategies  
- `#aggressive`: High-risk strategies

#### Network
- `#testnet`: Bitcoin testnet
- `#mainnet`: Bitcoin mainnet

#### WalletStatus
- `#active`: Wallet is active and can be used
- `#inactive`: Wallet is disabled

## Bitcoin Address Validation

The canister validates Bitcoin addresses based on the specified network:

### Testnet Addresses
- Must start with `tb1`, `2`, `m`, or `n`
- Length between 26-62 characters

### Mainnet Addresses  
- Must start with `bc1`, `3`, or `1`
- Length between 26-62 characters

## State Management

The canister uses stable storage for upgrade persistence:

- **users**: HashMap of User objects indexed by Principal
- **wallets**: HashMap of Wallet objects indexed by WalletId
- **user_wallets**: HashMap mapping UserId to array of WalletIds

## Error Handling

All public methods return `Result<T, ApiError>` types with appropriate error codes:

- `#not_found`: Resource does not exist
- `#unauthorized`: Insufficient permissions
- `#invalid_input`: Invalid parameters or validation failure
- `#internal_error`: System error

## Testing

The canister includes comprehensive test suites:

- **Unit Tests** (`test.mo`): Test individual functions and validation logic
- **Integration Tests** (`integration_test.mo`): Test complete user workflows and system interactions

### Running Tests

```bash
# Build the canister
dfx build user_registry

# Deploy locally
dfx deploy user_registry --local

# Run tests (requires test runner implementation)
./run_tests.sh
```

## Usage Examples

### Register a New User
```motoko
let result = await user_registry.register("Alice", ?("alice@example.com"));
switch (result) {
    case (#ok(user_id)) {
        // User registered successfully
    };
    case (#err(error)) {
        // Handle error
    };
};
```

### Link a Bitcoin Wallet
```motoko
let result = await user_registry.link_wallet("tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx", #testnet);
switch (result) {
    case (#ok(wallet_id)) {
        // Wallet linked successfully
    };
    case (#err(error)) {
        // Handle error
    };
};
```

### Update Risk Profile
```motoko
let result = await user_registry.set_risk_profile(user_id, #aggressive);
switch (result) {
    case (#ok(success)) {
        // Risk profile updated
    };
    case (#err(error)) {
        // Handle error
    };
};
```

## Integration with Other Canisters

The User Registry canister is designed to integrate with other BetterTrade canisters:

- **Portfolio State**: Provides user validation and profile information
- **Strategy Selector**: Uses risk profiles for strategy recommendations
- **Execution Agent**: Validates user ownership for transaction execution
- **Risk Guard**: Uses risk preferences for protection configuration

## Future Enhancements

- Email verification and notifications
- Multi-signature wallet support
- Advanced user preferences and settings
- User activity tracking and analytics
- Integration with external identity providers