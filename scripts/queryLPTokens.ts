require('dotenv').config();
import { getDefaultProvider, utils, Wallet } from 'ethers'
import { Contract, PopulatedTransaction } from '@ethersproject/contracts'
import { readJSONFile, writeJSONToFile, writeJSONToFileWithDate } from './utils/files'
import { multicall, Call } from './utils/multicall';
const { getNetworkConfig } = require("../migration-config");

import ApeFactoryBuild from '../build-apeswap-dex/contracts/ApeFactory.json'
import MulticallBuild from '../build/contracts/Multicall2.json'

(async function () {
    const ADDRESS_LIST_FILEPATH = __dirname + '/../constants/bsc/ApePairAddresses';
    const pairAddresses: string[] = await readJSONFile(ADDRESS_LIST_FILEPATH);
    const { factoryAddress, slippageFactor, routerAddress, baseRoutes, multicall: multicallAddress } = getNetworkConfig('bsc');
    const provider = getDefaultProvider('https://bsc-dataseed1.binance.org')
    // setup contracts
    const multicallContract = new Contract(multicallAddress, MulticallBuild.abi, provider);
    const apeFactoryContract = new Contract(factoryAddress, ApeFactoryBuild.abi, provider);
    // get total pairs
    const pairLength = (await apeFactoryContract.allPairsLength()).toNumber();
    // setup multicall
    const callDataArray: Call[] = [];
    for (let pairId = pairAddresses.length; pairId < pairLength; pairId++) {
        callDataArray.push({
            address: apeFactoryContract.address,
            functionName: 'allPairs',
            params: [pairId]
        });
    };
    // Add additional pair addresses if any
    if(callDataArray.length) {
        const returnedData = await multicall(multicallContract, ApeFactoryBuild.abi, callDataArray);
        // Pull addresses out of return data
        const cleanedData = returnedData.map((dataArray) => dataArray[0]);
        const updatedPairAddresses = [...pairAddresses, ...cleanedData];
        await writeJSONToFileWithDate(ADDRESS_LIST_FILEPATH, updatedPairAddresses);
        await writeJSONToFile(ADDRESS_LIST_FILEPATH, updatedPairAddresses);
        console.log(`Saved pairs to file. See ${ADDRESS_LIST_FILEPATH}.json`);
    }

    console.log(`Total pairs: ${pairLength.toString()}.`);
    console.log(`Added ${callDataArray.length} new pairs!`)

    process.exit(0);
}());

