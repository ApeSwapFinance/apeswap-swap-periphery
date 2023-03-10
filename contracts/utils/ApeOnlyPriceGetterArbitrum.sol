// SPDX-License-Identifier: MIT
pragma solidity =0.6.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IApePair.sol";

// This library provides simple price calculations for ApeSwap tokens, accounting
// for commonly used pairings. Will break if USDT, USDC, or DAI goes far off peg.
// Should NOT be used as the sole oracle for sensitive calculations such as
// liquidation, as it is vulnerable to manipulation by flash loans, etc. BETA
// SOFTWARE, PROVIDED AS IS WITH NO WARRANTIES WHATSOEVER.



library ApeOnlyPriceGetterArbitrum {
    address public constant FACTORY = 0xCf083Be4164828f00cAE704EC15a36D711491284; //ApeSwap Factory

    bytes32 public constant INITCODEHASH =
        hex"ae7373e804a043c4c08107a81def627eeb3792e211fb4711fcfe32f0e4c45fd5"; // for pairs created by ApeFactory

    //All returned prices calculated with this precision (18 decimals)
    uint256 private constant PRECISION = 10**DECIMALS; //1e18 == $1
    uint256 public constant DECIMALS = 18;

    //Token addresses
    address constant WNATIVE = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address constant DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    //Token value constants
    uint256 private constant USDC_USDT_RAW_PRICE = 1e6;

    //Ape LP addresses
    address constant USDC_WNATIVE_PAIR = 0xC53e453E4A6953887bf447162D1dC9E1e7f16f60; // usdc is token1
    address constant DAI_WNATIVE_PAIR = 0xeBca41a83b658519F9Cf9fEB63CAe9f2A5112023; // dai is token1
    address constant USDT_WNATIVE_PAIR = 0xBEb125e43B46F757ece0428cdE20cce336aF962E; // usdt is token1

    //Normalized to specified number of decimals based on token's decimals and specified number of decimals

    function getPrice(address token, uint256 _decimals)
        external
        view
        returns (uint256)
    {
        return normalize(getRawPrice(token), token, _decimals);
    }

    function getLPPrice(address token, uint256 _decimals)
        external
        view
        returns (uint256)
    {
        return normalize(getRawLPPrice(token), token, _decimals);
    }

    function getPrices(address[] calldata tokens, uint256 _decimals)
        external
        view
        returns (uint256[] memory prices)
    {
        prices = getRawPrices(tokens);

        for (uint256 i; i < prices.length; i++) {
            prices[i] = normalize(prices[i], tokens[i], _decimals);
        }
    }

    function getLPPrices(address[] calldata tokens, uint256 _decimals)
        external
        view
        returns (uint256[] memory prices)
    {
        prices = getRawLPPrices(tokens);

        for (uint256 i; i < prices.length; i++) {
            prices[i] = normalize(prices[i], tokens[i], _decimals);
        }
    }

    //returns the price of any token in USD based on common pairings; zero on failure

    function getRawPrice(address token) public view returns (uint256) {
        uint256 pegPrice = pegTokenPrice(token);
        if (pegPrice != 0) return pegPrice;

        return getRawPrice(token, getNativePrice());
    }

    //returns the prices of multiple tokens, zero on failure

    function getRawPrices(address[] memory tokens)
        public
        view
        returns (uint256[] memory prices)
    {
        prices = new uint256[](tokens.length);
        uint256 nativePrice = getNativePrice();

        for (uint256 i; i < prices.length; i++) {
            address token = tokens[i];
            uint256 pegPrice = pegTokenPrice(token, nativePrice);

            if (pegPrice != 0) prices[i] = pegPrice;
            else prices[i] = getRawPrice(token, nativePrice);
        }
    }

    //returns the value of a LP token if it is one, or the regular price if it isn't LP

    function getRawLPPrice(address token) internal view returns (uint256) {
        uint256 pegPrice = pegTokenPrice(token);
        if (pegPrice != 0) return pegPrice;

        return getRawLPPrice(token, getNativePrice());
    }

    //returns the prices of multiple tokens which may or may not be LPs

    function getRawLPPrices(address[] memory tokens)
        internal
        view
        returns (uint256[] memory prices)
    {
        prices = new uint256[](tokens.length);
        uint256 nativePrice = getNativePrice();

        for (uint256 i; i < prices.length; i++) {
            address token = tokens[i];
            uint256 pegPrice = pegTokenPrice(token, nativePrice);

            if (pegPrice != 0) prices[i] = pegPrice;
            else prices[i] = getRawLPPrice(token, nativePrice);
        }
    }

    //returns the current USD price of BNB based on primary stablecoin pairs
    function getNativePrice() public view returns (uint256) {
        /// @dev WBNB happens to be token0 for each pair
        (uint256 wNativeReserve0, uint256 daiReserve, ) = IApePair(DAI_WNATIVE_PAIR)
            .getReserves();

        (uint256 wNativeReserve1, uint256 usdcReserve, ) = IApePair(USDC_WNATIVE_PAIR)
            .getReserves();

        (uint256 wNativeReserve2, uint256 usdtReserve, ) = IApePair(USDT_WNATIVE_PAIR)
            .getReserves();

        uint256 wNativeTotal = wNativeReserve0 + wNativeReserve1 + wNativeReserve2;
        uint256 usdTotal = daiReserve * PRECISION + (usdcReserve + usdtReserve) * PRECISION / USDC_USDT_RAW_PRICE * PRECISION;

        return usdTotal / wNativeTotal;
    }

    //Calculate LP token value in USD. Generally compatible with any UniswapV2 pair but will always price underlying
    //tokens using ape prices. If the provided token is not a LP, it will attempt to price the token as a
    //standard token. This is useful for MasterChef farms which stake both single tokens and pairs

    function getRawLPPrice(address lp, uint256 nativePrice)
        internal
        view
        returns (uint256)
    {
        //if not a LP, handle as a standard token
        try IApePair(lp).getReserves() returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32
        ) {
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
    function getRawPrice(address token, uint256 nativePrice)
        internal
        view
        returns (uint256 rawPrice)
    {
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
    function pegTokenPrice(address token, uint256 nativePrice)
        private
        pure
        returns (uint256)
    {
        if (token == USDC || token == USDT) return PRECISION * 1e12;
        if (token == DAI) return PRECISION;
        if (token == WNATIVE) return nativePrice;
        return 0;
    }

    function pegTokenPrice(address token) private view returns (uint256) {
        if (token == USDC || token == USDT) return PRECISION * 1e12;
        if (token == DAI) return PRECISION;
        if (token == WNATIVE) return getNativePrice();
        return 0;
    }

    //returns the number of tokens and the USD value within a single LP. peg is one of the listed primary, pegPrice is the predetermined USD value of this token
    function pairTokensAndValue(address token, address peg)
        private
        view
        returns (uint256 tokenNum, uint256 pegValue)
    {
        address tokenPegPair = pairFor(token, peg);

        // if the address has no contract deployed, the pair doesn't exist
        uint256 size;

        assembly {
            size := extcodesize(tokenPegPair)
        }

        if (size == 0) return (0, 0);

        try IApePair(tokenPegPair).getReserves() returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32
        ) {
            uint256 reservePeg;

            (tokenNum, reservePeg) = token < peg
                ? (reserve0, reserve1)
                : (reserve1, reserve0);

            pegValue = reservePeg * pegTokenPrice(peg);
        } catch {
            return (0, 0);
        }
    }

    //normalize a token price to a specified number of decimals
    function normalize(
        uint256 price,
        address token,
        uint256 _decimals
    ) private view returns (uint256) {
        uint256 tokenDecimals;

        try ERC20(token).decimals() returns (uint8 dec) {
            tokenDecimals = dec;
        } catch {
            tokenDecimals = 18;
        }

        if (tokenDecimals + _decimals <= 2 * DECIMALS)
            return price / 10**(2 * DECIMALS - tokenDecimals - _decimals);
        else return price * 10**(_decimals + tokenDecimals - 2 * DECIMALS);
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address tokenA, address tokenB)
        private
        pure
        returns (address pair)
    {
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);

        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            FACTORY,
                            keccak256(abi.encodePacked(token0, token1)),
                            INITCODEHASH
                        )
                    )
                )
            )
        );
    }
}