// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

struct TokenInput {
    address tokenIn;
    uint256 netTokenIn;
    address tokenMintSy;
    address pendleSwap;
    SwapData swapData;
}

struct TokenOutput {
    address tokenOut;
    uint256 minTokenOut;
    address tokenRedeemSy;
    address pendleSwap;
    SwapData swapData;
}

struct SwapData {
    SwapType swapType;
    address extRouter;
    bytes extCalldata;
    bool needScale;
}

enum SwapType {
    NONE,
    KYBERSWAP,
    ONE_INCH,
    ETH_WETH
}

interface IPendleRouter {
    /// @notice Mints PT and YT from token
    /// @param receiver The address to receive the PT and YT
    /// @param YT The YT token address
    /// @param minPyOut Minimum amount of PT/YT to receive
    /// @param input Token input struct
    /// @return netPyOut The amount of PT/YT minted
    function mintPyFromToken(
        address receiver,
        address YT,
        uint256 minPyOut,
        TokenInput calldata input
    ) external returns (uint256 netPyOut);

    /// @notice Swaps exact YT for token
    /// @param receiver The address to receive the tokens
    /// @param market The Pendle market address
    /// @param exactYtIn The exact amount of YT to swap
    /// @param output Token output struct
    /// @return netTokenOut The amount of tokens received
    /// @return netSyFee The SY fee charged
    function swapExactYtForToken(
        address receiver,
        address market,
        uint256 exactYtIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut, uint256 netSyFee);

    /// @notice Redeems PT to token after maturity
    /// @param receiver The address to receive the tokens
    /// @param YT The YT token address
    /// @param netPyIn The amount of PT to redeem
    /// @param output Token output struct
    /// @return netTokenOut The amount of tokens received
    function redeemPyToToken(
        address receiver,
        address YT,
        uint256 netPyIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut);
}
