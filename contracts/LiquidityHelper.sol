// SPDX-License-Identifier: MIT
pragma solidity =0.6.6;

import './interfaces/IApeFactory.sol';
import './interfaces/IApePair.sol';
import './interfaces/IERC20.sol';
import './libraries/SafeMath.sol';

contract LiquidityHelper {
    using SafeMath for uint256;
    IApeFactory factory;
    uint256 MAX_INT = uint256(-1);

    constructor(address factoryAddress) public {
        factory = IApeFactory(factoryAddress);
    }

    function getPairBalances(address token0, address token1)
        public
        view
        returns (uint256 totalLpSupply, uint256 token0Balance, uint256 token1Balance)
    {
        address pair = factory.getPair(token0, token1);
        return getPairBalances(pair);
    }

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

    function getLiquidityAmountsOut(address token0, address token1, uint256 lpBalance)
        public
        view
        returns (uint256 token0Out, uint256 token1Out)
    {
        address pair = factory.getPair(token0, token1);
        return getLiquidityAmountsOut(pair, lpBalance);
    }

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
