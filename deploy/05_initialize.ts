import { DeployFunction } from 'hardhat-deploy/dist/types';

const deployFunc: DeployFunction = async ({ getNamedAccounts, deployments, ethers }) => {
    // let dep = deployments.get('Treasury');
    const { deployer } = await getNamedAccounts();
    const { execute, get } = deployments;

    const AddressZero = ethers.constants.AddressZero;
    const PancakeRouter = '0xD99D1c33F9fC3444f8101754aBC46c52416550D1';
    const Owner = '0x22f60E6BD7973c226979B6F57BC92C2d66a8c151';
    const BUSD = '0x78867bbeef44f2326bf8ddd1941a4439382ef2a7';
    const WETH = '0x1e33833a035069f42d68d1f53b341643de1c018d';
    const RedTrustWallet = '0x22f60E6BD7973c226979B6F57BC92C2d66a8c151';

    const treasuryAddress = (await get('Treasury')).address;
    const furnaceAddress = (await get('RedFurnace')).address;
    const nftAddress = (await get('NFT')).address;
    const marketAddress = (await get('Marketplace')).address;
    const tokenAddress = (await get('BabiesOfMars')).address;

    const token = await ethers.getContractAt('BabiesOfMars', tokenAddress);

    await execute('Treasury', {
        from: deployer,
        log: true,
    }, 'initialize', Owner)

    await execute('BabiesOfMars', {
        from: deployer,
        log: true,
    }, 'initialize', PancakeRouter, Owner, treasuryAddress, RedTrustWallet, nftAddress, furnaceAddress);

    await execute('NFT', {
        from: deployer,
        log: true,
    }, 'initialize', 'NFT Name', 'NFTS', treasuryAddress, RedTrustWallet, tokenAddress, 200, 200, 200, await token.pair(), PancakeRouter, BUSD, WETH);

    await execute('Marketplace', {
        from: deployer,
        log: true,
    }, 'initialize', 200, treasuryAddress, nftAddress, tokenAddress);

};

const tags = ['Initialize'];
const dependencies = ['Treasury', 'Furnace', 'NFT', 'Marketplace', 'Token']

export default deployFunc;
export { tags, dependencies };
