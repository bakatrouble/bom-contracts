import { getImplementationAddress } from '@openzeppelin/upgrades-core';
import { parseEther } from 'ethers/lib/utils';
import { getCurrentTimestamp } from 'hardhat/internal/hardhat-network/provider/utils/getCurrentTimestamp';
import { DeployFunction } from 'hardhat-deploy/dist/types';

require('dotenv').config();

const deployFunc: DeployFunction = async ({ ethers, run, deployments, getChainId, upgrades }) => {
    const { execute, get } = deployments;
    const { deploy } = deployments;
    const [deployer] = await ethers.getSigners();
    const ProxyAdmin = await deployments.get('BoMProxyAdmin');
    let arrayToVefiry = [];

    const AddressZero = ethers.constants.AddressZero;
    const PancakeRouter = '0xD99D1c33F9fC3444f8101754aBC46c52416550D1';
    const Owner = '0x22f60E6BD7973c226979B6F57BC92C2d66a8c151';
    const BUSD = '0xB08B32EC7E2Aa60a4C2f4343E7EB638187163415';
    const WETH = '0xF1960ee684B173cf6c17fCdA5F1dFC366Aba55d3';
    const RedTrustWallet = '0x22f60E6BD7973c226979B6F57BC92C2d66a8c151';

    const furnaceAddress = (await get('RedFurnace')).address;
    const nftMetadataAddress = (await get('NFTMetadata')).address;
    const pancake = await ethers.getContractAt('IPancakeSwapRouter', PancakeRouter);

    //Treasury
    const factoryTreasury = await ethers.getContractFactory('Treasury');
    let deployedTreasury = await deployments.getOrNull('Treasury');
    let bomTreasury;
    if (deployedTreasury) {
        bomTreasury = await upgrades.upgradeProxy(deployedTreasury.address, factoryTreasury);
    } else {
        bomTreasury = await upgrades.deployProxy(factoryTreasury);
        await bomTreasury.deployed();
    }
    //@ts-ignore
    await deployments.save('Treasury', bomTreasury)
    arrayToVefiry.push({ address: bomTreasury.address, path: 'contracts/Treasury.sol:Treasury' })

    //Token
    const tokenFactory = await ethers.getContractFactory('BabiesOfMars');
    let deployedToken = await deployments.getOrNull('BabiesOfMars');
    let BoM;
    if (deployedToken) {
        BoM = await upgrades.upgradeProxy(deployedToken.address, tokenFactory);
    } else {
        BoM = await upgrades.deployProxy(tokenFactory, [PancakeRouter, Owner, bomTreasury.address, RedTrustWallet, furnaceAddress, BUSD]);
        await BoM.deployed();
    }
    //@ts-ignore
    await deployments.save('BabiesOfMars', BoM)
    arrayToVefiry.push({ address: BoM.address, path: 'contracts/token.sol:BabiesOfMars' })

    //NFT
    let pair = await BoM.connect(deployer).pair()
    const factoryNFT = await ethers.getContractFactory('NFT');
    let deployed = await deployments.getOrNull('NFT');
    let bomNFT;
    if (deployed) {
        bomNFT = await upgrades.upgradeProxy(deployed.address, factoryNFT);
    } else {
        bomNFT = await upgrades.deployProxy(factoryNFT, [
            'NFT Name', 'NFTS', bomTreasury.address, RedTrustWallet, BoM.address, 200, 200, 200, pair, PancakeRouter, BUSD, WETH
        ]);
        await bomNFT.deployed();
    }

    //@ts-ignore
    await deployments.save('NFT', bomNFT)
    arrayToVefiry.push({ address: bomNFT.address, path: 'contracts/nft.sol:NFT' })

    //Market
    const marketFactory = await ethers.getContractFactory('Marketplace');
    let deployedMarket = await deployments.getOrNull('Marketplace');
    let bomMarket;
    if (deployedMarket) {
        bomMarket = await upgrades.upgradeProxy(deployedMarket.address, marketFactory);
    } else {
        bomMarket = await upgrades.deployProxy(marketFactory, [
            200, bomTreasury.address, bomNFT.address, BoM.address
        ]);
        await bomMarket.deployed();
    }

    //@ts-ignore
    await deployments.save('Marketplace', bomMarket)
    arrayToVefiry.push({ address: bomMarket.address, path: 'contracts/market.sol:Marketplace' })

    await BoM.connect(deployer).adminUpdatePoolAddress(bomNFT.address)
    await bomNFT.connect(deployer).updateMetadata(nftMetadataAddress)

    await BoM.connect(deployer).approve(PancakeRouter, parseEther('1000000000000000000'));
    await new Promise((approve) => setTimeout(() => approve(null), 5000));
    await pancake.addLiquidity(BoM.address, WETH, 10000000, parseEther('10'), 0, 0, deployer.address, getCurrentTimestamp() + 1000);
    await pancake.addLiquidity(BoM.address, BUSD, 10000000, parseEther('1000'), 0, 0, deployer.address, getCurrentTimestamp() + 1000);


    //implementation verification
    for (let proxy of arrayToVefiry) {
        const currentImplAddress = await getImplementationAddress(ethers.provider, proxy.address);
        console.log(`${proxy.address} => ${currentImplAddress}`)
        try {
            await run('verify:verify', {
                address: currentImplAddress,
                contract: proxy.path
            });
        } catch (error) {
            console.log(`${currentImplAddress} is already verified`)
        }
    }
    console.log(`Treasury: ${bomTreasury.address}\nRedFurnace: ${furnaceAddress}\nNFT: ${bomNFT.address}\nMarketplace: ${bomMarket.address}\nBabiesOfMars: ${BoM.address}`);

};
module.exports.tags = ['Treasury', 'NFT', 'Marketplace', 'Token']
module.exports.dependencies = ['ProxyAdmin', 'NFTMetadata', 'Furnace']

export default deployFunc;
