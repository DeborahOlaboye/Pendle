// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStETH is IERC20 {
    /// @notice Submit ETH to the pool and mint stETH
    /// @param _referral Optional referral address
    /// @return The amount of stETH minted
    function submit(address _referral) external payable returns (uint256);

    /// @notice Get the amount of ETH controlled by the system
    /// @return Total pooled ETH
    function getTotalPooledEther() external view returns (uint256);

    /// @notice Get the amount of shares owned by an account
    /// @param _account The account address
    /// @return The amount of shares
    function sharesOf(address _account) external view returns (uint256);

    /// @notice Get the amount of stETH that corresponds to shares
    /// @param _sharesAmount The amount of shares
    /// @return The amount of stETH
    function getPooledEthByShares(uint256 _sharesAmount) external view returns (uint256);

    /// @notice Get the amount of shares that corresponds to stETH
    /// @param _ethAmount The amount of stETH
    /// @return The amount of shares
    function getSharesByPooledEth(uint256 _ethAmount) external view returns (uint256);
}
