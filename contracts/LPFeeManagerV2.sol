// SPDX-License-Identifier: MIT
pragma solidity =0.6.6;
pragma experimental ABIEncoderV2;

import './interfaces/IApeRouter02.sol';
import './interfaces/IApeFactory.sol';
import './interfaces/IApePair.sol';
import './utils/Sweeper.sol';


/// @title LP fee manager
/// @author Apeswap.finance
/// @notice Swap LP token fees collected to different token
contract LPFeeManagerV2 is Sweeper {
    IApeRouter02 public router;
    IApeFactory public factory;

    event LiquidityRemoved(address indexed pairAddress);
    event LiquidityRemovalFailed(address indexed pairAddress);
    event Swap(uint256 amountIn, uint256 amountOut, address[] path);
    event SwapFailed(uint256 amountIn, uint256 amountOut, address[] path);

    constructor(
        address _router,
        address _admin,
        address[] memory _lockedTokens,
        bool _allowNativeSweep
    ) public Sweeper(_lockedTokens, _allowNativeSweep) {
        router = IApeRouter02(_router);
        factory = IApeFactory(router.factory());

        require(_admin != address(0), 'Admin is the zero address');
        adminAddress = _admin;
    }

    /// @notice Remove LP and unwrap to base tokens
    /// @param _lpTokens address list of LP tokens to unwrap
    /// @param _amounts Amount of each LP token to sell
    /// @param _token0Outs Minimum token 0 output requested.
    /// @param _token1Outs Minimum token 1 output requested.
    /// @param _to address the tokens need to be transferred to.
    function removeLiquidityTokens(
        address[] memory _lpTokens,
        uint256[] memory _amounts,
        uint256[] memory _token0Outs,
        uint256[] memory _token1Outs,
        address _to
    ) public onlyOwner {
        address toAddress = _to == address(0) ? address(this) : _to;

        for (uint256 i = 0; i < _lpTokens.length; i++) {
            IApePair pair = IApePair(_lpTokens[i]);
            pair.approve(address(router), _amounts[i]);
            try
                router.removeLiquidity(
                    pair.token0(),
                    pair.token1(),
                    _amounts[i],
                    _token0Outs[i],
                    _token1Outs[i],
                    toAddress,
                    block.timestamp + 600
                ) returns (uint amountA, uint amountB)
            {
                emit LiquidityRemoved(address(pair));
            } catch {
                emit LiquidityRemovalFailed(address(pair));
            }
        }
    }

    /// @notice Swap amount in vs amount out
    /// @param _amountIns Array of amount ins
    /// @param _amountOuts Array of amount outs
    /// @param _paths path to follow for swapping
    /// @param _to address the tokens need to be transferred to.
    function swapTokens(
        uint256[] memory _amountIns,
        uint256[] memory _amountOuts,
        address[][] memory _paths,
        address _to
    ) public onlyOwner virtual {
        address toAddress = _to == address(0) ? address(this) : _to;

        for (uint256 i = 0; i < _amountIns.length; i++) {
            IERC20 token = IERC20(_paths[i][0]);
            token.approve(address(router), _amountIns[i]);
            try
                router.swapExactTokensForTokens(
                    _amountIns[i],
                    _amountOuts[i],
                    _paths[i],
                    toAddress,
                    block.timestamp + 600
                )
            {
                emit Swap(_amountIns[i], _amountOuts[i], _paths[i]);
            } catch {
                emit SwapFailed(_amountIns[i], _amountOuts[i], _paths[i]);
            }
        }
    }

    /// @notice Change admin
    /// @param _newAdmin New admin address
    function changeAdmin(address _newAdmin) public virtual onlyOwner {
        require(_newAdmin != address(0), 'New admin is the zero address');
        emit OwnershipTransferred(adminAddress, _newAdmin);
        adminAddress = _newAdmin;
    }
}
