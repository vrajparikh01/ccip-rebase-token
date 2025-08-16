# CCIP Rebase Token Protocol

## 📌 Overview

The CCIP Rebase Token Protocol is a cross-chain enabled vault system that issues rebase tokens to depositors. These tokens dynamically represent a user’s share of the underlying vault balance, adjusting automatically over time based on protocol-defined interest rates.

Unlike traditional ERC20 tokens, rebase tokens have a dynamic balanceOf calculation, meaning balances are not fixed but instead update in real time as yield accrues. This makes them ideal for building yield-bearing assets, liquidity layers, or cross-chain DeFi applications.

## 🚀 Key Features

#### Vault-Based Deposits
Users deposit assets into the protocol vault and receive rebase tokens representing their share of the vault.

#### Dynamic Rebase Tokens
balanceOf(address) is dynamic and reflects linear growth or decay over time.
Token balances adjust whenever users interact with the system (mint, burn, transfer, bridge, etc.).

#### Protocol-Wide Interest Rate
Each deposit is assigned an interest rate derived from a global interest rate curve.
The global rate only decreases over time, rewarding early adopters.
Earlier depositors benefit from higher yields compared to latecomers.

#### Cross-Chain Interoperability (via CCIP)
Rebase tokens can be bridged across chains using Chainlink’s CCIP (Cross-Chain Interoperability Protocol).
Ensures that yield accrual remains synchronized across multiple networks.

## ⚙️ Technical Architecture
#### `1. Vault`
- Holds user deposits.
- Mints rebase tokens to depositors proportional to their contribution.
- Tracks individual user rates and accrual schedules.

#### `2. Rebase Token (ERC20 Extension)`
- Implements ERC20 standard with modified balanceOf.
- balanceOf(user) = Principal Deposit × (1 + Interest Accrual over time).
- Supports minting, burning, transferring, and bridging.

#### `3. Interest Rate Mechanism`
- Global Interest Rate: decreases monotonically over time.
- User Rate: fixed at time of deposit, based on current global rate.
- Formula (simplified): userBalance(t) = principal × (1 + userRate × elapsedTime)

#### `4. CCIP Integration`
- Uses Chainlink CCIP for secure cross-chain messaging.
- Ensures consistent balances when tokens are moved across chains.

### 📁 Installation

1. Clone the repository:
   ```
   git clone https://github.com/vrajparikh01/ccip-rebase-token.git
   ```

2. Navigate to the project directory:
   ```
   cd ccip-rebase-token
   ```

3. Install dependencies:
   ```
   forge install
   ```

### 🧪 Deployment and Testing
1. Deploy the CCIP Rebase token contracts on Sepolia testnet using the following command:
   ```
   forge script script/Deployer.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
   forge script script/ConfigurePool.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
   forge script script/BridgeTokens.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
   ```
2. Run fuzz tests locally on foundry:
   ```
   forge test
   ```

## 💡 Use Cases
- Yield-bearing stablecoins.
- Cross-chain liquidity markets.
- Incentivized savings vaults.
- On-chain treasuries with dynamic growth.