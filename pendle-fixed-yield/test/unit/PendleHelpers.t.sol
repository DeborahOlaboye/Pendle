// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../../src/libraries/PendleHelpers.sol";
import "@pendle/interfaces/IPMarket.sol";

// Simple mock that implements minimal IPMarket interface for testing
contract MockPendleMarket {
    uint256 public expiry;
    address public PT;
    address public YT;
    address public SY;
    bool public isExpired;
    uint256 private totalPt;
    uint256 private totalSy;

    constructor(
        uint256 _expiry,
        address _PT,
        address _YT,
        address _SY,
        uint256 _totalPt,
        uint256 _totalSy
    ) {
        expiry = _expiry;
        PT = _PT;
        YT = _YT;
        SY = _SY;
        totalPt = _totalPt;
        totalSy = _totalSy;
        isExpired = false;
    }

    function readTokens() external view returns (IStandardizedYield, IPPrincipalToken, IPYieldToken) {
        return (IStandardizedYield(SY), IPPrincipalToken(PT), IPYieldToken(YT));
    }

    function getReserves() external view returns (uint256, uint256) {
        return (totalPt, totalSy);
    }

    function readState(address) external view returns (MarketState memory) {
        return MarketState({
            totalPt: int256(totalPt),
            totalSy: int256(totalSy),
            totalLp: 0,
            treasury: address(0),
            scalarRoot: 0,
            expiry: expiry,
            lnFeeRateRoot: 0,
            reserveFeePercent: 0,
            lastLnImpliedRate: 0
        });
    }

    function setExpired(bool _expired) external {
        isExpired = _expired;
    }
}

