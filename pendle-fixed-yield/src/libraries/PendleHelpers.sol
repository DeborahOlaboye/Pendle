// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../interfaces/IPendleMarket.sol";

/// @title PendleHelpers
/// @notice Helper library for Pendle-related calculations
library PendleHelpers {
    uint256 constant SECONDS_PER_YEAR = 365 days;
    uint256 constant BASIS_POINTS = 10000;

    /// @notice Calculate expected YT value from market
    /// @param market Pendle market address
    /// @param ytAmount Amount of YT tokens
    /// @return expectedValue Expected value in underlying tokens
    function calculateYTValue(address market, uint256 ytAmount)
        internal
        view
        returns (uint256 expectedValue)
    {
        // Get market reserves
        (uint256 totalPt, uint256 totalSy) = IPendleMarket(market).getReserves();

        if (totalPt == 0 || totalSy == 0) return 0;

        // Simple estimate: YT value based on PT/SY ratio
        // In production, should use Pendle's pricing oracle
        expectedValue = (ytAmount * totalSy) / (totalPt + totalSy);
    }

    /// @notice Select optimal maturity date from available markets
    /// @param availableMarkets Array of available Pendle market addresses
    /// @return bestMarket Address of the best market
    /// @return maturity Maturity timestamp of the best market
    function selectOptimalMaturity(address[] memory availableMarkets)
        internal
        view
        returns (address bestMarket, uint256 maturity)
    {
        require(availableMarkets.length > 0, "No markets available");

        uint256 bestScore = 0;

        for (uint256 i = 0; i < availableMarkets.length; i++) {
            address market = availableMarkets[i];

            // Skip expired markets
            if (IPendleMarket(market).isExpired()) continue;

            uint256 marketMaturity = IPendleMarket(market).expiry();
            (uint256 totalPt, uint256 totalSy) = IPendleMarket(market)
                .getReserves();

            // Score based on liquidity and time to maturity
            uint256 liquidity = totalPt + totalSy;
            uint256 timeToMaturity = marketMaturity > block.timestamp
                ? marketMaturity - block.timestamp
                : 0;

            // Prefer markets with good liquidity and reasonable maturity (6-12 months)
            uint256 score = calculateMarketScore(
                liquidity,
                timeToMaturity,
                marketMaturity
            );

            if (score > bestScore) {
                bestScore = score;
                bestMarket = market;
                maturity = marketMaturity;
            }
        }

        require(bestMarket != address(0), "No suitable market found");
    }

    /// @notice Calculate market score for selection
    /// @param liquidity Total liquidity in the market
    /// @param timeToMaturity Time until maturity in seconds
    /// @param maturity Maturity timestamp
    /// @return score Market score
    function calculateMarketScore(
        uint256 liquidity,
        uint256 timeToMaturity,
        uint256 maturity
    ) internal pure returns (uint256 score) {
        // Prefer 6-12 month maturities
        uint256 optimalTime = 9 * 30 days; // 9 months
        uint256 timeDiff = timeToMaturity > optimalTime
            ? timeToMaturity - optimalTime
            : optimalTime - timeToMaturity;

        // Liquidity weight (higher is better)
        uint256 liquidityScore = liquidity / 1e18;

        // Time weight (closer to optimal is better)
        uint256 maxTimeDiff = 12 * 30 days;
        uint256 timeScore = timeDiff < maxTimeDiff
            ? (maxTimeDiff - timeDiff) / 1 days
            : 0;

        // Combined score
        score = liquidityScore + (timeScore * 100);
    }

    /// @notice Calculate fixed yield rate from YT sale
    /// @param ytSaleProceeds Proceeds from selling YT
    /// @param principal Principal amount invested
    /// @param timeToMaturity Time to maturity in seconds
    /// @return annualizedRate Annualized rate in basis points
    function calculateFixedRate(
        uint256 ytSaleProceeds,
        uint256 principal,
        uint256 timeToMaturity
    ) internal pure returns (uint256 annualizedRate) {
        if (principal == 0 || timeToMaturity == 0) return 0;

        // Calculate return: (proceeds / principal)
        uint256 returnBps = (ytSaleProceeds * BASIS_POINTS) / principal;

        // Annualize: (return * seconds_per_year / time_to_maturity)
        annualizedRate = (returnBps * SECONDS_PER_YEAR) / timeToMaturity;
    }

    /// @notice Calculate minimum output with slippage protection
    /// @param amount Input amount
    /// @param slippageBps Slippage tolerance in basis points
    /// @return minOutput Minimum output amount
    function calculateMinOutput(uint256 amount, uint256 slippageBps)
        internal
        pure
        returns (uint256 minOutput)
    {
        require(slippageBps <= BASIS_POINTS, "Invalid slippage");
        minOutput = (amount * (BASIS_POINTS - slippageBps)) / BASIS_POINTS;
    }

    /// @notice Calculate optimal split between multiple maturities
    /// @param totalAmount Total amount to split
    /// @param maturities Array of maturity timestamps
    /// @return allocations Array of allocation amounts
    function calculateLadderAllocations(
        uint256 totalAmount,
        uint256[] memory maturities
    ) internal view returns (uint256[] memory allocations) {
        require(maturities.length > 0, "No maturities provided");

        allocations = new uint256[](maturities.length);

        // Simple equal distribution for MVP
        // In production, weight by time to maturity and rates
        uint256 amountPerMaturity = totalAmount / maturities.length;

        for (uint256 i = 0; i < maturities.length; i++) {
            allocations[i] = amountPerMaturity;
        }

        // Handle remainder
        uint256 remainder = totalAmount - (amountPerMaturity * maturities.length);
        if (remainder > 0) {
            allocations[0] += remainder;
        }
    }

    /// @notice Check if market has sufficient liquidity
    /// @param market Market address
    /// @param requiredAmount Required liquidity amount
    /// @return hasSufficientLiquidity True if market has sufficient liquidity
    function hasSufficientLiquidity(address market, uint256 requiredAmount)
        internal
        view
        returns (bool)
    {
        (uint256 totalPt, uint256 totalSy) = IPendleMarket(market).getReserves();
        uint256 totalLiquidity = totalPt + totalSy;

        // Require liquidity to be at least 10x the required amount for safety
        return totalLiquidity >= (requiredAmount * 10);
    }

    /// @notice Estimate gas cost for operations
    /// @param operationType Type of operation (0=deposit, 1=withdraw, 2=split)
    /// @return estimatedGas Estimated gas cost
    function estimateGasCost(uint256 operationType)
        internal
        pure
        returns (uint256 estimatedGas)
    {
        if (operationType == 0) {
            // Deposit operation
            estimatedGas = 300000;
        } else if (operationType == 1) {
            // Withdrawal operation
            estimatedGas = 250000;
        } else if (operationType == 2) {
            // YT split and sale
            estimatedGas = 400000;
        } else {
            estimatedGas = 200000;
        }
    }

    /// @notice Calculate time-weighted yield
    /// @param amounts Array of yield amounts
    /// @param timestamps Array of timestamps
    /// @return weightedYield Time-weighted average yield
    function calculateTimeWeightedYield(
        uint256[] memory amounts,
        uint256[] memory timestamps
    ) internal pure returns (uint256 weightedYield) {
        require(amounts.length == timestamps.length, "Array length mismatch");
        require(amounts.length > 0, "Empty arrays");

        if (amounts.length == 1) return amounts[0];

        uint256 totalWeighted = 0;
        uint256 totalTime = 0;

        for (uint256 i = 1; i < amounts.length; i++) {
            uint256 timeDiff = timestamps[i] - timestamps[i - 1];
            totalWeighted += amounts[i] * timeDiff;
            totalTime += timeDiff;
        }

        if (totalTime > 0) {
            weightedYield = totalWeighted / totalTime;
        }
    }
}
