// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title FixedYieldDistributor
/// @notice Collects and distributes fixed yield to public goods projects
/// @dev Interfaces with Octant's payment splitter for public goods funding
contract FixedYieldDistributor is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // stETH token
    IERC20 public immutable stETH;

    // Octant integration
    address public octantPaymentSplitter;

    // Yield tracking
    uint256 public totalYieldCollected;
    uint256 public totalYieldDistributed;

    // Public goods allocations
    mapping(address => uint256) public publicGoodsAllocations;
    address[] public publicGoodsProjects;

    // Yield history
    struct YieldEvent {
        uint256 amount;
        uint256 timestamp;
        uint256 annualizedRate;
    }

    YieldEvent[] public yieldHistory;

    // Events
    event YieldReceived(uint256 amount, uint256 timestamp);
    event YieldDistributed(address indexed recipient, uint256 amount);
    event OctantSplitterUpdated(address indexed newSplitter);
    event PublicGoodAdded(address indexed project);
    event PublicGoodRemoved(address indexed project);

    /// @notice Constructor
    /// @param _stETH stETH token address
    constructor(address _stETH) Ownable(msg.sender) {
        require(_stETH != address(0), "Invalid stETH address");
        stETH = IERC20(_stETH);
    }

    /// @notice Receive yield from the vault
    /// @param amount Amount of yield received
    function receiveYield(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");

        totalYieldCollected += amount;

        // Calculate annualized rate (simplified)
        uint256 annualizedRate = 0;
        if (yieldHistory.length > 0) {
            // Simple calculation based on recent yields
            annualizedRate = calculateAnnualizedRate(amount);
        }

        // Record yield event
        yieldHistory.push(
            YieldEvent({
                amount: amount,
                timestamp: block.timestamp,
                annualizedRate: annualizedRate
            })
        );

        emit YieldReceived(amount, block.timestamp);
    }

    /// @notice Calculate annualized rate based on recent yield
    /// @param currentYield Current yield amount
    /// @return rate Annualized rate in basis points
    function calculateAnnualizedRate(uint256 currentYield)
        internal
        view
        returns (uint256 rate)
    {
        // Simplified calculation
        // In production, this should account for principal, time periods, etc.
        if (yieldHistory.length > 0) {
            uint256 lastYield = yieldHistory[yieldHistory.length - 1].amount;
            uint256 timeDiff = block.timestamp -
                yieldHistory[yieldHistory.length - 1].timestamp;

            if (timeDiff > 0 && lastYield > 0) {
                // Annualize: (yield / time) * seconds_in_year / principal
                // For now, return a simple estimate
                rate = (currentYield * 365 days * 10000) / (timeDiff * lastYield);
            }
        }
    }

    /// @notice Distribute yield to public goods projects
    function distributeToPublicGoods() external nonReentrant onlyOwner {
        uint256 availableYield = totalYieldCollected - totalYieldDistributed;
        require(availableYield > 0, "No yield to distribute");

        if (octantPaymentSplitter != address(0)) {
            // Distribute via Octant payment splitter
            stETH.safeTransfer(octantPaymentSplitter, availableYield);
            totalYieldDistributed += availableYield;
            emit YieldDistributed(octantPaymentSplitter, availableYield);
        } else {
            // Distribute directly to public goods projects
            require(
                publicGoodsProjects.length > 0,
                "No public goods projects"
            );

            uint256 amountPerProject = availableYield /
                publicGoodsProjects.length;

            for (uint256 i = 0; i < publicGoodsProjects.length; i++) {
                address project = publicGoodsProjects[i];
                stETH.safeTransfer(project, amountPerProject);
                publicGoodsAllocations[project] += amountPerProject;
                totalYieldDistributed += amountPerProject;
                emit YieldDistributed(project, amountPerProject);
            }
        }
    }

    /// @notice Set Octant payment splitter address
    /// @param _splitter Octant payment splitter address
    function setOctantPaymentSplitter(address _splitter) external onlyOwner {
        require(_splitter != address(0), "Invalid splitter address");
        octantPaymentSplitter = _splitter;
        emit OctantSplitterUpdated(_splitter);
    }

    /// @notice Add a public goods project
    /// @param project Project address
    function addPublicGoodsProject(address project) external onlyOwner {
        require(project != address(0), "Invalid project address");
        require(!isPublicGoodsProject(project), "Project already exists");

        publicGoodsProjects.push(project);
        emit PublicGoodAdded(project);
    }

    /// @notice Remove a public goods project
    /// @param project Project address
    function removePublicGoodsProject(address project) external onlyOwner {
        require(isPublicGoodsProject(project), "Project does not exist");

        for (uint256 i = 0; i < publicGoodsProjects.length; i++) {
            if (publicGoodsProjects[i] == project) {
                publicGoodsProjects[i] = publicGoodsProjects[
                    publicGoodsProjects.length - 1
                ];
                publicGoodsProjects.pop();
                emit PublicGoodRemoved(project);
                break;
            }
        }
    }

    /// @notice Check if address is a public goods project
    /// @param project Project address
    /// @return exists True if project exists
    function isPublicGoodsProject(address project)
        public
        view
        returns (bool exists)
    {
        for (uint256 i = 0; i < publicGoodsProjects.length; i++) {
            if (publicGoodsProjects[i] == project) {
                return true;
            }
        }
        return false;
    }

    /// @notice Get available yield to distribute
    /// @return available Available yield amount
    function getAvailableYield() external view returns (uint256 available) {
        return totalYieldCollected - totalYieldDistributed;
    }

    /// @notice Get fixed yield rate based on recent history
    /// @return rate Annualized rate in basis points
    function getFixedYieldRate() external view returns (uint256 rate) {
        if (yieldHistory.length == 0) return 0;

        // Return weighted average of recent rates
        uint256 count = yieldHistory.length > 5 ? 5 : yieldHistory.length;
        uint256 sum = 0;

        for (uint256 i = yieldHistory.length - count; i < yieldHistory.length; i++) {
            sum += yieldHistory[i].annualizedRate;
        }

        return sum / count;
    }

    /// @notice Get yield history
    /// @param startIndex Start index
    /// @param endIndex End index
    /// @return events Array of yield events
    function getYieldHistory(uint256 startIndex, uint256 endIndex)
        external
        view
        returns (YieldEvent[] memory events)
    {
        require(startIndex < yieldHistory.length, "Invalid start index");
        require(endIndex <= yieldHistory.length, "Invalid end index");
        require(startIndex < endIndex, "Invalid range");

        uint256 length = endIndex - startIndex;
        events = new YieldEvent[](length);

        for (uint256 i = 0; i < length; i++) {
            events[i] = yieldHistory[startIndex + i];
        }
    }

    /// @notice Get predicted yield for a timeframe
    /// @param timeframe Timeframe in seconds
    /// @return predicted Predicted yield amount
    function getPredictedYield(uint256 timeframe)
        external
        view
        returns (uint256 predicted)
    {
        if (yieldHistory.length == 0) return 0;

        // Simple prediction based on recent average
        uint256 recentAverage = 0;
        uint256 count = yieldHistory.length > 10 ? 10 : yieldHistory.length;

        for (uint256 i = yieldHistory.length - count; i < yieldHistory.length; i++) {
            recentAverage += yieldHistory[i].amount;
        }

        recentAverage = recentAverage / count;

        // Extrapolate based on timeframe
        if (count > 1) {
            uint256 avgTimeDiff = (yieldHistory[yieldHistory.length - 1].timestamp -
                yieldHistory[yieldHistory.length - count].timestamp) / (count - 1);

            if (avgTimeDiff > 0) {
                predicted = (recentAverage * timeframe) / avgTimeDiff;
            }
        }
    }

    /// @notice Get number of public goods projects
    /// @return count Number of projects
    function getPublicGoodsProjectsCount()
        external
        view
        returns (uint256 count)
    {
        return publicGoodsProjects.length;
    }

    /// @notice Get all public goods projects
    /// @return projects Array of project addresses
    function getAllPublicGoodsProjects()
        external
        view
        returns (address[] memory projects)
    {
        return publicGoodsProjects;
    }

    /// @notice Get yield history count
    /// @return count Number of yield events
    function getYieldHistoryCount() external view returns (uint256 count) {
        return yieldHistory.length;
    }

    /// @notice Emergency withdrawal
    /// @param token Token to withdraw
    /// @param amount Amount to withdraw
    function emergencyWithdraw(address token, uint256 amount)
        external
        onlyOwner
    {
        IERC20(token).safeTransfer(owner(), amount);
    }
}