contract PendleHelpersTest is Test {
    using PendleHelpers for *;

    MockPendleMarket public market1;
    MockPendleMarket public market2;
    MockPendleMarket public market3;

    address constant PT_1 = address(0x1);
    address constant YT_1 = address(0x2);
    address constant SY_1 = address(0x3);

    function setUp() public {
        // Market with good liquidity, 6 months maturity
        market1 = new MockPendleMarket(
            block.timestamp + 180 days,
            PT_1,
            YT_1,
            SY_1,
            1000 ether,
            1000 ether
        );

        // Market with lower liquidity, 12 months maturity
        market2 = new MockPendleMarket(
            block.timestamp + 365 days,
            PT_1,
            YT_1,
            SY_1,
            500 ether,
            500 ether
        );

        // Market with high liquidity, 3 months maturity
        market3 = new MockPendleMarket(
            block.timestamp + 90 days,
            PT_1,
            YT_1,
            SY_1,
            2000 ether,
            2000 ether
        );
    }

    function testCalculateYTValue() public {
        uint256 ytAmount = 100 ether;
        uint256 expectedValue = PendleHelpers.calculateYTValue(
            address(market1),
            ytAmount
        );

        // With 1000 PT and 1000 SY, YT value should be:
        // (ytAmount * totalSy) / (totalPt + totalSy)
        // (100 * 1000) / 2000 = 50
        assertEq(expectedValue, 50 ether);
    }

    function testCalculateYTValueZeroReserves() public {
        MockPendleMarket emptyMarket = new MockPendleMarket(
            block.timestamp + 180 days,
            PT_1,
            YT_1,
            SY_1,
            0,
            0
        );

        uint256 value = PendleHelpers.calculateYTValue(
            address(emptyMarket),
            100 ether
        );
        assertEq(value, 0);
    }

    function testSelectOptimalMaturity() public {
        address[] memory markets = new address[](3);
        markets[0] = address(market1);
        markets[1] = address(market2);
        markets[2] = address(market3);

        (address bestMarket, uint256 maturity) = PendleHelpers
            .selectOptimalMaturity(markets);

        // Should prefer market with good liquidity and reasonable maturity
        // Market1 has good liquidity and 6-month maturity (close to optimal 9 months)
        assertTrue(bestMarket != address(0));
        assertGt(maturity, block.timestamp);
    }

    function testSelectOptimalMaturitySkipsExpired() public {
        market1.setExpired(true);

        address[] memory markets = new address[](2);
        markets[0] = address(market1);
        markets[1] = address(market2);

        (address bestMarket,) = PendleHelpers.selectOptimalMaturity(markets);

        // Should skip expired market1 and select market2
        assertEq(bestMarket, address(market2));
    }

    function testSelectOptimalMaturityRevertsWithNoMarkets() public {
        address[] memory markets = new address[](0);

        vm.expectRevert("No markets available");
        PendleHelpers.selectOptimalMaturity(markets);
    }

    function testSelectOptimalMaturityRevertsWhenAllExpired() public {
        market1.setExpired(true);
        market2.setExpired(true);

        address[] memory markets = new address[](2);
        markets[0] = address(market1);
        markets[1] = address(market2);

        vm.expectRevert("No suitable market found");
        PendleHelpers.selectOptimalMaturity(markets);
    }

    function testCalculateMarketScore() public {
        uint256 liquidity = 2000 ether;
        uint256 timeToMaturity = 270 days; // 9 months (optimal)
        uint256 maturity = block.timestamp + timeToMaturity;

        uint256 score = PendleHelpers.calculateMarketScore(
            liquidity,
            timeToMaturity,
            maturity
        );

        assertGt(score, 0);

        // Market closer to optimal time should have higher score
        uint256 score2 = PendleHelpers.calculateMarketScore(
            liquidity,
            30 days,
            block.timestamp + 30 days
        );

        // 9-month maturity should score better than 1-month
        assertGt(score, score2);
    }

    function testCalculateFixedRate() public {
        uint256 ytSaleProceeds = 10 ether;
        uint256 principal = 100 ether;
        uint256 timeToMaturity = 180 days;

        uint256 annualizedRate = PendleHelpers.calculateFixedRate(
            ytSaleProceeds,
            principal,
            timeToMaturity
        );

        // Rate should be: (10/100) * (365 days / 180 days) * 10000
        // = 0.1 * 2.027 * 10000 = ~2027 bps = ~20.27%
        assertGt(annualizedRate, 1800); // ~18%
        assertLt(annualizedRate, 2200); // ~22%
    }

    function testCalculateFixedRateZeroPrincipal() public {
        uint256 rate = PendleHelpers.calculateFixedRate(10 ether, 0, 180 days);
        assertEq(rate, 0);
    }

    function testCalculateFixedRateZeroTime() public {
        uint256 rate = PendleHelpers.calculateFixedRate(10 ether, 100 ether, 0);
        assertEq(rate, 0);
    }

    function testCalculateMinOutput() public {
        uint256 amount = 100 ether;
        uint256 slippageBps = 100; // 1%

        uint256 minOutput = PendleHelpers.calculateMinOutput(
            amount,
            slippageBps
        );

        // Should be 99% of input
        assertEq(minOutput, 99 ether);
    }

    function testCalculateMinOutputMaxSlippage() public {
        uint256 amount = 100 ether;
        uint256 slippageBps = 1000; // 10%

        uint256 minOutput = PendleHelpers.calculateMinOutput(
            amount,
            slippageBps
        );

        assertEq(minOutput, 90 ether);
    }

    function testCalculateMinOutputRevertsOnInvalidSlippage() public {
        vm.expectRevert("Invalid slippage");
        PendleHelpers.calculateMinOutput(100 ether, 10001);
    }

    function testCalculateLadderAllocations() public {
        uint256 totalAmount = 1000 ether;
        uint256[] memory maturities = new uint256[](3);
        maturities[0] = block.timestamp + 180 days;
        maturities[1] = block.timestamp + 270 days;
        maturities[2] = block.timestamp + 365 days;

        uint256[] memory allocations = PendleHelpers.calculateLadderAllocations(
            totalAmount,
            maturities
        );

        assertEq(allocations.length, 3);

        // Should distribute equally (with remainder to first)
        uint256 expectedPerMaturity = totalAmount / 3;

        assertGe(allocations[0], expectedPerMaturity);
        assertEq(allocations[1], expectedPerMaturity);
        assertEq(allocations[2], expectedPerMaturity);

        // Total should equal input
        uint256 total = 0;
        for (uint256 i = 0; i < allocations.length; i++) {
            total += allocations[i];
        }
        assertEq(total, totalAmount);
    }

    function testCalculateLadderAllocationsRevertsWithNoMaturities() public {
        uint256[] memory maturities = new uint256[](0);

        vm.expectRevert("No maturities provided");
        PendleHelpers.calculateLadderAllocations(1000 ether, maturities);
    }

    function testHasSufficientLiquidity() public {
        // Market1 has 2000 ether total liquidity (1000 PT + 1000 SY)
        // Required amount is 100 ether
        // Should need at least 1000 ether (10x) liquidity
        assertTrue(
            PendleHelpers.hasSufficientLiquidity(address(market1), 100 ether)
        );

        // Should fail if requiring too much
        assertFalse(
            PendleHelpers.hasSufficientLiquidity(address(market1), 300 ether)
        );
    }

    function testEstimateGasCost() public {
        // Deposit operation
        uint256 depositGas = PendleHelpers.estimateGasCost(0);
        assertEq(depositGas, 300000);

        // Withdrawal operation
        uint256 withdrawGas = PendleHelpers.estimateGasCost(1);
        assertEq(withdrawGas, 250000);

        // YT split and sale
        uint256 splitGas = PendleHelpers.estimateGasCost(2);
        assertEq(splitGas, 400000);

        // Other operation
        uint256 otherGas = PendleHelpers.estimateGasCost(999);
        assertEq(otherGas, 200000);
    }

    function testCalculateTimeWeightedYield() public {
        uint256[] memory amounts = new uint256[](4);
        uint256[] memory timestamps = new uint256[](4);

        amounts[0] = 10 ether;
        amounts[1] = 12 ether;
        amounts[2] = 11 ether;
        amounts[3] = 13 ether;

        timestamps[0] = 1000;
        timestamps[1] = 2000;
        timestamps[2] = 3000;
        timestamps[3] = 4000;

        uint256 weightedYield = PendleHelpers.calculateTimeWeightedYield(
            amounts,
            timestamps
        );

        // Weighted calculation:
        // (12 * 1000 + 11 * 1000 + 13 * 1000) / 3000
        // = 36000 / 3000 = 12
        assertEq(weightedYield, 12 ether);
    }

    function testCalculateTimeWeightedYieldSingleValue() public {
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory timestamps = new uint256[](1);

        amounts[0] = 10 ether;
        timestamps[0] = 1000;

        uint256 weightedYield = PendleHelpers.calculateTimeWeightedYield(
            amounts,
            timestamps
        );

        assertEq(weightedYield, 10 ether);
    }

    function testCalculateTimeWeightedYieldRevertsOnMismatch() public {
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory timestamps = new uint256[](3);

        vm.expectRevert("Array length mismatch");
        PendleHelpers.calculateTimeWeightedYield(amounts, timestamps);
    }

    function testCalculateTimeWeightedYieldRevertsOnEmpty() public {
        uint256[] memory amounts = new uint256[](0);
        uint256[] memory timestamps = new uint256[](0);

        vm.expectRevert("Empty arrays");
        PendleHelpers.calculateTimeWeightedYield(amounts, timestamps);
    }

    function testFuzzCalculateMinOutput(uint256 amount, uint256 slippageBps)
        public
    {
        amount = bound(amount, 1, 1000000 ether);
        slippageBps = bound(slippageBps, 0, 10000);

        uint256 minOutput = PendleHelpers.calculateMinOutput(
            amount,
            slippageBps
        );

        assertLe(minOutput, amount);
        assertEq(minOutput, (amount * (10000 - slippageBps)) / 10000);
    }

    function testFuzzCalculateFixedRate(
        uint256 proceeds,
        uint256 principal,
        uint256 timeToMaturity
    ) public {
        proceeds = bound(proceeds, 1, 1000 ether);
        principal = bound(principal, 1, 10000 ether);
        timeToMaturity = bound(timeToMaturity, 1 days, 1000 days);

        uint256 rate = PendleHelpers.calculateFixedRate(
            proceeds,
            principal,
            timeToMaturity
        );

        // Rate should be reasonable (0-1000% APY)
        assertLe(rate, 100000); // 1000% max
    }
}
