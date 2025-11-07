# Pendle Fixed Yield Strategy for Octant

## Overview

This project implements a **Pendle Fixed Yield Strategy** that transforms unpredictable DeFi yields into guaranteed, fixed returns for sustainable public goods funding through integration with Octant.

## The Problem

Public goods projects struggle with unpredictable funding from variable DeFi yields, making it difficult to plan long-term initiatives and maintain sustainability.

## Our Solution

By leveraging Pendle's yield tokenization protocol, we split staking yields into:
- **PT (Principal Tokens)**: Locked until maturity, representing the principal
- **YT (Yield Tokens)**: Sold immediately for guaranteed fixed yield

This creates predictable, fixed-rate returns that can be reliably distributed to public goods projects via Octant.

## Architecture

```
User deposits ETH
    ↓
Convert to stETH (Lido)
    ↓
Split into PT + YT (Pendle)
    ↓
Sell YT for fixed yield → Distribute to public goods
    ↓
Hold PT until maturity → Return principal to vault
```

## Smart Contracts

### 1. PendleFixedYieldVault.sol
**Main ERC4626 vault contract**
- Accepts ETH deposits and mints vault shares
- Converts ETH to stETH via Lido
- Splits stETH into PT/YT via Pendle
- Manages withdrawals and PT redemption
- **Location**: `src/PendleFixedYieldVault.sol`

### 2. YieldLockManager.sol
**PT position tracking and management**
- Tracks all PT positions with maturity dates
- Manages position redemption status
- Provides maturity tracking and laddering
- Calculates total locked value
- **Location**: `src/YieldLockManager.sol`

### 3. FixedYieldDistributor.sol
**Yield collection and distribution**
- Collects fixed yield from YT sales
- Distributes to Octant payment splitter
- Tracks yield history and rates
- Provides yield predictions
- **Location**: `src/FixedYieldDistributor.sol`

### 4. PendleHelpers.sol
**Helper library for calculations**
- YT value calculations
- Optimal maturity selection
- Fixed rate calculations
- Slippage protection
- **Location**: `src/libraries/PendleHelpers.sol`

### 5. Interfaces
- **IPendleRouter**: Pendle Router interaction
- **IPendleMarket**: Market data retrieval
- **IStETH**: Lido stETH interaction
- **Location**: `src/interfaces/`

## Project Structure

```
pendle-fixed-yield/
├── src/
│   ├── PendleFixedYieldVault.sol       # Main vault
│   ├── YieldLockManager.sol            # PT tracking
│   ├── FixedYieldDistributor.sol       # Yield distribution
│   ├── interfaces/                     # Contract interfaces
│   │   ├── IPendleRouter.sol
│   │   ├── IPendleMarket.sol
│   │   └── IStETH.sol
│   └── libraries/
│       └── PendleHelpers.sol           # Helper functions
├── test/
│   ├── unit/                           # Unit tests
│   ├── integration/                    # Integration tests
│   └── fork/                           # Mainnet fork tests
├── script/
│   └── Deploy.s.sol                    # Deployment script
├── docs/                               # Additional documentation
├── foundry.toml                        # Foundry configuration
└── .env                                # Environment variables
```

## Setup Instructions

### Prerequisites
- Foundry installed (forge, cast, anvil)
- RPC URL for Ethereum mainnet
- Etherscan API key (for verification)

### Installation

1. **Navigate to the project**:
```bash
cd pendle-fixed-yield
```

2. **Install dependencies** (already installed):
```bash
forge install
```

3. **Configure environment variables**:
Edit `.env` file with your actual values:
```bash
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
ETHERSCAN_API_KEY=your_etherscan_key
PRIVATE_KEY=your_private_key
```

4. **Compile contracts**:
```bash
forge build
```

## Compilation Status

✅ **Successfully compiled!**
- All contracts compile without errors
- Only style warnings (naming conventions)
- Ready for testing and deployment

## Key Features

### For Users
- **Fixed Yield**: Predictable returns instead of variable APY
- **ERC4626 Standard**: Compatible with existing DeFi integrations
- **Flexible Withdrawals**: Withdraw before or after PT maturity
- **No Impermanent Loss**: Principal protected by PT tokens

### For Public Goods
- **Predictable Funding**: Known yield amounts in advance
- **Sustainable Planning**: Long-term project planning
- **Octant Integration**: Direct payment splitter integration
- **Transparent Distribution**: On-chain yield tracking

### Technical Features
- **Pausable**: Emergency pause mechanism
- **Access Control**: Owner-only admin functions
- **Reentrancy Protection**: SafeERC20 and ReentrancyGuard
- **Slippage Protection**: Configurable slippage tolerance
- **Gas Optimized**: Efficient storage and computation

## Contract Addresses

### Mainnet Dependencies
```solidity
stETH: 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84
Pendle Router: 0x00000000005BBB0EF59571E58418F9a4357b68A0
```

### Deployment
To deploy, update market addresses in `script/Deploy.s.sol` and run:
```bash
forge script script/Deploy.s.sol --rpc-url $MAINNET_RPC_URL --broadcast --verify
```

## Usage Examples

### Depositing ETH
```solidity
// User deposits 1 ETH
vault.depositETH{value: 1 ether}();
```

### Checking Fixed Yield Rate
```solidity
uint256 rate = distributor.getFixedYieldRate(); // Returns rate in basis points
```

### Redeeming Matured PT
```solidity
vault.redeemMaturedPT(); // Only owner
```

### Distributing to Public Goods
```solidity
distributor.distributeToPublicGoods(); // Only owner
```

## Security Considerations

### Implemented Protections
- ✅ ReentrancyGuard on all state-changing functions
- ✅ SafeERC20 for all token transfers
- ✅ Access control (Ownable)
- ✅ Pausable for emergencies
- ✅ Input validation on all functions
- ✅ Slippage protection on swaps

### Recommended Audits
- [ ] Smart contract security audit
- [ ] Economic model review
- [ ] Integration testing on mainnet fork
- [ ] Gas optimization review

## Testing

### Run Tests
```bash
# Unit tests
forge test

# With verbosity
forge test -vvv

# Gas report
forge test --gas-report

# Coverage
forge coverage
```

### Fork Testing
```bash
# Test against mainnet fork
forge test --fork-url $MAINNET_RPC_URL -vvv
```

## Roadmap

### Completed ✅
- [x] Core smart contract architecture
- [x] ERC4626 vault implementation
- [x] PT position management
- [x] Yield distribution system
- [x] Helper libraries
- [x] Deployment scripts
- [x] Compilation successful

### Next Steps 📋
- [ ] Comprehensive unit tests (>90% coverage)
- [ ] Integration tests with mainnet fork
- [ ] Frontend development (Next.js + RainbowKit)
- [ ] Documentation and user guides
- [ ] Security audit
- [ ] Testnet deployment
- [ ] Mainnet deployment

## Contributing

This is a hackathon project for the Octant/Pendle integration challenge. Contributions, suggestions, and feedback are welcome!

## License

MIT License

## Resources

- [Pendle Documentation](https://docs.pendle.finance/)
- [Octant Documentation](https://docs.octant.app/)
- [ERC-4626 Standard](https://eips.ethereum.org/EIPS/eip-4626)
- [Foundry Book](https://book.getfoundry.sh/)

## Contact

For questions or collaboration, please open an issue in this repository.

---

**Built with ❤️ for sustainable public goods funding**
