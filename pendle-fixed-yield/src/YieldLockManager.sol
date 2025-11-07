// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title YieldLockManager
/// @notice Manages PT (Principal Token) positions and tracks maturities
/// @dev Tracks all locked PT positions, their maturity dates, and redemption status
contract YieldLockManager is Ownable {
    /// @notice PT position structure
    struct PTPosition {
        address ptToken;        // PT token address
        uint256 amount;         // Amount of PT locked
        uint256 maturity;       // Maturity timestamp
        bool redeemed;          // Redemption status
        uint256 depositedAt;    // Deposit timestamp
    }

    // Position tracking
    mapping(uint256 => PTPosition) public positions;
    uint256 public positionCount;

    // Maturity tracking
    uint256[] public maturities;
    mapping(uint256 => uint256) public totalPTByMaturity;
    mapping(uint256 => bool) public maturityExists;

    // Events
    event PositionAdded(
        uint256 indexed positionId,
        address indexed ptToken,
        uint256 amount,
        uint256 maturity
    );
    event PositionRedeemed(uint256 indexed positionId, uint256 timestamp);
    event MaturityAdded(uint256 maturity);

    constructor() Ownable(msg.sender) {}

    /// @notice Add a new PT position
    /// @param ptToken PT token address
    /// @param amount Amount of PT
    /// @param maturity Maturity timestamp
    /// @return positionId The ID of the created position
    function addPosition(
        address ptToken,
        uint256 amount,
        uint256 maturity
    ) external onlyOwner returns (uint256 positionId) {
        require(ptToken != address(0), "Invalid PT token");
        require(amount > 0, "Amount must be > 0");
        require(maturity > block.timestamp, "Maturity must be in future");

        positionId = positionCount++;

        positions[positionId] = PTPosition({
            ptToken: ptToken,
            amount: amount,
            maturity: maturity,
            redeemed: false,
            depositedAt: block.timestamp
        });

        // Track maturity
        if (!maturityExists[maturity]) {
            maturities.push(maturity);
            maturityExists[maturity] = true;
            emit MaturityAdded(maturity);
        }

        totalPTByMaturity[maturity] += amount;

        emit PositionAdded(positionId, ptToken, amount, maturity);
    }

    /// @notice Mark a position as redeemed
    /// @param positionId Position ID to mark as redeemed
    function markRedeemed(uint256 positionId) external onlyOwner {
        require(positionId < positionCount, "Invalid position ID");
        require(!positions[positionId].redeemed, "Already redeemed");
        require(
            block.timestamp >= positions[positionId].maturity,
            "Not matured yet"
        );

        positions[positionId].redeemed = true;

        // Update maturity tracking
        uint256 maturity = positions[positionId].maturity;
        totalPTByMaturity[maturity] -= positions[positionId].amount;

        emit PositionRedeemed(positionId, block.timestamp);
    }

    /// @notice Get all matured positions
    /// @return ptTokens Array of PT token addresses
    /// @return amounts Array of amounts
    /// @return maturityDates Array of maturity dates
    function getMaturedPositions()
        external
        view
        returns (
            address[] memory ptTokens,
            uint256[] memory amounts,
            uint256[] memory maturityDates
        )
    {
        // First count matured positions
        uint256 maturedCount = 0;
        for (uint256 i = 0; i < positionCount; i++) {
            if (
                block.timestamp >= positions[i].maturity &&
                !positions[i].redeemed
            ) {
                maturedCount++;
            }
        }

        // Allocate arrays
        ptTokens = new address[](maturedCount);
        amounts = new uint256[](maturedCount);
        maturityDates = new uint256[](maturedCount);

        // Fill arrays
        uint256 index = 0;
        for (uint256 i = 0; i < positionCount; i++) {
            if (
                block.timestamp >= positions[i].maturity &&
                !positions[i].redeemed
            ) {
                ptTokens[index] = positions[i].ptToken;
                amounts[index] = positions[i].amount;
                maturityDates[index] = positions[i].maturity;
                index++;
            }
        }
    }

    /// @notice Get upcoming maturities within next N days
    /// @param daysAhead Number of days to look ahead
    /// @return upcomingMaturities Array of upcoming maturity timestamps
    function getUpcomingMaturities(uint256 daysAhead)
        external
        view
        returns (uint256[] memory upcomingMaturities)
    {
        uint256 deadline = block.timestamp + (daysAhead * 1 days);

        // Count upcoming maturities
        uint256 count = 0;
        for (uint256 i = 0; i < maturities.length; i++) {
            if (
                maturities[i] > block.timestamp &&
                maturities[i] <= deadline &&
                totalPTByMaturity[maturities[i]] > 0
            ) {
                count++;
            }
        }

        // Fill array
        upcomingMaturities = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < maturities.length; i++) {
            if (
                maturities[i] > block.timestamp &&
                maturities[i] <= deadline &&
                totalPTByMaturity[maturities[i]] > 0
            ) {
                upcomingMaturities[index] = maturities[i];
                index++;
            }
        }
    }

    /// @notice Get all positions for a specific maturity
    /// @param maturity Maturity timestamp
    /// @return positionIds Array of position IDs
    function getPositionsByMaturity(uint256 maturity)
        external
        view
        returns (uint256[] memory positionIds)
    {
        // Count positions with this maturity
        uint256 count = 0;
        for (uint256 i = 0; i < positionCount; i++) {
            if (positions[i].maturity == maturity) {
                count++;
            }
        }

        // Fill array
        positionIds = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < positionCount; i++) {
            if (positions[i].maturity == maturity) {
                positionIds[index] = i;
                index++;
            }
        }
    }

    /// @notice Calculate total value locked in PT tokens
    /// @return total Total value locked
    function getTotalLockedValue() external view returns (uint256 total) {
        for (uint256 i = 0; i < positionCount; i++) {
            if (!positions[i].redeemed) {
                total += positions[i].amount;
            }
        }
    }

    /// @notice Calculate amount that can be redeemed
    /// @return redeemable Amount that can be redeemed
    function calculateRedeemableAmount()
        external
        view
        returns (uint256 redeemable)
    {
        for (uint256 i = 0; i < positionCount; i++) {
            if (
                block.timestamp >= positions[i].maturity &&
                !positions[i].redeemed
            ) {
                redeemable += positions[i].amount;
            }
        }
    }

    /// @notice Get position details
    /// @param positionId Position ID
    /// @return position The position details
    function getPosition(uint256 positionId)
        external
        view
        returns (PTPosition memory position)
    {
        require(positionId < positionCount, "Invalid position ID");
        return positions[positionId];
    }

    /// @notice Get total number of maturities
    /// @return count Number of unique maturities
    function getMaturitiesCount() external view returns (uint256 count) {
        return maturities.length;
    }

    /// @notice Get all maturity dates
    /// @return allMaturities Array of all maturity timestamps
    function getAllMaturities()
        external
        view
        returns (uint256[] memory allMaturities)
    {
        return maturities;
    }

    /// @notice Get total PT amount for a specific maturity
    /// @param maturity Maturity timestamp
    /// @return amount Total PT amount for this maturity
    function getTotalPTForMaturity(uint256 maturity)
        external
        view
        returns (uint256 amount)
    {
        return totalPTByMaturity[maturity];
    }
}
