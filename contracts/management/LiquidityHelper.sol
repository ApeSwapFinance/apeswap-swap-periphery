// SPDX-License-Identifier: MIT
pragma solidity =0.6.6;
pragma experimental ABIEncoderV2;

import '../interfaces/IApeFactory.sol';
import '../interfaces/IApePair.sol';
import '../interfaces/IERC20.sol';
import '../libraries/SafeMath.sol';

contract LiquidityHelper {
    using SafeMath for uint256;
    IApeFactory public factory;

    struct PairInfo {
        uint256 totalLpSupply;
        IERC20 token0;
        string token0Symbol;
        uint256 token0Balance;
        IERC20 token1;
        string token1Symbol;
        uint256 token1Balance;
    }

    struct LiquidityOutInfo {
        uint256 totalLpSupply;
        IERC20 token0;
        string token0Symbol;
        uint256 token0Out;
        IERC20 token1;
        string token1Symbol;
        uint256 token1Out;
    }

    constructor(address factoryAddress) public {
        factory = IApeFactory(factoryAddress);
    }

    /// @notice Provide two tokens and this will find the pair address related and return useful values
    /// @param tokenA Address of token0
    /// @param tokenB Address of token1
    /// @return pairInfo PairInfo struct based on provided inputs
    function getPairBalances(address tokenA, address tokenB)
        public
        view
        returns (PairInfo memory pairInfo)
    {
        address pair = factory.getPair(tokenA, tokenB);
        pairInfo = getPairBalances(pair);
    }

    /// @notice Provide a pair address and this will find the pair address related and return useful values
    /// @param pairAddress Address of the pair contract
    /// @return pairInfo PairInfo struct based on provided inputs
    function getPairBalances(address pairAddress)
        public
        view
        returns (PairInfo memory pairInfo)
    {
        IApePair apePair = IApePair(pairAddress);
        pairInfo.token0 = IERC20(apePair.token0());
        pairInfo.token0Symbol = pairInfo.token0.symbol();
        pairInfo.token1 = IERC20(apePair.token1());
        pairInfo.token1Symbol = pairInfo.token1.symbol();

        pairInfo.totalLpSupply = apePair.totalSupply();
        pairInfo.token0Balance = pairInfo.token0.balanceOf(pairAddress);
        pairInfo.token1Balance = pairInfo.token1.balanceOf(pairAddress);
    }

    /// @notice Find the token outputs for unwrapping LP tokens
    /// @param tokenA Address of the token0 contract
    /// @param tokenB Address of the token1 contract
    /// @param lpBalance Amount of LP tokens to unwrap
    /// @return liquidityOutInfo LiquidityOutInfo based on input data
    function getLiquidityAmountsOut(
        address tokenA,
        address tokenB,
        uint256 lpBalance
    )
        public
        view
        returns (LiquidityOutInfo memory liquidityOutInfo)
    {
        address pair = factory.getPair(tokenA, tokenB);
        liquidityOutInfo = getLiquidityAmountsOut(pair, lpBalance);
    }

    /// @notice Find the token outputs for unwrapping LP tokens
    /// @param pairAddress Address of the pair contract
    /// @param lpBalance Amount of LP tokens to unwrap
    /// @return liquidityOutInfo LiquidityOutInfo based on input data
    function getLiquidityAmountsOut(address pairAddress, uint256 lpBalance)
        public
        view
        returns (LiquidityOutInfo memory liquidityOutInfo)
    {
        PairInfo memory pairInfo = getPairBalances(pairAddress);

        uint256 token0Out = lpBalance.mul(pairInfo.token0Balance) / (pairInfo.totalLpSupply);
        uint256 token1Out = lpBalance.mul(pairInfo.token1Balance) / (pairInfo.totalLpSupply);

        liquidityOutInfo = LiquidityOutInfo(
            pairInfo.totalLpSupply,
            pairInfo.token0,
            pairInfo.token0Symbol,
            token0Out,
            pairInfo.token1,
            pairInfo.token1Symbol,
            token1Out
        );
    }
}
