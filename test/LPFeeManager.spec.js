const { balance, expectRevert, time, ether, BN } = require('@openzeppelin/test-helpers');
const { accounts, contract } = require('@openzeppelin/test-environment');
const { expect, assert } = require('chai');
const { getNetworkConfig } = require("../migration-config.js");

const ApeFactoryBuild = require('../build-apeswap-dex/contracts/ApeFactory.json');
const ApeFactory = contract.fromABI(ApeFactoryBuild.abi, ApeFactoryBuild.bytecode);

// Load compiled artifacts
const LPFeeManager = contract.fromArtifact("LPFeeManager");
const ApeRouter = contract.fromArtifact("ApeRouter");
const ERC20Mock = contract.fromArtifact("ERC20Mock");
const IApePair = contract.fromArtifact("IApePair");

describe('LPFeeManager', function () {
    const [minter, proxyAdmin, adminAddress, feeToSetter, feeAddress, alice, bob, carol, dan] = accounts;
    const { wrappedAddress } = getNetworkConfig('development', accounts)

    let feeManager = null;
    let dexFactory = null;
    let dexRouter = null;
    let btc = null;
    let eth = null;
    let bnb = null;
    let busd = null;
    let shib = null;
    let BTCBUSD = null;
    let ETHBUSD = null;
    let BTCETH = null;
    let ETHBNB = null;
    let SHIBBUSD = null;

    beforeEach(async function () {
        dexFactory = await ApeFactory.new(feeToSetter);
        dexRouter = await ApeRouter.new(dexFactory.address, wrappedAddress);

        btc = await ERC20Mock.new("Bitcoin", "BTC");
        await btc.mint(minter, ether("99999"));
        await btc.approve(dexRouter.address, ether("99999"), { from: minter });

        eth = await ERC20Mock.new("Ethereum", "ETH");
        await eth.mint(minter, ether("99999"));
        await eth.approve(dexRouter.address, ether("99999"), { from: minter });

        bnb = await ERC20Mock.new("Binance Coin", "BNB");
        await bnb.mint(minter, ether("99999"));
        await bnb.approve(dexRouter.address, ether("99999"), { from: minter });

        busd = await ERC20Mock.new("Binance USD", "BUSD");
        await busd.mint(minter, ether("99999"));
        await busd.approve(dexRouter.address, ether("99999"), { from: minter });

        shib = await ERC20Mock.new("Shiba Inu", "SHIB");
        await shib.mint(minter, ether("99999"));
        await shib.approve(dexRouter.address, ether("99999"), { from: minter });

        feeManager = await LPFeeManager.new([busd.address, eth.address], dexRouter.address, dexFactory.address, 0, adminAddress);

        //Mock of liquidity provider routes
        /**
         * BTC -> BUSD
         * ETH -> BUSD
         * BTC -> ETH
         * ETH -> BNB
         * SHIB -> BUSD 
         */
        await dexRouter.addLiquidity(btc.address, busd.address, ether("100"), ether("1000"), 0, 0, minter, (await time.latest()) + 600, { from: minter });
        await dexRouter.addLiquidity(eth.address, busd.address, ether("250"), ether("1000"), 0, 0, minter, (await time.latest()) + 600, { from: minter });
        await dexRouter.addLiquidity(btc.address, eth.address, ether("100"), ether("250"), 0, 0, minter, (await time.latest()) + 600, { from: minter });
        await dexRouter.addLiquidity(eth.address, bnb.address, ether("250"), ether("400"), 0, 0, minter, (await time.latest()) + 600, { from: minter });
        await dexRouter.addLiquidity(shib.address, busd.address, ether("1234"), ether("1000"), 0, 0, minter, (await time.latest()) + 600, { from: minter });

        //Mock of LP token fees to fee manager
        await dexRouter.addLiquidity(btc.address, busd.address, ether("1"), ether("10"), 0, 0, feeManager.address, (await time.latest()) + 600, { from: minter });
        await dexRouter.addLiquidity(eth.address, busd.address, ether("2.5"), ether("10"), 0, 0, feeManager.address, (await time.latest()) + 600, { from: minter });
        await dexRouter.addLiquidity(btc.address, eth.address, ether("1"), ether("2.5"), 0, 0, feeManager.address, (await time.latest()) + 600, { from: minter });
        await dexRouter.addLiquidity(eth.address, bnb.address, ether("2.5"), ether("4"), 0, 0, feeManager.address, (await time.latest()) + 600, { from: minter });
        await dexRouter.addLiquidity(shib.address, busd.address, ether("12.34"), ether("10"), 0, 0, feeManager.address, (await time.latest()) + 600, { from: minter });

        const btcbusd = await dexFactory.getPair(btc.address, busd.address);
        BTCBUSD = await IApePair.at(btcbusd);
        const ethbusd = await dexFactory.getPair(eth.address, busd.address);
        ETHBUSD = await IApePair.at(ethbusd);
        const btceth = await dexFactory.getPair(btc.address, eth.address);
        BTCETH = await IApePair.at(btceth);
        const ethbnb = await dexFactory.getPair(eth.address, bnb.address);
        ETHBNB = await IApePair.at(ethbnb);
        const shibbusd = await dexFactory.getPair(shib.address, busd.address);
        SHIBBUSD = await IApePair.at(shibbusd);
    })

    it("Should swap lp tokens with no output", async () => {
        await feeManager.swapLiquidityTokens([BTCBUSD.address], "0x0000000000000000000000000000000000000000", adminAddress, { from: adminAddress });
        btcbusdBalance = await BTCBUSD.balanceOf(feeManager.address);
        assert.equal(
            btcbusdBalance,
            0,
            'feeManager should not have any LP tokens left'
        );

        busdBalance = await busd.balanceOf(adminAddress);
        btcBalance = await btc.balanceOf(adminAddress);
        assert.isAbove(
            parseInt(busdBalance.toString()),
            0,
            'admin should receive busd'
        );
        assert.isAbove(
            parseInt(btcBalance.toString()),
            0,
            'admin should receive btc'
        );

        busdBalance = await busd.balanceOf(feeManager.address);
        btcBalance = await btc.balanceOf(feeManager.address);
        assert.equal(
            busdBalance,
            0,
            'feeManager should not receive busd'
        );
        assert.equal(
            btcBalance,
            0,
            'feeManager should not receive btc'
        );
    });

    it("Should swap lp tokens. BTC-BUSD -> BUSD", async () => {
        await feeManager.swapLiquidityTokens([BTCBUSD.address], busd.address, adminAddress, { from: adminAddress });

        btcbusdBalance = await BTCBUSD.balanceOf(feeManager.address);
        assert.equal(
            btcbusdBalance,
            0,
            'feeManager should not have any LP tokens left'
        );

        busdBalance = await busd.balanceOf(feeManager.address);
        btcBalance = await btc.balanceOf(feeManager.address);
        assert.equal(
            busdBalance,
            0,
            'feeManager should not receive busd'
        );
        assert.equal(
            btcBalance,
            0,
            'feeManager should not receive btc'
        );

        busdBalance = await busd.balanceOf(adminAddress);
        assert.isAbove(
            parseInt(busdBalance.toString()),
            0,
            'admin should receive busd'
        );
    });

    it("Should swap lp tokens. BTC-BUSD -> ETH", async () => {
        await feeManager.swapLiquidityTokens([BTCBUSD.address], eth.address, adminAddress, { from: adminAddress });

        btcbusdBalance = await BTCBUSD.balanceOf(feeManager.address);
        assert.equal(
            btcbusdBalance,
            0,
            'feeManager should not have any LP tokens left'
        );

        busdBalance = await busd.balanceOf(feeManager.address);
        btcBalance = await btc.balanceOf(feeManager.address);
        assert.equal(
            busdBalance,
            0,
            'feeManager should not receive busd'
        );
        assert.equal(
            btcBalance,
            0,
            'feeManager should not receive btc'
        );

        ethBalance = await eth.balanceOf(adminAddress);
        assert.isAbove(
            parseInt(ethBalance.toString()),
            0,
            'admin should receive busd'
        );
    });

    it("Should swap lp tokens. BTC-BUSD -> BNB", async () => {
        await feeManager.swapLiquidityTokens([BTCBUSD.address], bnb.address, adminAddress, { from: adminAddress });

        btcbusdBalance = await BTCBUSD.balanceOf(feeManager.address);
        assert.equal(
            btcbusdBalance,
            0,
            'feeManager should not have any LP tokens left'
        );

        busdBalance = await busd.balanceOf(feeManager.address);
        btcBalance = await btc.balanceOf(feeManager.address);
        assert.equal(
            busdBalance,
            0,
            'feeManager should not receive busd'
        );
        assert.equal(
            btcBalance,
            0,
            'feeManager should not receive btc'
        );

        bnbBalance = await bnb.balanceOf(adminAddress);
        assert.isAbove(
            parseInt(bnbBalance.toString()),
            0,
            'admin should receive busd'
        );
    });

    it("Should swap lp tokens. BTC-BUSD + BTC-ETH -> BUSD", async () => {
        await feeManager.swapLiquidityTokens([BTCBUSD.address, BTCETH.address], busd.address, adminAddress, { from: adminAddress });

        btcbusdBalance = await BTCBUSD.balanceOf(feeManager.address);
        assert.equal(
            btcbusdBalance,
            0,
            'feeManager should not have any LP tokens left'
        );
        btceth = await BTCETH.balanceOf(feeManager.address);
        assert.equal(
            btceth,
            0,
            'feeManager should not have any LP tokens left'
        );

        busdBalance = await busd.balanceOf(feeManager.address);
        ethBalance = await eth.balanceOf(feeManager.address);
        btcBalance = await btc.balanceOf(feeManager.address);
        assert.equal(
            busdBalance,
            0,
            'feeManager should not receive busd'
        );
        assert.equal(
            ethBalance,
            0,
            'feeManager should not receive eth'
        );
        assert.equal(
            btcBalance,
            0,
            'feeManager should not receive btc'
        );

        busdBalance = await busd.balanceOf(adminAddress);
        assert.isAbove(
            parseInt(busdBalance.toString()),
            0,
            'admin should receive busd'
        );
    });

    it("Should FAIL swap lp tokens. SHIB-BUSD -> BNB", async () => {
        await expectRevert(feeManager.swapLiquidityTokens([SHIBBUSD.address], bnb.address, adminAddress, { from: adminAddress }), "No path found",);
    });

    it("Should add new path", async () => {
        await feeManager.addPossiblePath(shib.address, { from: adminAddress });

        const newPath = await feeManager.possiblePaths(2);
        assert.equal(
            newPath,
            shib.address,
            'New path not correctly added'
        );
    });
});