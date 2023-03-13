// SPDX-License-Identifier: MIT
pragma solidity =0.6.6;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '../interfaces/IApePair.sol';
import '../interfaces/IApeFactory.sol';
import './IPriceGetter.sol';

// This library provides simple price calculations for ApeSwap tokens, accounting
// for commonly used pairings. Will break if USDT, USDC, or DAI goes far off peg.
// Should NOT be used as the sole oracle for sensitive calculations such as
// liquidation, as it is vulnerable to manipulation by flash loans, etc. BETA
// SOFTWARE, PROVIDED AS IS WITH NO WARRANTIES WHATSOEVER.

contract ApeOnlyPriceGetterBSC is IPriceGetter {
    address public constant override FACTORY = 0x0841BD0B734E4F5853f0dD8d7Ea041c241fb0Da6; // ApeFactory
    bytes32 public constant override INITCODEHASH = hex'f4ccce374816856d11f00e4069e7cada164065686fbef53c6167a63ec2fd8c5b';
    uint256 public constant override DECIMALS = 18;

    //All returned prices calculated with this precision (18 decimals)
    uint256 private constant PRECISION = 10 ** DECIMALS; // 1e18 == $1

    //Token addresses
    address constant WNATIVE = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    address constant DAI = 0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3;
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;

    //Ape LP addresses
    address constant BUSD_WNATIVE_PAIR = 0x51e6D27FA57373d8d4C256231241053a70Cb1d93; // busd is token1
    address constant USDC_WNATIVE_PAIR = 0xd00302278693E5084e2B06A996d1D14aE3467fE6; // usdc is token0
    address constant DAI_WNATIVE_PAIR = 0xeeF64E1b9417acC4a4fef492d85B98Fa4Cb7D50A;  // dai is token0
    address constant USDT_WNATIVE_PAIR = 0x83C5b5b309EE8E232Fe9dB217d394e262a71bCC0; // usdt is token0

    //Normalized to specified number of decimals based on token's decimals and specified number of decimals

    function getPrice(address token, uint256 _decimals) external view override returns (uint256) {
        return normalize(getRawPrice(token), token, _decimals);
    }

    function getLPPrice(address token, uint256 _decimals) external view override returns (uint256) {
        return normalize(getRawLPPrice(token), token, _decimals);
    }

    function getPrices(
        address[] calldata tokens,
        uint256 _decimals
    ) external view override returns (uint256[] memory prices) {
        prices = getRawPrices(tokens);

        for (uint256 i; i < prices.length; i++) {
            prices[i] = normalize(prices[i], tokens[i], _decimals);
        }
    }

    function getLPPrices(
        address[] calldata tokens,
        uint256 _decimals
    ) external view override returns (uint256[] memory prices) {
        prices = getRawLPPrices(tokens);

        for (uint256 i; i < prices.length; i++) {
            prices[i] = normalize(prices[i], tokens[i], _decimals);
        }
    }

    //returns the price of any token in USD based on common pairings; zero on failure

    function getRawPrice(address token) public view override returns (uint256) {
        uint256 pegPrice = pegTokenPrice(token);
        if (pegPrice != 0) return pegPrice;

        return getRawPrice(token, getNativePrice());
    }

    //returns the prices of multiple tokens, zero on failure

    function getRawPrices(address[] memory tokens) public view override returns (uint256[] memory prices) {
        prices = new uint256[](tokens.length);
        uint256 nativePrice = getNativePrice();

        for (uint256 i; i < prices.length; i++) {
            address token = tokens[i];
            uint256 pegPrice = pegTokenPrice(token, nativePrice);

            if (pegPrice != 0) prices[i] = pegPrice;
            else prices[i] = getRawPrice(token, nativePrice);
        }
    }

    //returns the current USD price of BNB based on primary stablecoin pairs
    function getNativePrice() public view override returns (uint256) {
        /// @dev WBNB happens to be token0 for each pair
        (uint256 daiReserve, uint256 wNativeReserve0, ) = IApePair(DAI_WNATIVE_PAIR).getReserves();

        (uint256 usdcReserve, uint256 wNativeReserve1, ) = IApePair(USDC_WNATIVE_PAIR).getReserves();

        (uint256 usdtReserve, uint256 wNativeReserve2, ) = IApePair(USDT_WNATIVE_PAIR).getReserves();

        (uint256 wNativeReserve3, uint256 busdReserve, ) = IApePair(BUSD_WNATIVE_PAIR).getReserves();

        uint256 wNativeTotal = wNativeReserve0 + wNativeReserve1 + wNativeReserve2 + wNativeReserve3;

        uint usdTotal = daiReserve + usdcReserve + busdReserve + usdtReserve;

        return usdTotal * PRECISION / wNativeTotal;
    }

    //returns the value of a LP token if it is one, or the regular price if it isn't LP

    function getRawLPPrice(address token) internal view returns (uint256) {
        uint256 pegPrice = pegTokenPrice(token);
        if (pegPrice != 0) return pegPrice;

        return getRawLPPrice(token, getNativePrice());
    }

    //returns the prices of multiple tokens which may or may not be LPs

    function getRawLPPrices(address[] memory tokens) internal view returns (uint256[] memory prices) {
        prices = new uint256[](tokens.length);
        uint256 nativePrice = getNativePrice();

        for (uint256 i; i < prices.length; i++) {
            address token = tokens[i];
            uint256 pegPrice = pegTokenPrice(token, nativePrice);

            if (pegPrice != 0) prices[i] = pegPrice;
            else prices[i] = getRawLPPrice(token, nativePrice);
        }
    }

    //Calculate LP token value in USD. Generally compatible with any UniswapV2 pair but will always price underlying
    //tokens using ape prices. If the provided token is not a LP, it will attempt to price the token as a
    //standard token. This is useful for MasterChef farms which stake both single tokens and pairs

    function getRawLPPrice(address lp, uint256 nativePrice) internal view returns (uint256) {
        //if not a LP, handle as a standard token
        try IApePair(lp).getReserves() returns (uint112 reserve0, uint112 reserve1, uint32) {
            address token0 = IApePair(lp).token0();
            address token1 = IApePair(lp).token1();
            uint256 totalSupply = IApePair(lp).totalSupply();

            //price0*reserve0+price1*reserve1

            uint256 totalValue = getRawPrice(token0, nativePrice) *
                reserve0 +
                getRawPrice(token1, nativePrice) *
                reserve1;

            return totalValue / totalSupply;
        } catch {
            return getRawPrice(lp, nativePrice);
        }
    }

    // checks for primary tokens and returns the correct predetermined price if possible, otherwise calculates price
    function getRawPrice(address token, uint256 nativePrice) internal view returns (uint256 rawPrice) {
        uint256 pegPrice = pegTokenPrice(token, nativePrice);

        if (pegPrice != 0) return pegPrice;

        uint256 numTokens;
        uint256 pairedValue;
        uint256 lpTokens;
        uint256 lpValue;

        (lpTokens, lpValue) = pairTokensAndValue(token, WNATIVE);
        numTokens += lpTokens;
        pairedValue += lpValue;

        (lpTokens, lpValue) = pairTokensAndValue(token, DAI);
        numTokens += lpTokens;
        pairedValue += lpValue;

        (lpTokens, lpValue) = pairTokensAndValue(token, USDC);
        numTokens += lpTokens;
        pairedValue += lpValue;

        (lpTokens, lpValue) = pairTokensAndValue(token, USDT);
        numTokens += lpTokens;
        pairedValue += lpValue;

        if (numTokens > 0) return pairedValue / numTokens;
    }

    //if one of the peg tokens, returns that price, otherwise zero
    function pegTokenPrice(address token, uint256 nativePrice) private pure returns (uint256) {
        if (token == DAI || token == USDC || token == USDT || token == BUSD) return PRECISION;
        if (token == WNATIVE) return nativePrice;
        return 0;
    }

    function pegTokenPrice(address token) private view returns (uint256) {
        if (token == DAI || token == USDC || token == USDT || token == BUSD) return PRECISION;
        if (token == WNATIVE) return getNativePrice();
        return 0;
    }

    //returns the number of tokens and the USD value within a single LP. peg is one of the listed primary, pegPrice is the predetermined USD value of this token
    function pairTokensAndValue(address token, address peg) private view returns (uint256 tokenNum, uint256 pegValue) {
        address tokenPegPair = pairFor(token, peg);

        // if the address has no contract deployed, the pair doesn't exist
        uint256 size;

        assembly {
            size := extcodesize(tokenPegPair)
        }

        if (size == 0) return (0, 0);

        try IApePair(tokenPegPair).getReserves() returns (uint112 reserve0, uint112 reserve1, uint32) {
            uint256 reservePeg;

            (tokenNum, reservePeg) = token < peg ? (reserve0, reserve1) : (reserve1, reserve0);

            pegValue = reservePeg * pegTokenPrice(peg);
        } catch {
            return (0, 0);
        }
    }

    //normalize a token price to a specified number of decimals
    function normalize(uint256 price, address token, uint256 _decimals) private view returns (uint256) {
        uint256 tokenDecimals;

        try ERC20(token).decimals() returns (uint8 dec) {
            tokenDecimals = dec;
        } catch {
            tokenDecimals = 18;
        }

        if (tokenDecimals + _decimals <= 2 * DECIMALS) return price / 10 ** (2 * DECIMALS - tokenDecimals - _decimals);
        else return price * 10 ** (_decimals + tokenDecimals - 2 * DECIMALS);
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address tokenA, address tokenB) private pure returns (address pair) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(hex'ff', FACTORY, keccak256(abi.encodePacked(token0, token1)), INITCODEHASH)
                    )
                )
            )
        );
    }
}
