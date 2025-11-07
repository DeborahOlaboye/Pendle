// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../src/PendleFixedYieldVault.sol";

/// @title Deploy Script
/// @notice Deploys the Pendle Fixed Yield Vault and related contracts
contract DeployScript is Script {
    // Mainnet addresses (Ethereum)
    address constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address constant PENDLE_ROUTER = 0x00000000005BBB0EF59571E58418F9a4357b68A0;

    // These should be updated with actual market addresses
    // Check https://app.pendle.finance/trade/markets for latest
    address constant PENDLE_MARKET_STETH = address(0); // UPDATE THIS
    address constant PENDLE_YT_STETH = address(0); // UPDATE THIS

    function run() external {
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the vault
        PendleFixedYieldVault vault = new PendleFixedYieldVault(
            STETH,
            PENDLE_ROUTER,
            PENDLE_MARKET_STETH,
            PENDLE_YT_STETH
        );

        console.log("PendleFixedYieldVault deployed at:", address(vault));
        console.log("YieldLockManager deployed at:", address(vault.yieldLockManager()));
        console.log("FixedYieldDistributor deployed at:", address(vault.yieldDistributor()));

        vm.stopBroadcast();
    }
}
