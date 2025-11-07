// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// Import official Pendle interfaces
import "@pendle/interfaces/IPAllActionV3.sol";
import "@pendle/interfaces/IPAllActionTypeV3.sol";

// Re-export the official interface for convenience
interface IPendleRouter is IPAllActionV3 {}
