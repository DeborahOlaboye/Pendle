// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@solmate/tokens/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IStETH.sol";
import "./interfaces/IPendleRouter.sol";
import "./interfaces/IPendleMarket.sol";
import "./YieldLockManager.sol";
import "./FixedYieldDistributor.sol";

/// @title PendleFixedYieldVault
/// @notice ERC4626 vault that converts ETH deposits into fixed yield via Pendle PT/YT splitting
/// @dev Deposits ETH, converts to stETH, splits into PT+YT, sells YT for fixed yield
contract PendleFixedYieldVault is ERC4626, Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // Immutable contracts
    IStETH public immutable stETH;
    IPendleRouter public immutable pendleRouter;

    // Manager contracts
    YieldLockManager public yieldLockManager;
    FixedYieldDistributor public yieldDistributor;

    // Pendle market configuration
    address public pendleMarket;
    address public pendleYT;

    // Slippage protection (in basis points, e.g., 100 = 1%)
    uint256 public slippageBps = 100;

    // Minimum deposit amount (0.01 ETH)
    uint256 public minDeposit = 0.01 ether;

    // Events
    event Deposited(address indexed user, uint256 ethAmount, uint256 shares);
    event YieldLocked(uint256 ytAmount, uint256 fixedYield, uint256 maturity);
    event PTRedeemed(uint256 ptAmount, uint256 stETHReceived);
    event ManagersUpdated(address yieldLockManager, address yieldDistributor);
    event MarketUpdated(address market, address yt);
    event SlippageUpdated(uint256 newSlippageBps);
    event MinDepositUpdated(uint256 newMinDeposit);

    /// @notice Constructor
    /// @param _stETH Lido stETH token address
    /// @param _pendleRouter Pendle Router address
    /// @param _pendleMarket Pendle Market address for stETH
    /// @param _pendleYT Pendle YT token address
    constructor(
        address _stETH,
        address _pendleRouter,
        address _pendleMarket,
        address _pendleYT
    ) ERC4626(IERC20(_stETH), "Pendle Fixed Yield Vault", "pfyVault") Ownable(msg.sender) {
        require(_stETH != address(0), "Invalid stETH address");
        require(_pendleRouter != address(0), "Invalid router address");
        require(_pendleMarket != address(0), "Invalid market address");
        require(_pendleYT != address(0), "Invalid YT address");

        stETH = IStETH(_stETH);
        pendleRouter = IPendleRouter(_pendleRouter);
        pendleMarket = _pendleMarket;
        pendleYT = _pendleYT;

        // Deploy manager contracts
        yieldLockManager = new YieldLockManager();
        yieldDistributor = new FixedYieldDistributor(_stETH);
    }

    /// @notice Deposit ETH and receive vault shares
    /// @return shares The number of vault shares minted
    function depositETH() external payable nonReentrant whenNotPaused returns (uint256 shares) {
        require(msg.value >= minDeposit, "Deposit too small");

        // Convert ETH to stETH
        uint256 stETHReceived = stETH.submit{value: msg.value}(address(0));
        require(stETHReceived > 0, "stETH mint failed");

        // Lock a portion of the yield via Pendle
        _lockYield(stETHReceived);

        // Calculate shares to mint (simplified - should use proper ERC4626 math)
        shares = previewDeposit(stETHReceived);
        _mint(msg.sender, shares);

        emit Deposited(msg.sender, msg.value, shares);
    }

    /// @notice Internal function to lock yield via Pendle PT/YT split
    /// @param stETHAmount Amount of stETH to split
    function _lockYield(uint256 stETHAmount) internal {
        // Approve router to spend stETH
        IERC20(address(stETH)).safeIncreaseAllowance(address(pendleRouter), stETHAmount);

        // Prepare TokenInput for Pendle
        TokenInput memory input = TokenInput({
            tokenIn: address(stETH),
            netTokenIn: stETHAmount,
            tokenMintSy: address(stETH),
            pendleSwap: address(0),
            swapData: SwapData({
                swapType: SwapType.NONE,
                extRouter: address(0),
                extCalldata: "",
                needScale: false
            })
        });

        // Calculate minimum output with slippage protection
        uint256 minPyOut = (stETHAmount * (10000 - slippageBps)) / 10000;

        // Mint PT + YT from stETH
        uint256 netPyOut = pendleRouter.mintPyFromToken(
            address(this),
            pendleYT,
            minPyOut,
            input
        );

        // Track PT position
        address ptToken = IPendleMarket(pendleMarket).PT();
        uint256 maturity = IPendleMarket(pendleMarket).expiry();
        yieldLockManager.addPosition(ptToken, netPyOut, maturity);

        // Sell YT for fixed yield
        _sellYT(netPyOut);
    }

    /// @notice Sell YT tokens for fixed yield
    /// @param ytAmount Amount of YT to sell
    function _sellYT(uint256 ytAmount) internal {
        // Approve router to spend YT
        IERC20(pendleYT).safeIncreaseAllowance(address(pendleRouter), ytAmount);

        // Prepare TokenOutput
        TokenOutput memory output = TokenOutput({
            tokenOut: address(stETH),
            minTokenOut: 0, // Should calculate proper slippage
            tokenRedeemSy: address(stETH),
            pendleSwap: address(0),
            swapData: SwapData({
                swapType: SwapType.NONE,
                extRouter: address(0),
                extCalldata: "",
                needScale: false
            })
        });

        // Swap YT for stETH
        (uint256 netTokenOut,) = pendleRouter.swapExactYtForToken(
            address(this),
            pendleMarket,
            ytAmount,
            output
        );

        // Transfer fixed yield to distributor
        IERC20(address(stETH)).safeTransfer(address(yieldDistributor), netTokenOut);
        yieldDistributor.receiveYield(netTokenOut);

        uint256 maturity = IPendleMarket(pendleMarket).expiry();
        emit YieldLocked(ytAmount, netTokenOut, maturity);
    }

    /// @notice Redeem matured PT tokens
    function redeemMaturedPT() external nonReentrant onlyOwner {
        (address[] memory ptTokens, uint256[] memory amounts, uint256[] memory maturities) =
            yieldLockManager.getMaturedPositions();

        for (uint256 i = 0; i < ptTokens.length; i++) {
            if (amounts[i] > 0) {
                _redeemPT(ptTokens[i], amounts[i], i);
            }
        }
    }

    /// @notice Internal function to redeem PT
    /// @param ptToken PT token address
    /// @param amount Amount to redeem
    /// @param positionId Position ID to mark as redeemed
    function _redeemPT(address ptToken, uint256 amount, uint256 positionId) internal {
        // Approve router to spend PT
        IERC20(ptToken).safeIncreaseAllowance(address(pendleRouter), amount);

        // Prepare output
        TokenOutput memory output = TokenOutput({
            tokenOut: address(stETH),
            minTokenOut: 0,
            tokenRedeemSy: address(stETH),
            pendleSwap: address(0),
            swapData: SwapData({
                swapType: SwapType.NONE,
                extRouter: address(0),
                extCalldata: "",
                needScale: false
            })
        });

        // Redeem PT to stETH
        uint256 stETHReceived = pendleRouter.redeemPyToToken(
            address(this),
            pendleYT,
            amount,
            output
        );

        // Mark position as redeemed
        yieldLockManager.markRedeemed(positionId);

        emit PTRedeemed(amount, stETHReceived);
    }

    /// @notice Withdraw function (standard ERC4626)
    /// @param assets Amount of assets to withdraw
    /// @param receiver Address to receive assets
    /// @param owner Owner of shares
    /// @return shares Amount of shares burned
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override nonReentrant whenNotPaused returns (uint256 shares) {
        shares = previewWithdraw(assets);

        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender];
            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        _burn(owner, shares);
        IERC20(address(stETH)).safeTransfer(receiver, assets);

        return shares;
    }

    // Admin functions

    /// @notice Update manager contracts
    /// @param _yieldLockManager New YieldLockManager address
    /// @param _yieldDistributor New FixedYieldDistributor address
    function updateManagers(address _yieldLockManager, address _yieldDistributor) external onlyOwner {
        require(_yieldLockManager != address(0), "Invalid manager");
        require(_yieldDistributor != address(0), "Invalid distributor");

        yieldLockManager = YieldLockManager(_yieldLockManager);
        yieldDistributor = FixedYieldDistributor(_yieldDistributor);

        emit ManagersUpdated(_yieldLockManager, _yieldDistributor);
    }

    /// @notice Update Pendle market
    /// @param _market New market address
    /// @param _yt New YT address
    function updateMarket(address _market, address _yt) external onlyOwner {
        require(_market != address(0), "Invalid market");
        require(_yt != address(0), "Invalid YT");

        pendleMarket = _market;
        pendleYT = _yt;

        emit MarketUpdated(_market, _yt);
    }

    /// @notice Update slippage tolerance
    /// @param _slippageBps New slippage in basis points
    function updateSlippage(uint256 _slippageBps) external onlyOwner {
        require(_slippageBps <= 1000, "Slippage too high"); // Max 10%
        slippageBps = _slippageBps;
        emit SlippageUpdated(_slippageBps);
    }

    /// @notice Update minimum deposit
    /// @param _minDeposit New minimum deposit amount
    function updateMinDeposit(uint256 _minDeposit) external onlyOwner {
        minDeposit = _minDeposit;
        emit MinDepositUpdated(_minDeposit);
    }

    /// @notice Pause the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the contract
    function unpause() external onlyOwner {
        _unpause();
    }

    // ERC4626 overrides

    function totalAssets() public view override returns (uint256) {
        return IERC20(address(stETH)).balanceOf(address(this)) +
               yieldLockManager.getTotalLockedValue();
    }

    /// @notice Emergency withdrawal function
    /// @param token Token to withdraw
    /// @param amount Amount to withdraw
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }

    receive() external payable {}
}
