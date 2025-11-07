// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../../src/YieldLockManager.sol";
import "../../src/FixedYieldDistributor.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1000000 ether);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @notice Edge case and failure scenario tests
contract EdgeCasesTest is Test {
    YieldLockManager public manager;
    FixedYieldDistributor public distributor;
    MockERC20 public token;

    address public owner;
    address public attacker;

    function setUp() public {
        owner = address(this);
        attacker = address(0xBAD);

        manager = new YieldLockManager();
        token = new MockERC20();
        distributor = new FixedYieldDistributor(address(token));

        // Fund attacker
        vm.deal(attacker, 100 ether);
    }

    // ============= YieldLockManager Edge Cases =============

    function testCannotAddPositionWithZeroAmount() public {
        uint256 maturity = block.timestamp + 180 days;

        vm.expectRevert("Amount must be > 0");
        manager.addPosition(address(0x1), 0, maturity);
    }

    function testCannotAddPositionWithZeroAddress() public {
        vm.expectRevert("Invalid PT token");
        manager.addPosition(address(0), 100 ether, block.timestamp + 180 days);
    }

    function testCannotAddPositionInThePast() public {
        vm.expectRevert("Maturity must be in future");
        manager.addPosition(address(0x1), 100 ether, block.timestamp - 1);
    }

    function testCannotRedeemBeforeMaturity() public {
        uint256 maturity = block.timestamp + 180 days;
        uint256 positionId = manager.addPosition(address(0x1), 100 ether, maturity);

        vm.warp(maturity - 1); // Just before maturity

        vm.expectRevert("Not matured yet");
        manager.markRedeemed(positionId);
    }

    function testCannotRedeemTwice() public {
        uint256 maturity = block.timestamp + 180 days;
        uint256 positionId = manager.addPosition(address(0x1), 100 ether, maturity);

        vm.warp(maturity + 1);
        manager.markRedeemed(positionId);

        vm.expectRevert("Already redeemed");
        manager.markRedeemed(positionId);
    }

    function testCannotRedeemInvalidPosition() public {
        vm.expectRevert("Invalid position ID");
        manager.markRedeemed(999);
    }

    function testGetPositionRevertsOnInvalidId() public {
        vm.expectRevert("Invalid position ID");
        manager.getPosition(999);
    }

    function testEmptyMaturedPositions() public {
        (address[] memory tokens, uint256[] memory amounts, uint256[] memory maturities) =
            manager.getMaturedPositions();

        assertEq(tokens.length, 0);
        assertEq(amounts.length, 0);
        assertEq(maturities.length, 0);
    }

    function testUpcomingMaturitiesWithNoneUpcoming() public {
        // Add position far in future
        manager.addPosition(address(0x1), 100 ether, block.timestamp + 365 days);

        uint256[] memory upcoming = manager.getUpcomingMaturities(30); // Next 30 days

        assertEq(upcoming.length, 0, "Should have no upcoming maturities");
    }

    function testTotalLockedValueWhenAllRedeemed() public {
        uint256 maturity = block.timestamp + 180 days;

        manager.addPosition(address(0x1), 100 ether, maturity);
        manager.addPosition(address(0x2), 200 ether, maturity);

        vm.warp(maturity + 1);

        manager.markRedeemed(0);
        manager.markRedeemed(1);

        assertEq(manager.getTotalLockedValue(), 0);
    }

    // ============= FixedYieldDistributor Edge Cases =============

    function testCannotReceiveZeroYield() public {
        vm.expectRevert("Amount must be > 0");
        distributor.receiveYield(0);
    }

    function testCannotDistributeWithNoYield() public {
        distributor.addPublicGoodsProject(address(0x1));

        vm.expectRevert("No yield to distribute");
        distributor.distributeToPublicGoods();
    }

    function testCannotDistributeWithNoProjects() public {
        token.transfer(address(distributor), 100 ether);
        distributor.receiveYield(100 ether);

        vm.expectRevert("No public goods projects");
        distributor.distributeToPublicGoods();
    }

    function testCannotAddZeroAddressProject() public {
        vm.expectRevert("Invalid project address");
        distributor.addPublicGoodsProject(address(0));
    }

    function testCannotAddDuplicateProject() public {
        distributor.addPublicGoodsProject(address(0x1));

        vm.expectRevert("Project already exists");
        distributor.addPublicGoodsProject(address(0x1));
    }

    function testCannotRemoveNonexistentProject() public {
        vm.expectRevert("Project does not exist");
        distributor.removePublicGoodsProject(address(0x1));
    }

    function testCannotSetZeroAddressSplitter() public {
        vm.expectRevert("Invalid splitter address");
        distributor.setOctantPaymentSplitter(address(0));
    }

    function testGetYieldHistoryInvalidRange() public {
        token.transfer(address(distributor), 10 ether);
        distributor.receiveYield(10 ether);

        vm.expectRevert("Invalid end index");
        distributor.getYieldHistory(0, 10);

        vm.expectRevert("Invalid range");
        distributor.getYieldHistory(5, 0);

        vm.expectRevert("Invalid start index");
        distributor.getYieldHistory(10, 15);
    }

    function testPredictedYieldWithNoHistory() public {
        uint256 predicted = distributor.getPredictedYield(30 days);
        assertEq(predicted, 0);
    }

    function testFixedYieldRateWithNoHistory() public {
        uint256 rate = distributor.getFixedYieldRate();
        assertEq(rate, 0);
    }

    // ============= Access Control Tests =============

    function testOnlyOwnerCanAddPosition() public {
        vm.prank(attacker);
        vm.expectRevert();
        manager.addPosition(address(0x1), 100 ether, block.timestamp + 180 days);
    }

    function testOnlyOwnerCanMarkRedeemed() public {
        uint256 positionId = manager.addPosition(
            address(0x1),
            100 ether,
            block.timestamp + 180 days
        );

        vm.warp(block.timestamp + 181 days);

        vm.prank(attacker);
        vm.expectRevert();
        manager.markRedeemed(positionId);
    }

    function testOnlyOwnerCanDistribute() public {
        distributor.addPublicGoodsProject(address(0x1));
        token.transfer(address(distributor), 100 ether);
        distributor.receiveYield(100 ether);

        vm.prank(attacker);
        vm.expectRevert();
        distributor.distributeToPublicGoods();
    }

    function testOnlyOwnerCanAddProject() public {
        vm.prank(attacker);
        vm.expectRevert();
        distributor.addPublicGoodsProject(address(0x1));
    }

    function testOnlyOwnerCanRemoveProject() public {
        distributor.addPublicGoodsProject(address(0x1));

        vm.prank(attacker);
        vm.expectRevert();
        distributor.removePublicGoodsProject(address(0x1));
    }

    function testOnlyOwnerCanSetSplitter() public {
        vm.prank(attacker);
        vm.expectRevert();
        distributor.setOctantPaymentSplitter(address(0x123));
    }

    function testOnlyOwnerCanEmergencyWithdraw() public {
        token.transfer(address(distributor), 100 ether);

        vm.prank(attacker);
        vm.expectRevert();
        distributor.emergencyWithdraw(address(token), 100 ether);
    }

    // ============= Arithmetic Edge Cases =============

    function testVerySmallYieldAmounts() public {
        uint256 tinyAmount = 1; // 1 wei

        token.mint(address(distributor), tinyAmount);
        distributor.receiveYield(tinyAmount);

        assertEq(distributor.totalYieldCollected(), tinyAmount);
    }

    function testVeryLargeYieldAmounts() public {
        uint256 hugeAmount = 1000000 ether;

        token.mint(address(distributor), hugeAmount);
        distributor.receiveYield(hugeAmount);

        assertEq(distributor.totalYieldCollected(), hugeAmount);
    }

    function testDistributionRounding() public {
        // Test with amount that doesn't divide evenly
        distributor.addPublicGoodsProject(address(0x1));
        distributor.addPublicGoodsProject(address(0x2));
        distributor.addPublicGoodsProject(address(0x3));

        uint256 yieldAmount = 100 ether + 1 wei; // Not divisible by 3

        token.transfer(address(distributor), yieldAmount);
        distributor.receiveYield(yieldAmount);
        distributor.distributeToPublicGoods();

        // Check total distributed equals total collected
        assertEq(
            distributor.totalYieldDistributed(),
            distributor.totalYieldCollected()
        );
    }

    function testPositionCountOverflow() public {
        // This would take too long to actually overflow uint256
        // But we can test the counter increments correctly
        uint256 initialCount = manager.positionCount();

        manager.addPosition(address(0x1), 100 ether, block.timestamp + 180 days);

        assertEq(manager.positionCount(), initialCount + 1);
    }

    function testMultipleMaturitiesSameTimestamp() public {
        uint256 maturity = block.timestamp + 180 days;

        // Add multiple positions with same maturity
        manager.addPosition(address(0x1), 100 ether, maturity);
        manager.addPosition(address(0x2), 200 ether, maturity);
        manager.addPosition(address(0x3), 300 ether, maturity);

        // Should only create one maturity entry
        assertEq(manager.getMaturitiesCount(), 1);

        // Total should be sum of all
        assertEq(manager.getTotalPTForMaturity(maturity), 600 ether);
    }

    function testRemoveMiddleProject() public {
        distributor.addPublicGoodsProject(address(0x1));
        distributor.addPublicGoodsProject(address(0x2));
        distributor.addPublicGoodsProject(address(0x3));

        distributor.removePublicGoodsProject(address(0x2));

        assertEq(distributor.getPublicGoodsProjectsCount(), 2);
        assertFalse(distributor.isPublicGoodsProject(address(0x2)));
        assertTrue(distributor.isPublicGoodsProject(address(0x1)));
        assertTrue(distributor.isPublicGoodsProject(address(0x3)));
    }

    function testYieldHistoryOrder() public {
        // Add yields with increasing amounts
        for (uint256 i = 1; i <= 5; i++) {
            token.mint(address(distributor), i * 1 ether);
            distributor.receiveYield(i * 1 ether);
            vm.warp(block.timestamp + 10 days);
        }

        // Verify history maintains order
        FixedYieldDistributor.YieldEvent[] memory events =
            distributor.getYieldHistory(0, 5);

        for (uint256 i = 0; i < events.length - 1; i++) {
            assertLt(
                events[i].timestamp,
                events[i + 1].timestamp,
                "Timestamps should be increasing"
            );
        }
    }

    // ============= Reentrancy Tests =============

    function testReentrancyProtection() public {
        // FixedYieldDistributor has ReentrancyGuard
        // This is a placeholder - actual reentrancy testing would need
        // malicious contract attempting to reenter
        distributor.addPublicGoodsProject(address(0x1));
        token.transfer(address(distributor), 100 ether);
        distributor.receiveYield(100 ether);

        // Should complete without reentrancy
        distributor.distributeToPublicGoods();
        assertTrue(true);
    }

    // ============= Time-based Edge Cases =============

    function testMaturityExactlyAtBlockTimestamp() public {
        uint256 maturity = block.timestamp + 180 days;
        manager.addPosition(address(0x1), 100 ether, maturity);

        // Warp to exact maturity
        vm.warp(maturity);

        // Should be able to redeem at exact maturity
        manager.markRedeemed(0);
        assertTrue(true);
    }

    function testVeryFarFutureMaturity() public {
        uint256 farFuture = block.timestamp + 100 * 365 days; // 100 years

        uint256 positionId = manager.addPosition(
            address(0x1),
            100 ether,
            farFuture
        );

        YieldLockManager.PTPosition memory position = manager.getPosition(positionId);
        assertEq(position.maturity, farFuture);
    }

    // ============= Fuzz Tests for Edge Cases =============

    function testFuzzYieldAmount(uint256 amount) public {
        amount = bound(amount, 1, type(uint128).max); // Reasonable range

        token.mint(address(distributor), amount);
        distributor.receiveYield(amount);

        assertEq(distributor.totalYieldCollected(), amount);
    }

    function testFuzzPositionAmount(uint256 amount) public {
        amount = bound(amount, 1, type(uint128).max);

        uint256 positionId = manager.addPosition(
            address(0x1),
            amount,
            block.timestamp + 180 days
        );

        YieldLockManager.PTPosition memory position = manager.getPosition(positionId);
        assertEq(position.amount, amount);
    }

    function testFuzzMaturityDate(uint256 futureTime) public {
        futureTime = bound(futureTime, 1, 1000 * 365 days);

        uint256 maturity = block.timestamp + futureTime;

        uint256 positionId = manager.addPosition(address(0x1), 100 ether, maturity);

        YieldLockManager.PTPosition memory position = manager.getPosition(positionId);
        assertEq(position.maturity, maturity);
    }
}
