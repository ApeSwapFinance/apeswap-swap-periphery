// SPDX-License-Identifier: MIT
pragma solidity =0.6.6;

import '../interfaces/IApeFactory.sol';
import '../interfaces/IApePair.sol';
import '../interfaces/IERC20.sol';
import '../libraries/SafeMath.sol';

contract LiquidityHelper {
    using SafeMath for uint256;
    IApeFactory public factory;

    constructor(address factoryAddress) public {
        factory = IApeFactory(factoryAddress);
    }

    /// @notice Provide two tokens and this will find the pair address related and return useful values
    /// @param token0 Address of token0
    /// @param token1 Address of token1
    /// @return totalLpSupply The total supply of LP tokens minted for the pair
    /// @return token0Balance The total balance of token0 in the pair
    /// @return token1Balance The total balance of token1 in the pair
    function getPairBalances(address token0, address token1)
        public
        view
        returns (uint256 totalLpSupply, uint256 token0Balance, uint256 token1Balance)
    {
        address pair = factory.getPair(token0, token1);
        return getPairBalances(pair);
    }

    /// @notice Provide a pair address and this will find the pair address related and return useful values
    /// @param pairAddress Address of the pair contract
    /// @return totalLpSupply The total supply of LP tokens minted for the pair
    /// @return token0Balance The total balance of token0 in the pair
    /// @return token1Balance The total balance of token1 in the pair
    function getPairBalances(address pairAddress)
        public
        view
        returns (
            uint256 totalLpSupply, 
            uint256 token0Balance, 
            uint256 token1Balance
        )
    {
        IApePair apePair = IApePair(pairAddress);
        IERC20 token0 = IERC20(apePair.token0());
        IERC20 token1 = IERC20(apePair.token1());

        totalLpSupply = apePair.totalSupply();
        token0Balance = token0.balanceOf(pairAddress);
        token1Balance = token1.balanceOf(pairAddress);
    }

    /// @notice Find the token outputs for unwrapping LP tokens
    /// @param token0 Address of the token0 contract
    /// @param token1 Address of the token1 contract
    /// @param lpBalance Amount of LP tokens to unwrap
    /// @return token0Out The output amount of token0
    /// @return token1Out The output amount of token1Out
    function getLiquidityAmountsOut(address token0, address token1, uint256 lpBalance)
        public
        view
        returns (uint256 token0Out, uint256 token1Out)
    {
        address pair = factory.getPair(token0, token1);
        return getLiquidityAmountsOut(pair, lpBalance);
    }

    /// @notice Find the token outputs for unwrapping LP tokens
    /// @param pairAddress Address of the pair contract
    /// @param lpBalance Amount of LP tokens to unwrap
    /// @return token0Out The output amount of token0
    /// @return token1Out The output amount of token1Out
    function getLiquidityAmountsOut(address pairAddress, uint256 lpBalance)
        public
        view
        returns (uint256 token0Out, uint256 token1Out)
    {
        (
            uint256 totalLpSupply, 
            uint256 token0Balance, 
            uint256 token1Balance
        ) = getPairBalances(pairAddress);

        token0Out = lpBalance.mul(token0Balance) / (totalLpSupply);
        token1Out = lpBalance.mul(token1Balance) / (totalLpSupply);
    }
}
