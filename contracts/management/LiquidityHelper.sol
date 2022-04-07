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
    /// @return token0 token0 as registered on the pair contract
    /// @return token0Symbol symbol of token0
    /// @return token0Balance The total balance of token0 in the pair
    /// @return token1 token1 as registered on the pair contract
    /// @return token1Symbol symbol of token1
    /// @return token1Balance The total balance of token1 in the pair
    function getPairBalances(address _tokenA, address _tokenB)
        public
        view
        returns (
            uint256 totalLpSupply,
            IERC20 token0, 
            string memory token0Symbol, 
            uint256 token0Balance, 
            IERC20 token1, 
            string memory token1Symbol, 
            uint256 token1Balance
        )
    {
        address pair = factory.getPair(_tokenA, _tokenB);
        return getPairBalances(pair);
    }

    /// @notice Provide a pair address and this will find the pair address related and return useful values
    /// @param pairAddress Address of the pair contract
    /// @return totalLpSupply The total supply of LP tokens minted for the pair
    /// @return token0 token0 as registered on the pair contract
    /// @return token0Symbol symbol of token0
    /// @return token0Balance The total balance of token0 in the pair
    /// @return token1 token1 as registered on the pair contract
    /// @return token1Symbol symbol of token1
    /// @return token1Balance The total balance of token1 in the pair
    function getPairBalances(address pairAddress)
        public
        view
        returns (
            uint256 totalLpSupply,
            IERC20 token0, 
            string memory token0Symbol, 
            uint256 token0Balance, 
            IERC20 token1, 
            string memory token1Symbol, 
            uint256 token1Balance
        )
    {
        IApePair apePair = IApePair(pairAddress);
        token0 = IERC20(apePair.token0());
        token0Symbol = token0.symbol();
        token1 = IERC20(apePair.token1());
        token1Symbol = token1.symbol();

        totalLpSupply = apePair.totalSupply();
        token0Balance = token0.balanceOf(pairAddress);
        token1Balance = token1.balanceOf(pairAddress);
    }

    /// @notice Find the token outputs for unwrapping LP tokens
    /// @param tokenA Address of the token0 contract
    /// @param tokenB Address of the token1 contract
    /// @param lpBalance Amount of LP tokens to unwrap
    /// @return totalLpSupply Total supply of LP tokens for the pair
    /// @return token0 token0 as registered on the pair contract
    /// @return token0Symbol symbol of token0
    /// @return token0Out The output amount of token0
    /// @return token1 token1 as registered on the pair contract
    /// @return token1Symbol symbol of token1
    /// @return token1Out The output amount of token1
    function getLiquidityAmountsOut(address tokenA, address tokenB, uint256 lpBalance)
        public
        view
        returns (
            uint256 totalLpSupply,
            IERC20 token0,
            string memory token0Symbol, 
            uint256 token0Out,
            IERC20 token1,
            string memory token1Symbol, 
            uint256 token1Out
        )
    {
        address pair = factory.getPair(tokenA, tokenB);
        return getLiquidityAmountsOut(pair, lpBalance);
    }

    /// @notice Find the token outputs for unwrapping LP tokens
    /// @param pairAddress Address of the pair contract
    /// @param lpBalance Amount of LP tokens to unwrap
    /// @return totalLpSupply Total supply of LP tokens for the pair
    /// @return token0 token0 as registered on the pair contract
    /// @return token0Symbol symbol of token0
    /// @return token0Out The output amount of token0
    /// @return token1 token1 as registered on the pair contract
    /// @return token1Symbol symbol of token1
    /// @return token1Out The output amount of token1
    function getLiquidityAmountsOut(address pairAddress, uint256 lpBalance)
        public
        view
        returns (
            uint256 totalLpSupply,
            IERC20 token0,
            string memory token0Symbol, 
            uint256 token0Out,
            IERC20 token1,
            string memory token1Symbol, 
            uint256 token1Out
        )
    {
        (
            uint256 totalLpSupply_, 
            IERC20 token0_,
            string memory token0Symbol_,
            uint256 token0Balance, 
            IERC20 token1_,
            string memory token1Symbol_,
            uint256 token1Balance
        ) = getPairBalances(pairAddress);

        totalLpSupply = totalLpSupply_;
        token0 = token0_;
        token0Symbol = token0Symbol_;
        token1 = token1_;
        token1Symbol = token1Symbol_;

        token0Out = lpBalance.mul(token0Balance) / (totalLpSupply_);
        token1Out = lpBalance.mul(token1Balance) / (totalLpSupply_);
    }
}
