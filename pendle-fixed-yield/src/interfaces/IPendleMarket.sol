// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IPendleMarket {
    /// @notice Get the expiry date of the market
    /// @return The expiry timestamp
    function expiry() external view returns (uint256);

    /// @notice Read token addresses from the market
    /// @dev Returns (SY, PT, YT) in that order
    /// @return sy The SY token address
    /// @return pt The PT token address
    /// @return yt The YT token address
    function readTokens() external view returns (address sy, address pt, address yt);

    /// @notice Check if market is expired
    /// @return True if expired
    function isExpired() external view returns (bool);

    /// @notice Get the reserves of the market
    /// @return totalPt Total PT in the market
    /// @return totalSy Total SY in the market
    function getReserves() external view returns (uint256 totalPt, uint256 totalSy);

    /// @notice Read state of the market
    /// @return marketState The market state
    function readState(address router) external view returns (MarketState memory marketState);
}

struct MarketState {
    int256 totalPt;
    int256 totalSy;
    int256 totalLp;
    address treasury;
    int256 scalarRoot;
    uint256 expiry;
    uint256 lnFeeRateRoot;
    uint256 reserveFeePercent;
    uint256 lastLnImpliedRate;
}
