function getNetworkConfig(network, accounts) {
    if(["bsc", "bsc-fork"].includes(network)) {
        console.log(`Deploying with BSC MAINNET config.`)
        return {
            factoryAddress: '0x',
            wrappedAddress: '0x'
        }
    } else if (['testnet', 'testnet-fork'].includes(network)) {
        console.log(`Deploying with BSC testnet config.`)
        return {
            factoryAddress: '0x152349604d49c2Af10ADeE94b918b051104a143E',
            wrappedAddress: '0xae13d989dac2f0debff460ac112a837c89baa7cd'
        }
    } else if (['development'].includes(network)) {
        console.log(`Deploying with development config.`)
        return {
            factoryAddress: '0x804962FAc9268A54dF121f129C4a21d7c0aD70b7',
            wrappedAddress: '0x'
        }
    } else if (['polygon', 'polygon-fork'].includes(network)) {
        console.log(`Deploying with development config.`)
        return {
            factoryAddress: '0x',
            wrappedAddress: '0x'
        }
    } else if (['polygonTestnet', 'polygonTestnet-fork'].includes(network)) {
        console.log(`Deploying with development config.`)
        return {
            factoryAddress: '0xe145a77c21437e3FD32ce2731833114F0B53405b',
            wrappedAddress: '0x'
        }
    } else {
        throw new Error(`No config found for network ${network}.`)
    }
}

module.exports = { getNetworkConfig };
