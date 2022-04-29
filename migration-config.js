function getNetworkConfig(network, accounts) {
    if(["bsc", "bsc-fork"].includes(network)) {
        console.log(`Deploying with ${network} config.`)
        return {
            factoryAddress: '0x0841BD0B734E4F5853f0dD8d7Ea041c241fb0Da6',
            routerAddress: '0xcF0feBd3f17CEf5b47b0cD257aCf6025c5BFf3b7',
            wrappedAddress: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
            feeAddress: '0x94bfE225859347f2B2dd7EB8CBF35B84b4e8Df69',
            liquidityHelper: '0x7BfCD7d5D95b7ce2C4CF30D9e0aB535eD5D34968',
            multicall: '0xC50F4c1E81c873B2204D7eFf7069Ffec6Fbe136D',
        }
    } else if (['testnet', 'testnet-fork'].includes(network)) {
        console.log(`Deploying with ${network} config.`)
        return {
            factoryAddress: '0x152349604d49c2Af10ADeE94b918b051104a143E',
            routerAddress: '0x3380aE82e39E42Ca34EbEd69aF67fAa0683Bb5c1',
            wrappedAddress: '0xae13d989dac2f0debff460ac112a837c89baa7cd'
        }
    } else if (['development'].includes(network)) {
        console.log(`Deploying with ${network} config.`)
        return {
            factoryAddress: '0x804962FAc9268A54dF121f129C4a21d7c0aD70b7',
            routerAddress: '0x',
            wrappedAddress: '0x0000000000000000000000000000000000000000'
        }
    } else if (['polygon', 'polygon-fork'].includes(network)) {
        console.log(`Deploying with ${network} config.`)
        return {
            factoryAddress: '0xCf083Be4164828f00cAE704EC15a36D711491284',
            routerAddress: '0xC0788A3aD43d79aa53B09c2EaCc313A787d1d607',
            wrappedAddress: '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270'
        }
    } else if (['polygonTestnet', 'polygonTestnet-fork'].includes(network)) {
        console.log(`Deploying with ${network} config.`)
        return {
            factoryAddress: '0xe145a77c21437e3FD32ce2731833114F0B53405b',
            routerAddress: '0x',
            wrappedAddress: '0x'
        }
    } else {
        throw new Error(`No config found for network ${network}.`)
    }
}

module.exports = { getNetworkConfig };
