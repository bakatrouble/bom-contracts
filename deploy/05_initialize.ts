import { DeployFunction } from 'hardhat-deploy/dist/types';
import { parseEther } from 'ethers/lib/utils';
import { getCurrentTimestamp } from 'hardhat/internal/hardhat-network/provider/utils/getCurrentTimestamp';
import { constants } from 'ethers';

const deployFunc: DeployFunction = async ({ getNamedAccounts, deployments, ethers }) => {
    // let dep = deployments.get('Treasury');
    const { deployer } = await getNamedAccounts();
    const { execute, get } = deployments;

    const AddressZero = ethers.constants.AddressZero;
    const PancakeRouter = '0xD99D1c33F9fC3444f8101754aBC46c52416550D1';
    const Owner = deployer; //'0x22f60E6BD7973c226979B6F57BC92C2d66a8c151';
    const BUSD = '0xB08B32EC7E2Aa60a4C2f4343E7EB638187163415';
    const WETH = '0xF1960ee684B173cf6c17fCdA5F1dFC366Aba55d3';
    const RedTrustWallet = '0x22f60E6BD7973c226979B6F57BC92C2d66a8c151';

    const treasuryAddress = '0x0Cb09553b2d1Da0459577d7027EdA21d40f2a7Cb'; //(await get('Treasury')).address;
    const furnaceAddress = '0xe1cCbDFaBc90F15F96A658a6e96c27D0f1DA9Bd4'; //(await get('RedFurnace')).address;
    const nftAddress = (await get('NFT')).address;
    const marketAddress = '0x92DE9C3a72d787d16F73e18649139341869f4621'; //(await get('Marketplace')).address;
    const tokenAddress = '0x341D28f61ea857C31BAC30302D88a69f5E8c3ed0'; //(await get('BabiesOfMars')).address;

    const token = await ethers.getContractAt('BabiesOfMars', tokenAddress);
    const pancake = await ethers.getContractAt('IPancakeSwapRouter', PancakeRouter);
    const busd = await ethers.getContractAt('ERC', BUSD);
    const weth = await ethers.getContractAt('ERC', WETH);
    const nft = await ethers.getContractAt('NFT', nftAddress);

    // await execute('Treasury', {
    //     from: deployer,
    //     log: true,
    // }, 'initialize', Owner)
    //
    // await execute('BabiesOfMars', {
    //     from: deployer,
    //     log: true,
    // }, 'initialize', PancakeRouter, Owner, treasuryAddress, RedTrustWallet, nftAddress, furnaceAddress, BUSD);

    // await execute('NFT', {
    //     from: deployer,
    //     log: true,
    // }, 'initialize', 'NFT Name', 'NFTS', treasuryAddress, RedTrustWallet, tokenAddress, 200, 200, 200, await token.pair(), PancakeRouter, BUSD, WETH);

    // await execute('Marketplace', {
    //     from: deployer,
    //     log: true,
    // }, 'initialize', 200, treasuryAddress, nftAddress, tokenAddress);

    // await busd.mint(deployer, parseEther('100000000'));
    // await weth.mint(deployer, parseEther('100000000'));
    // await weth.approve(PancakeRouter, parseEther('100000000'));
    // await weth.approve(PancakeRouter, parseEther('100000000'));

    // await token.approve(PancakeRouter, parseEther('1000000000000000000'));
    // await new Promise((approve) => setTimeout(() => approve(null), 5000));
    // await pancake.addLiquidity(tokenAddress, WETH, 10000000, parseEther('10'), 0, 0, deployer, getCurrentTimestamp() + 1000);
    // await pancake.addLiquidity(tokenAddress, BUSD, 10000000, parseEther('1000'), 0, 0, deployer, getCurrentTimestamp() + 1000);

    console.log(`Treasury: ${treasuryAddress}\nRedFurnace: ${furnaceAddress}\nNFT: ${nftAddress}\nMarketplace: ${marketAddress}\nBabiesOfMars: ${tokenAddress}`);

    // await token.approve(nft.address, constants.MaxUint256);
    // await nft.finishPresale();
    // await new Promise((approve) => setTimeout(() => approve(null), 5000));
    // await nft.mint(10, 0);
    // await new Promise((approve) => setTimeout(() => approve(null), 5000));
    await nft.combineTokens([1, 2], { value: parseEther('.05'), gasLimit: 5000000 });

};

const tags = ['Initialize'];
const dependencies = ['Treasury', 'Furnace', 'NFT', 'Marketplace', 'Token']

export default deployFunc;
export { tags, dependencies };
