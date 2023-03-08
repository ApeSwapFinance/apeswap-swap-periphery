// SPDX-License-Identifier: MIT
pragma solidity 0.6.6;

/**
 * @notice DISCLAIMER: BETA SOFTWARE, PROVIDED AS IS WITH NO WARRANTIES WHATSOEVER.
 * This library provides simple price calculations for ApeSwap tokens, accounting
 * for commonly used pairings. Will break if USDT, USDC, or DAI goes far off peg.
 *
 * MUST NOT be used as the sole oracle for sensitive calculations such as
 * liquidation, as it is vulnerable to manipulation by flash loans, etc.
 */

import '../interfaces/IApePair.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

library ApeOnlyPriceGetterArbitrum {
    address public constant FACTORY = 0xCf083Be4164828f00cAE704EC15a36D711491284; //ApeFactory
    bytes32 public constant INITCODEHASH = hex'ae7373e804a043c4c08107a81def627eeb3792e211fb4711fcfe32f0e4c45fd5'; // for pairs created by ApeFactory

    //All returned prices calculated with this precision (18 decimals)
    uint public constant DECIMALS = 18;
    uint private constant PRECISION = 10 ** DECIMALS; //1e18 == $1

    //Token addresses
    address constant WNATIVE = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address constant DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    //Token value constants
    uint private constant USC_RAW_PRICE = 1e18;

    //Normalized to specified number of decimals based on token's decimals and
    //specified number of decimals
    function getPrice(address token, uint _decimals) external view returns (uint) {
        return normalize(getRawPrice(token), token, _decimals);
    }

    function getLPPrice(address token, uint _decimals) external view returns (uint) {
        return normalize(getRawLPPrice(token), token, _decimals);
    }

    function getPrices(address[] calldata tokens, uint _decimals) external view returns (uint[] memory prices) {
        prices = getRawPrices(tokens);

        for (uint i; i < prices.length; i++) {
            prices[i] = normalize(prices[i], tokens[i], _decimals);
        }
    }

    function getLPPrices(address[] calldata tokens, uint _decimals) external view returns (uint[] memory prices) {
        prices = getRawLPPrices(tokens);

        for (uint i; i < prices.length; i++) {
            prices[i] = normalize(prices[i], tokens[i], _decimals);
        }
    }

    //returns the price of any token in USD based on common pairings; zero on failure
    function getRawPrice(address token) public view returns (uint) {
        uint pegPrice = pegTokenPrice(token);

        if (pegPrice != 0) return pegPrice;

        return getRawPrice(token, getNativePrice());
    }

    //returns the prices of multiple tokens, zero on failure
    function getRawPrices(address[] memory tokens) public view returns (uint[] memory prices) {
        prices = new uint[](tokens.length);

        uint nativePrice = getNativePrice();

        for (uint i; i < prices.length; i++) {
            address token = tokens[i];

            uint pegPrice = pegTokenPrice(token, nativePrice);

            if (pegPrice != 0) prices[i] = pegPrice;
            else prices[i] = getRawPrice(token, nativePrice);
        }
    }

    // returns the current USD price of the Native currency based on primary stablecoin pairs
    function getNativePrice() public view returns (uint) {
        (uint daiReserve0, uint daiReserve1, ) = IApePair(pairFor(WNATIVE, DAI)).getReserves();
        uint nativeTotal = tokensAreSorted(WNATIVE, DAI) ? daiReserve0 : daiReserve1;
        uint usdTotal = tokensAreSorted(WNATIVE, DAI) ? daiReserve1 : daiReserve0;

        (uint usdcReserve0, uint usdcReserve1, ) = IApePair(pairFor(WNATIVE, USDC)).getReserves();
        nativeTotal += tokensAreSorted(WNATIVE, USDC) ? usdcReserve0 : usdcReserve1;
        usdTotal += tokensAreSorted(WNATIVE, USDC) ? usdcReserve1 : usdcReserve0;

        (uint usdtReserve0, uint usdtReserve1, ) = IApePair(pairFor(WNATIVE, USDT)).getReserves();
        nativeTotal += tokensAreSorted(WNATIVE, USDT) ? usdtReserve0 : usdtReserve1;
        usdTotal += tokensAreSorted(WNATIVE, USDT) ? usdtReserve1 : usdtReserve0;

        return (usdTotal * PRECISION) / nativeTotal;
    }

    //returns the value of a LP token if it is one, or the regular price if it isn't LP
    function getRawLPPrice(address token) internal view returns (uint) {
        uint pegPrice = pegTokenPrice(token);

        if (pegPrice != 0) return pegPrice;
        return getRawLPPrice(token, getNativePrice());
    }

    //returns the prices of multiple tokens which may or may not be LPs
    function getRawLPPrices(address[] memory tokens) internal view returns (uint[] memory prices) {
        prices = new uint[](tokens.length);

        uint nativePrice = getNativePrice();

        for (uint i; i < prices.length; i++) {
            address token = tokens[i];

            uint pegPrice = pegTokenPrice(token, nativePrice);

            if (pegPrice != 0) prices[i] = pegPrice;
            else prices[i] = getRawLPPrice(token, nativePrice);
        }
    }

    //Calculate LP token value in USD. Generally compatible with any UniswapV2 pair but will always price underlying
    //tokens using ape prices. If the provided token is not a LP, it will attempt to price the token as a
    //standard token. This is useful for MasterChef farms which stake both single tokens and pairs
    function getRawLPPrice(address lp, uint nativePrice) internal view returns (uint) {
        //if not a LP, handle as a standard token

        try IApePair(lp).getReserves() returns (uint112 reserve0, uint112 reserve1, uint32) {
            address token0 = IApePair(lp).token0();
            address token1 = IApePair(lp).token1();
            uint totalSupply = IApePair(lp).totalSupply();

            //price0*reserve0+price1*reserve1
            uint totalValue = getRawPrice(token0, nativePrice) * reserve0 + getRawPrice(token1, nativePrice) * reserve1;
            return totalValue / totalSupply;
        } catch {
            return getRawPrice(lp, nativePrice);
        }
    }

    // checks for primary tokens and returns the correct predetermined price if possible, otherwise calculates price
    function getRawPrice(address token, uint nativePrice) internal view returns (uint rawPrice) {
        uint pegPrice = pegTokenPrice(token, nativePrice);

        if (pegPrice != 0) return pegPrice;

        uint numTokens;
        uint pairedValue;
        uint lpTokens;
        uint lpValue;

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

    function pegTokenPrice(address token, uint nativePrice) private pure returns (uint) {
        if (token == USDT || token == USDC || token == DAI) return PRECISION;
        if (token == WNATIVE) return nativePrice;
        return 0;
    }

    function pegTokenPrice(address token) private view returns (uint) {
        if (token == USDT || token == USDC || token == DAI) return PRECISION;
        if (token == WNATIVE) return getNativePrice();
        return 0;
    }

    //returns the number of tokens and the USD value within a single LP. peg is one of the listed primary, pegPrice is the predetermined USD value of this token
    function pairTokensAndValue(address token, address peg) private view returns (uint tokenNum, uint pegValue) {
        address tokenPegPair = pairFor(token, peg);
        // if the address has no contract deployed, the pair doesn't exist
        uint256 size;
        assembly {
            size := extcodesize(tokenPegPair)
        }

        if (size == 0) return (0, 0);

        try IApePair(tokenPegPair).getReserves() returns (uint112 reserve0, uint112 reserve1, uint32) {
            uint reservePeg;
            (tokenNum, reservePeg) = token < peg ? (reserve0, reserve1) : (reserve1, reserve0);
            pegValue = reservePeg * pegTokenPrice(peg);
        } catch {
            return (0, 0);
        }
    }

    //normalize a token price to a specified number of decimals
    function normalize(uint price, address token, uint _decimals) private view returns (uint) {
        uint tokenDecimals;

        try IERC20Metadata(token).decimals() returns (uint8 dec) {
            tokenDecimals = dec;
        } catch {
            tokenDecimals = 18;
        }

        if (tokenDecimals + _decimals <= 2 * DECIMALS) return price / 10 ** (2 * DECIMALS - tokenDecimals - _decimals);
        else return price * 10 ** (_decimals + tokenDecimals - 2 * DECIMALS);
    }

    function tokensAreSorted(address tokenA, address tokenB) private pure returns (bool) {
        return tokenA < tokenB;
    }

    function sortTokens(address tokenA, address tokenB) private pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address tokenA, address tokenB) private pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);

        pair = address(
            uint160(
                uint(
                    keccak256(
                        abi.encodePacked(hex'ff', FACTORY, keccak256(abi.encodePacked(token0, token1)), INITCODEHASH)
                    )
                )
            )
        );
    }
}
