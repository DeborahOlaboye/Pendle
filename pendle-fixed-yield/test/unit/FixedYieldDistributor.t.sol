// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../../src/FixedYieldDistributor.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock stETH", "mstETH") {
        _mint(msg.sender, 1000000 ether);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract FixedYieldDistributorTest is Test {
    FixedYieldDistributor public distributor;
    MockERC20 public stETH;

    address public owner;
    address public vault;
    address public publicGood1;
    address public publicGood2;
    address public octantSplitter;

    event YieldReceived(uint256 amount, uint256 timestamp);
    event YieldDistributed(address indexed recipient, uint256 amount);
    event OctantSplitterUpdated(address indexed newSplitter);
    event PublicGoodAdded(address indexed project);
    event PublicGoodRemoved(address indexed project);

    function setUp() public {
        owner = address(this);
        vault = address(0x123);
        publicGood1 = address(0x456);
        publicGood2 = address(0x789);
        octantSplitter = address(0xABC);

        stETH = new MockERC20();
        distributor = new FixedYieldDistributor(address(stETH));

        // Transfer some stETH to vault for testing
        stETH.transfer(vault, 100000 ether);
    }

    function testInitialState() public {
        assertEq(address(distributor.stETH()), address(stETH));
        assertEq(distributor.totalYieldCollected(), 0);
        assertEq(distributor.totalYieldDistributed(), 0);
        assertEq(distributor.getPublicGoodsProjectsCount(), 0);
        assertEq(distributor.getYieldHistoryCount(), 0);
    }

    function testReceiveYield() public {
        uint256 yieldAmount = 10 ether;

        // Transfer yield to distributor
        vm.prank(vault);
        stETH.transfer(address(distributor), yieldAmount);

        vm.expectEmit(false, false, false, true);
        emit YieldReceived(yieldAmount, block.timestamp);

        distributor.receiveYield(yieldAmount);

        assertEq(distributor.totalYieldCollected(), yieldAmount);
        assertEq(distributor.getYieldHistoryCount(), 1);
        assertEq(distributor.getAvailableYield(), yieldAmount);
    }

    function testCannotReceiveZeroYield() public {
        vm.expectRevert("Amount must be > 0");
        distributor.receiveYield(0);
    }

    function testAddPublicGoodsProject() public {
        vm.expectEmit(true, false, false, false);
        emit PublicGoodAdded(publicGood1);

        distributor.addPublicGoodsProject(publicGood1);

        assertEq(distributor.getPublicGoodsProjectsCount(), 1);
        assertTrue(distributor.isPublicGoodsProject(publicGood1));
    }

    function testCannotAddZeroAddressProject() public {
        vm.expectRevert("Invalid project address");
        distributor.addPublicGoodsProject(address(0));
    }

    function testCannotAddDuplicateProject() public {
        distributor.addPublicGoodsProject(publicGood1);

        vm.expectRevert("Project already exists");
        distributor.addPublicGoodsProject(publicGood1);
    }

    function testRemovePublicGoodsProject() public {
        distributor.addPublicGoodsProject(publicGood1);
        distributor.addPublicGoodsProject(publicGood2);

        assertEq(distributor.getPublicGoodsProjectsCount(), 2);

        vm.expectEmit(true, false, false, false);
        emit PublicGoodRemoved(publicGood1);

        distributor.removePublicGoodsProject(publicGood1);

        assertEq(distributor.getPublicGoodsProjectsCount(), 1);
        assertFalse(distributor.isPublicGoodsProject(publicGood1));
        assertTrue(distributor.isPublicGoodsProject(publicGood2));
    }

    function testCannotRemoveNonexistentProject() public {
        vm.expectRevert("Project does not exist");
        distributor.removePublicGoodsProject(publicGood1);
    }

    function testSetOctantPaymentSplitter() public {
        vm.expectEmit(true, false, false, false);
        emit OctantSplitterUpdated(octantSplitter);

        distributor.setOctantPaymentSplitter(octantSplitter);

        assertEq(distributor.octantPaymentSplitter(), octantSplitter);
    }

    function testCannotSetZeroAddressSplitter() public {
        vm.expectRevert("Invalid splitter address");
        distributor.setOctantPaymentSplitter(address(0));
    }

    function testDistributeToPublicGoodsDirectly() public {
        // Add public goods projects
        distributor.addPublicGoodsProject(publicGood1);
        distributor.addPublicGoodsProject(publicGood2);

        // Receive yield
        uint256 yieldAmount = 100 ether;
        vm.prank(vault);
        stETH.transfer(address(distributor), yieldAmount);
        distributor.receiveYield(yieldAmount);

        // Distribute
        uint256 balanceBefore1 = stETH.balanceOf(publicGood1);
        uint256 balanceBefore2 = stETH.balanceOf(publicGood2);

        distributor.distributeToPublicGoods();

        uint256 expectedPerProject = yieldAmount / 2;
        assertEq(stETH.balanceOf(publicGood1) - balanceBefore1, expectedPerProject);
        assertEq(stETH.balanceOf(publicGood2) - balanceBefore2, expectedPerProject);
        assertEq(distributor.totalYieldDistributed(), yieldAmount);
        assertEq(distributor.getAvailableYield(), 0);
    }

    function testDistributeViaOctantSplitter() public {
        // Set Octant splitter
        distributor.setOctantPaymentSplitter(octantSplitter);

        // Receive yield
        uint256 yieldAmount = 100 ether;
        vm.prank(vault);
        stETH.transfer(address(distributor), yieldAmount);
        distributor.receiveYield(yieldAmount);

        // Distribute
        uint256 balanceBefore = stETH.balanceOf(octantSplitter);

        vm.expectEmit(true, false, false, true);
        emit YieldDistributed(octantSplitter, yieldAmount);

        distributor.distributeToPublicGoods();

        assertEq(stETH.balanceOf(octantSplitter) - balanceBefore, yieldAmount);
        assertEq(distributor.totalYieldDistributed(), yieldAmount);
    }

    function testCannotDistributeWithNoYield() public {
        distributor.addPublicGoodsProject(publicGood1);

        vm.expectRevert("No yield to distribute");
        distributor.distributeToPublicGoods();
    }

    function testCannotDistributeWithNoProjects() public {
        // Receive yield
        uint256 yieldAmount = 100 ether;
        vm.prank(vault);
        stETH.transfer(address(distributor), yieldAmount);
        distributor.receiveYield(yieldAmount);

        vm.expectRevert("No public goods projects");
        distributor.distributeToPublicGoods();
    }

    function testGetFixedYieldRate() public {
        // Initially zero
        assertEq(distributor.getFixedYieldRate(), 0);

        // Add some yield events
        vm.prank(vault);
        stETH.transfer(address(distributor), 10 ether);
        distributor.receiveYield(10 ether);

        vm.warp(block.timestamp + 30 days);

        vm.prank(vault);
        stETH.transfer(address(distributor), 10 ether);
        distributor.receiveYield(10 ether);

        // Should have a rate now
        uint256 rate = distributor.getFixedYieldRate();
        assertGt(rate, 0);
    }

    function testGetYieldHistory() public {
        // Add multiple yield events
        for (uint256 i = 1; i <= 5; i++) {
            vm.prank(vault);
            stETH.transfer(address(distributor), i * 1 ether);
            distributor.receiveYield(i * 1 ether);

            vm.warp(block.timestamp + 10 days);
        }

        assertEq(distributor.getYieldHistoryCount(), 5);

        // Get history range
        FixedYieldDistributor.YieldEvent[] memory events =
            distributor.getYieldHistory(0, 3);

        assertEq(events.length, 3);
        assertEq(events[0].amount, 1 ether);
        assertEq(events[1].amount, 2 ether);
        assertEq(events[2].amount, 3 ether);
    }

    function testCannotGetInvalidYieldHistoryRange() public {
        vm.prank(vault);
        stETH.transfer(address(distributor), 10 ether);
        distributor.receiveYield(10 ether);

        vm.expectRevert("Invalid end index");
        distributor.getYieldHistory(0, 10);

        vm.expectRevert("Invalid range");
        distributor.getYieldHistory(1, 0);
    }

    function testGetPredictedYield() public {
        // Initially zero
        assertEq(distributor.getPredictedYield(30 days), 0);

        // Add some yield events with consistent timing
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(vault);
            stETH.transfer(address(distributor), 10 ether);
            distributor.receiveYield(10 ether);

            vm.warp(block.timestamp + 30 days);
        }

        // Predict yield for next 30 days
        uint256 predicted = distributor.getPredictedYield(30 days);
        assertGt(predicted, 0);
        // Should be around 10 ether based on recent average
        assertApproxEqRel(predicted, 10 ether, 0.5e18); // 50% tolerance
    }

    function testGetAllPublicGoodsProjects() public {
        distributor.addPublicGoodsProject(publicGood1);
        distributor.addPublicGoodsProject(publicGood2);

        address[] memory projects = distributor.getAllPublicGoodsProjects();
        assertEq(projects.length, 2);
        assertEq(projects[0], publicGood1);
        assertEq(projects[1], publicGood2);
    }

    function testEmergencyWithdraw() public {
        uint256 amount = 50 ether;
        vm.prank(vault);
        stETH.transfer(address(distributor), amount);

        uint256 ownerBalanceBefore = stETH.balanceOf(owner);

        distributor.emergencyWithdraw(address(stETH), amount);

        assertEq(stETH.balanceOf(owner) - ownerBalanceBefore, amount);
    }

    function testOnlyOwnerCanReceiveYield() public {
        // Actually anyone can call receiveYield, no access control
        // This is intentional as the vault calls it
        vm.prank(vault);
        stETH.transfer(address(distributor), 10 ether);

        vm.prank(address(0x999));
        distributor.receiveYield(10 ether);

        assertEq(distributor.totalYieldCollected(), 10 ether);
    }

    function testOnlyOwnerCanDistribute() public {
        distributor.addPublicGoodsProject(publicGood1);

        vm.prank(vault);
        stETH.transfer(address(distributor), 10 ether);
        distributor.receiveYield(10 ether);

        vm.prank(address(0x999));
        vm.expectRevert();
        distributor.distributeToPublicGoods();
    }

    function testOnlyOwnerCanAddProject() public {
        vm.prank(address(0x999));
        vm.expectRevert();
        distributor.addPublicGoodsProject(publicGood1);
    }

    function testOnlyOwnerCanRemoveProject() public {
        distributor.addPublicGoodsProject(publicGood1);

        vm.prank(address(0x999));
        vm.expectRevert();
        distributor.removePublicGoodsProject(publicGood1);
    }

    function testOnlyOwnerCanSetSplitter() public {
        vm.prank(address(0x999));
        vm.expectRevert();
        distributor.setOctantPaymentSplitter(octantSplitter);
    }

    function testMultipleDistributions() public {
        distributor.addPublicGoodsProject(publicGood1);

        // First distribution
        vm.prank(vault);
        stETH.transfer(address(distributor), 50 ether);
        distributor.receiveYield(50 ether);
        distributor.distributeToPublicGoods();

        assertEq(distributor.totalYieldDistributed(), 50 ether);

        // Second distribution
        vm.prank(vault);
        stETH.transfer(address(distributor), 30 ether);
        distributor.receiveYield(30 ether);
        distributor.distributeToPublicGoods();

        assertEq(distributor.totalYieldCollected(), 80 ether);
        assertEq(distributor.totalYieldDistributed(), 80 ether);
        assertEq(distributor.getAvailableYield(), 0);
    }

    function testPublicGoodsAllocationTracking() public {
        distributor.addPublicGoodsProject(publicGood1);
        distributor.addPublicGoodsProject(publicGood2);

        vm.prank(vault);
        stETH.transfer(address(distributor), 100 ether);
        distributor.receiveYield(100 ether);
        distributor.distributeToPublicGoods();

        assertEq(distributor.publicGoodsAllocations(publicGood1), 50 ether);
        assertEq(distributor.publicGoodsAllocations(publicGood2), 50 ether);
    }

    function testFuzzReceiveYield(uint256 amount) public {
        amount = bound(amount, 1, 1000000 ether);

        vm.prank(vault);
        stETH.mint(address(distributor), amount);

        distributor.receiveYield(amount);

        assertEq(distributor.totalYieldCollected(), amount);
        assertEq(distributor.getAvailableYield(), amount);
    }
}
