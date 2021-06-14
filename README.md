# ApeSwap Periphery

The ApeSwap periphery contracts, commonly known as the "Router", handles important checks regarding interacting with the [core DEX contracts](https://github.com/ApeSwapFinance/apeswap-swap-core). This is related to the main functionality of the DEX which includes adding/removing liquidity and swapping tokens.   

The periphery contracts are unique in that they don't hold any value, it just manages transferring the proper amount of tokens to the proper contracts for the core DEX contracts to properly do their work.   

Because the periphery contracts hold no value, they can be easily upgraded and improved without requiring a DEX migration.   
<br>
## Configuration

### Environment
To deploy/verify contracts copy [.env.example](./.env.example) and rename it `.env`. Fill in the variables in this file to deploy to different networks and verify the contracts after.  
<br>

### Truffle
The [truffle-config.js](./truffle-config.js) is used to configure deployable networks 
<br>
   
### Setting up a new DEX

Deploying a periphery contract to work with a new set of DEX core contracts requires an update to the contract code for [ApeLibrary.sol](./contracts/libraries/ApeLibrary.sol) in the `pairFor` function. 

This function pre-computes a pair address before creation and requires that the `hex` value match the `INIT_CODE_PAIR_HASH` of the core pair contract. On the deployed factory that the periphery contract is intended to be linked to, there is a public variable `INIT_CODE_PAIR_HASH` that should be used to replace the `hex` value in `ApeLibrary.sol`. (Remember to remove the `0x` before the hash)
<br>

## Commands

The following assumes the use of `node@>=12`.
<br>

## Install Dependencies

`yarn`
<br>

## Compile Contracts

`npx truffle compile`
<br>

## Run Tests

`yarn test`
<br>

## Migrate Contracts 
Once the migration seed phrases are setup in `.env` and the `truffle-config.js` is configured for the network of your choice, contracts can be deployed to a specific network using: `npx truffle migrate --network <network-name>`
<br>

## Local Development 
- Start a local blockchain `npx ganache-cli` 
- Deploy to local blockchain `npx truffle migrate --network development` 
<br>
