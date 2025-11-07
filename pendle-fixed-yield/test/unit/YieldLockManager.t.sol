// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../../src/YieldLockManager.sol";

contract YieldLockManagerTest is Test {
    YieldLockManager public manager;
    address public owner;
    address public user;

    address constant PT_TOKEN_1 = address(0x1);
    address constant PT_TOKEN_2 = address(0x2);

    uint256 constant AMOUNT_1 = 100 ether;
    uint256 constant AMOUNT_2 = 200 ether;

    event PositionAdded(
        uint256 indexed positionId,
        address indexed ptToken,
        uint256 amount,
        uint256 maturity
    );

    event PositionRedeemed(uint256 indexed positionId, uint256 timestamp);
    event MaturityAdded(uint256 maturity);

    function setUp() public {
        owner = address(this);
        user = address(0x123);
        manager = new YieldLockManager();
    }

    function testInitialState() public {
        assertEq(manager.positionCount(), 0);
        assertEq(manager.getMaturitiesCount(), 0);
    }

    function testAddPosition() public {
        uint256 maturity = block.timestamp + 180 days;

        vm.expectEmit(true, true, false, true);
        emit MaturityAdded(maturity);

        vm.expectEmit(true, true, false, true);
        emit PositionAdded(0, PT_TOKEN_1, AMOUNT_1, maturity);

        uint256 positionId = manager.addPosition(PT_TOKEN_1, AMOUNT_1, maturity);

        assertEq(positionId, 0);
        assertEq(manager.positionCount(), 1);

        YieldLockManager.PTPosition memory position = manager.getPosition(0);
        assertEq(position.ptToken, PT_TOKEN_1);
        assertEq(position.amount, AMOUNT_1);
        assertEq(position.maturity, maturity);
        assertEq(position.redeemed, false);
        assertEq(position.depositedAt, block.timestamp);
    }

    function testAddMultiplePositions() public {
        uint256 maturity1 = block.timestamp + 180 days;
        uint256 maturity2 = block.timestamp + 365 days;

        manager.addPosition(PT_TOKEN_1, AMOUNT_1, maturity1);
        manager.addPosition(PT_TOKEN_2, AMOUNT_2, maturity2);

        assertEq(manager.positionCount(), 2);
        assertEq(manager.getMaturitiesCount(), 2);

        // Check first position
        YieldLockManager.PTPosition memory pos1 = manager.getPosition(0);
        assertEq(pos1.amount, AMOUNT_1);

        // Check second position
        YieldLockManager.PTPosition memory pos2 = manager.getPosition(1);
        assertEq(pos2.amount, AMOUNT_2);
    }

    function testAddPositionSameMaturity() public {
        uint256 maturity = block.timestamp + 180 days;

        manager.addPosition(PT_TOKEN_1, AMOUNT_1, maturity);
        manager.addPosition(PT_TOKEN_2, AMOUNT_2, maturity);

        // Should only have 1 unique maturity
        assertEq(manager.getMaturitiesCount(), 1);
        assertEq(manager.positionCount(), 2);

        // Total PT for this maturity should be sum of both
        assertEq(manager.getTotalPTForMaturity(maturity), AMOUNT_1 + AMOUNT_2);
    }

    function testCannotAddPositionWithZeroAddress() public {
        uint256 maturity = block.timestamp + 180 days;

        vm.expectRevert("Invalid PT token");
        manager.addPosition(address(0), AMOUNT_1, maturity);
    }

    function testCannotAddPositionWithZeroAmount() public {
        uint256 maturity = block.timestamp + 180 days;

        vm.expectRevert("Amount must be > 0");
        manager.addPosition(PT_TOKEN_1, 0, maturity);
    }

    function testCannotAddPositionWithPastMaturity() public {
        uint256 pastMaturity = block.timestamp - 1 days;

        vm.expectRevert("Maturity must be in future");
        manager.addPosition(PT_TOKEN_1, AMOUNT_1, pastMaturity);
    }

    function testMarkRedeemed() public {
        uint256 maturity = block.timestamp + 180 days;
        uint256 positionId = manager.addPosition(PT_TOKEN_1, AMOUNT_1, maturity);

        // Warp to after maturity
        vm.warp(maturity + 1);

        vm.expectEmit(true, false, false, true);
        emit PositionRedeemed(positionId, block.timestamp);

        manager.markRedeemed(positionId);

        YieldLockManager.PTPosition memory position = manager.getPosition(positionId);
        assertTrue(position.redeemed);

        // Total PT for maturity should be reduced
        assertEq(manager.getTotalPTForMaturity(maturity), 0);
    }

    function testCannotRedeemBeforeMaturity() public {
        uint256 maturity = block.timestamp + 180 days;
        uint256 positionId = manager.addPosition(PT_TOKEN_1, AMOUNT_1, maturity);

        vm.expectRevert("Not matured yet");
        manager.markRedeemed(positionId);
    }

    function testCannotRedeemAlreadyRedeemed() public {
        uint256 maturity = block.timestamp + 180 days;
        uint256 positionId = manager.addPosition(PT_TOKEN_1, AMOUNT_1, maturity);

        vm.warp(maturity + 1);
        manager.markRedeemed(positionId);

        vm.expectRevert("Already redeemed");
        manager.markRedeemed(positionId);
    }

    function testCannotRedeemInvalidPosition() public {
        vm.expectRevert("Invalid position ID");
        manager.markRedeemed(999);
    }

    function testGetMaturedPositions() public {
        uint256 maturity1 = block.timestamp + 180 days;
        uint256 maturity2 = block.timestamp + 365 days;

        manager.addPosition(PT_TOKEN_1, AMOUNT_1, maturity1);
        manager.addPosition(PT_TOKEN_2, AMOUNT_2, maturity2);

        // Initially no matured positions
        (address[] memory tokens, uint256[] memory amounts, uint256[] memory maturities)
            = manager.getMaturedPositions();
        assertEq(tokens.length, 0);

        // Warp to after first maturity
        vm.warp(maturity1 + 1);

        (tokens, amounts, maturities) = manager.getMaturedPositions();
        assertEq(tokens.length, 1);
        assertEq(tokens[0], PT_TOKEN_1);
        assertEq(amounts[0], AMOUNT_1);
        assertEq(maturities[0], maturity1);

        // Warp to after second maturity
        vm.warp(maturity2 + 1);

        (tokens, amounts, maturities) = manager.getMaturedPositions();
        assertEq(tokens.length, 2);
    }

    function testGetUpcomingMaturities() public {
        uint256 maturity1 = block.timestamp + 10 days;
        uint256 maturity2 = block.timestamp + 20 days;
        uint256 maturity3 = block.timestamp + 40 days;

        manager.addPosition(PT_TOKEN_1, AMOUNT_1, maturity1);
        manager.addPosition(PT_TOKEN_1, AMOUNT_2, maturity2);
        manager.addPosition(PT_TOKEN_1, AMOUNT_1, maturity3);

        // Get maturities in next 25 days
        uint256[] memory upcoming = manager.getUpcomingMaturities(25);
        assertEq(upcoming.length, 2); // maturity1 and maturity2

        // Get maturities in next 50 days
        upcoming = manager.getUpcomingMaturities(50);
        assertEq(upcoming.length, 3); // all three
    }

    function testGetPositionsByMaturity() public {
        uint256 maturity = block.timestamp + 180 days;

        manager.addPosition(PT_TOKEN_1, AMOUNT_1, maturity);
        manager.addPosition(PT_TOKEN_2, AMOUNT_2, maturity);
        manager.addPosition(PT_TOKEN_1, AMOUNT_1, block.timestamp + 365 days);

        uint256[] memory positions = manager.getPositionsByMaturity(maturity);
        assertEq(positions.length, 2);
        assertEq(positions[0], 0);
        assertEq(positions[1], 1);
    }

    function testGetTotalLockedValue() public {
        uint256 maturity = block.timestamp + 180 days;

        manager.addPosition(PT_TOKEN_1, AMOUNT_1, maturity);
        manager.addPosition(PT_TOKEN_2, AMOUNT_2, maturity);

        uint256 totalLocked = manager.getTotalLockedValue();
        assertEq(totalLocked, AMOUNT_1 + AMOUNT_2);

        // After redeeming one
        vm.warp(maturity + 1);
        manager.markRedeemed(0);

        totalLocked = manager.getTotalLockedValue();
        assertEq(totalLocked, AMOUNT_2);
    }

    function testCalculateRedeemableAmount() public {
        uint256 maturity1 = block.timestamp + 180 days;
        uint256 maturity2 = block.timestamp + 365 days;

        manager.addPosition(PT_TOKEN_1, AMOUNT_1, maturity1);
        manager.addPosition(PT_TOKEN_2, AMOUNT_2, maturity2);

        // Initially nothing redeemable
        assertEq(manager.calculateRedeemableAmount(), 0);

        // After first maturity
        vm.warp(maturity1 + 1);
        assertEq(manager.calculateRedeemableAmount(), AMOUNT_1);

        // After second maturity
        vm.warp(maturity2 + 1);
        assertEq(manager.calculateRedeemableAmount(), AMOUNT_1 + AMOUNT_2);

        // After redeeming first
        manager.markRedeemed(0);
        assertEq(manager.calculateRedeemableAmount(), AMOUNT_2);
    }

    function testGetAllMaturities() public {
        uint256 maturity1 = block.timestamp + 180 days;
        uint256 maturity2 = block.timestamp + 365 days;

        manager.addPosition(PT_TOKEN_1, AMOUNT_1, maturity1);
        manager.addPosition(PT_TOKEN_2, AMOUNT_2, maturity2);

        uint256[] memory maturities = manager.getAllMaturities();
        assertEq(maturities.length, 2);
        assertEq(maturities[0], maturity1);
        assertEq(maturities[1], maturity2);
    }

    function testOnlyOwnerCanAddPosition() public {
        uint256 maturity = block.timestamp + 180 days;

        vm.prank(user);
        vm.expectRevert();
        manager.addPosition(PT_TOKEN_1, AMOUNT_1, maturity);
    }

    function testOnlyOwnerCanMarkRedeemed() public {
        uint256 maturity = block.timestamp + 180 days;
        manager.addPosition(PT_TOKEN_1, AMOUNT_1, maturity);

        vm.warp(maturity + 1);

        vm.prank(user);
        vm.expectRevert();
        manager.markRedeemed(0);
    }

    function testFuzzAddPosition(uint256 amount, uint256 futureTime) public {
        // Bound inputs to reasonable ranges
        amount = bound(amount, 1, 1000000 ether);
        futureTime = bound(futureTime, 1 days, 1000 days);

        uint256 maturity = block.timestamp + futureTime;

        uint256 positionId = manager.addPosition(PT_TOKEN_1, amount, maturity);

        YieldLockManager.PTPosition memory position = manager.getPosition(positionId);
        assertEq(position.amount, amount);
        assertEq(position.maturity, maturity);
    }
}
