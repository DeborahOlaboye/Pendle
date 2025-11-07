// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../../src/PendleFixedYieldVault.sol";
import "../../src/interfaces/IStETH.sol";

/// @notice Integration tests with mainnet fork
/// @dev These tests require a mainnet RPC URL in .env
contract FullFlowIntegrationTest is Test {
    PendleFixedYieldVault public vault;
    YieldLockManager public manager;
    FixedYieldDistributor public distributor;

    // Mainnet addresses
    address constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address constant PENDLE_ROUTER = 0x00000000005BBB0EF59571E58418F9a4357b68A0;

    // Pendle stETH Market (Expiry: Dec 25, 2025)
    // Market: PT-stETH-25DEC25/SY-stETH
    address constant PENDLE_MARKET_STETH = 0xC374f7eC85F8C7DE3207a10bB1978bA104bdA3B2;
    address constant PENDLE_YT_STETH = 0xf3aBC972A0f537c1119C990d422463b93227Cd83;

    address public user1;
    address public user2;
    address public publicGood;

    uint256 mainnetFork;

    function setUp() public {
        // Check if we have RPC URL
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) {
            vm.skip(true);
            return;
        }

        // Create and select mainnet fork
        mainnetFork = vm.createFork(rpcUrl);
        vm.selectFork(mainnetFork);

        // Set up test addresses
        user1 = address(0x1234);
        user2 = address(0x5678);
        publicGood = address(0x9ABC);

        // Fund test users with ETH
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);

        // Skip if market addresses not configured
        if (PENDLE_MARKET_STETH == address(0) || PENDLE_YT_STETH == address(0)) {
            console.log("WARNING: Pendle market addresses not configured");
            console.log("Update PENDLE_MARKET_STETH and PENDLE_YT_STETH in test file");
            vm.skip(true);
            return;
        }

        // Deploy vault
        vault = new PendleFixedYieldVault(
            STETH,
            PENDLE_ROUTER,
            PENDLE_MARKET_STETH,
            PENDLE_YT_STETH
        );

        manager = vault.yieldLockManager();
        distributor = vault.yieldDistributor();

        // Transfer ownership of distributor to test contract for admin functions
        vm.prank(address(vault));
        distributor.transferOwnership(address(this));

        // Add public good to distributor
        distributor.addPublicGoodsProject(publicGood);
    }

    function testForkExists() public view {
        // Tenderly virtual testnet uses chain ID 8, mainnet fork uses 1
        assertTrue(block.chainid == 1 || block.chainid == 8, "Should be on mainnet fork or Tenderly vnet");
    }

    function testStETHContract() public view {
        IStETH stETH = IStETH(STETH);
        uint256 totalPooled = stETH.getTotalPooledEther();
        assertGt(totalPooled, 0, "stETH should have pooled ether");
    }

    function testDepositETH() public {
        // Skip test if markets not configured
        if (PENDLE_MARKET_STETH == address(0)) {
            return;
        }

        uint256 depositAmount = 1 ether;

        vm.startPrank(user1);

        uint256 balanceBefore = user1.balance;

        // Deposit ETH
        uint256 shares = vault.depositETH{value: depositAmount}();

        assertGt(shares, 0, "Should receive vault shares");
        assertEq(user1.balance, balanceBefore - depositAmount, "ETH should be deducted");

        vm.stopPrank();
    }

    function testFullDepositToYieldFlow() public {
        if (PENDLE_MARKET_STETH == address(0)) {
            return;
        }

        uint256 depositAmount = 10 ether;

        vm.startPrank(user1);

        // 1. Deposit ETH
        uint256 shares = vault.depositETH{value: depositAmount}();
        assertGt(shares, 0, "Should receive shares");

        vm.stopPrank();

        // 2. Verify stETH was received by vault
        uint256 stETHBalance = IStETH(STETH).balanceOf(address(vault));
        assertGt(stETHBalance, 0, "Vault should hold stETH");

        // 3. Verify PT position was created
        assertGt(manager.positionCount(), 0, "Should have PT position");

        // 4. Verify yield was collected
        uint256 yieldCollected = distributor.totalYieldCollected();
        assertGt(yieldCollected, 0, "Should have collected yield from YT sale");

        // 5. Distribute yield to public goods
        distributor.distributeToPublicGoods();

        uint256 publicGoodBalance = IStETH(STETH).balanceOf(publicGood);
        assertGt(publicGoodBalance, 0, "Public good should receive yield");
    }

    function testWithdrawBeforeMaturity() public {
        if (PENDLE_MARKET_STETH == address(0)) {
            return;
        }

        uint256 depositAmount = 5 ether;

        vm.startPrank(user1);

        // Deposit
        uint256 shares = vault.depositETH{value: depositAmount}();

        // Try to withdraw immediately
        uint256 assets = vault.previewRedeem(shares / 2);

        if (assets > 0) {
            vault.withdraw(assets, user1, user1);

            // Verify stETH received
            uint256 stETHBalance = IStETH(STETH).balanceOf(user1);
            assertGt(stETHBalance, 0, "Should receive stETH");
        }

        vm.stopPrank();
    }

    function testMultipleUserDeposits() public {
        if (PENDLE_MARKET_STETH == address(0)) {
            return;
        }

        uint256 deposit1 = 5 ether;
        uint256 deposit2 = 3 ether;

        // User 1 deposits
        vm.prank(user1);
        uint256 shares1 = vault.depositETH{value: deposit1}();

        // User 2 deposits
        vm.prank(user2);
        uint256 shares2 = vault.depositETH{value: deposit2}();

        assertGt(shares1, 0);
        assertGt(shares2, 0);

        // Shares should be proportional to deposits
        assertGt(shares1, shares2, "Larger deposit should get more shares");

        // Verify total assets
        uint256 totalAssets = vault.totalAssets();
        assertGt(totalAssets, 0);
    }

    function testRedeemAfterMaturity() public {
        if (PENDLE_MARKET_STETH == address(0)) {
            return;
        }

        uint256 depositAmount = 10 ether;

        vm.prank(user1);
        vault.depositETH{value: depositAmount}();

        // Get maturity date
        YieldLockManager.PTPosition memory position = manager.getPosition(0);
        uint256 maturity = position.maturity;

        // Warp to after maturity
        vm.warp(maturity + 1 days);

        // Redeem matured PT
        vault.redeemMaturedPT();

        // Verify position is redeemed
        position = manager.getPosition(0);
        assertTrue(position.redeemed, "Position should be marked as redeemed");
    }

    function testVaultPauseUnpause() public {
        // Pause the vault
        vault.pause();
        assertTrue(vault.paused());

        // Should not be able to deposit while paused
        vm.prank(user1);
        vm.expectRevert();
        vault.depositETH{value: 1 ether}();

        // Unpause
        vault.unpause();
        assertFalse(vault.paused());

        // Should be able to deposit now
        vm.prank(user1);
        uint256 shares = vault.depositETH{value: 1 ether}();
        assertGt(shares, 0);
    }

    function testUpdateSlippage() public {
        uint256 newSlippage = 200; // 2%

        vault.updateSlippage(newSlippage);
        assertEq(vault.slippageBps(), newSlippage);

        // Should not allow too high slippage
        vm.expectRevert("Slippage too high");
        vault.updateSlippage(1001); // >10%
    }

    function testUpdateMinDeposit() public {
        uint256 newMinDeposit = 0.1 ether;

        vault.updateMinDeposit(newMinDeposit);
        assertEq(vault.minDeposit(), newMinDeposit);

        // Should not allow deposits below minimum
        vm.prank(user1);
        vm.expectRevert("Deposit too small");
        vault.depositETH{value: 0.05 ether}();
    }

    function testYieldHistory() public {
        if (PENDLE_MARKET_STETH == address(0)) {
            return;
        }

        // Make multiple deposits to generate yield events
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(user1);
            vault.depositETH{value: 1 ether}();

            vm.warp(block.timestamp + 10 days);
        }

        // Check yield history
        uint256 historyCount = distributor.getYieldHistoryCount();
        assertGt(historyCount, 0, "Should have yield history");

        // Get fixed yield rate
        uint256 rate = distributor.getFixedYieldRate();
        console.log("Fixed yield rate:", rate, "bps");
    }

    function testTotalAssetsCalculation() public {
        if (PENDLE_MARKET_STETH == address(0)) {
            return;
        }

        uint256 depositAmount = 10 ether;

        vm.prank(user1);
        vault.depositETH{value: depositAmount}();

        uint256 totalAssets = vault.totalAssets();

        // Total assets should include:
        // - stETH balance in vault
        // - PT locked value
        assertGt(totalAssets, 0, "Should have total assets");

        uint256 stETHBalance = IStETH(STETH).balanceOf(address(vault));
        uint256 lockedValue = manager.getTotalLockedValue();

        assertEq(
            totalAssets,
            stETHBalance + lockedValue,
            "Total assets should equal stETH + PT"
        );
    }

    function testGasEstimates() public {
        if (PENDLE_MARKET_STETH == address(0)) {
            return;
        }

        uint256 depositAmount = 1 ether;

        vm.prank(user1);

        uint256 gasBefore = gasleft();
        vault.depositETH{value: depositAmount}();
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used for deposit:", gasUsed);

        // Should be within expected range
        assertLt(gasUsed, 500000, "Deposit gas should be reasonable");
    }
}
