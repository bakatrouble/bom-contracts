import { MockContract, smock } from '@defi-wonderland/smock';
import { expect, use } from 'chai';
import {
    BabiesOfMars, BabiesOfMars__factory, ERC, IERC20,
    Marketplace,
    Marketplace__factory,
    NFT,
    NFT__factory,
    Treasury,
    Treasury__factory
} from '../typechain';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from 'hardhat';
import { parseEther } from 'ethers/lib/utils';
import { getCurrentTimestamp } from 'hardhat/internal/hardhat-network/provider/utils/getCurrentTimestamp';
import { constants } from 'ethers';
import { increase } from '@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time';
import { mineUpTo } from '@nomicfoundation/hardhat-network-helpers';

use(smock.matchers);

const PancakeRouter = '0xD99D1c33F9fC3444f8101754aBC46c52416550D1';
const BUSD = '0xB08B32EC7E2Aa60a4C2f4343E7EB638187163415';
const WETH = '0xF1960ee684B173cf6c17fCdA5F1dFC366Aba55d3';
const RedTrustWallet = '0x22f60E6BD7973c226979B6F57BC92C2d66a8c151';

describe('test', async () => {
    let admin: SignerWithAddress;

    let treasury: MockContract<Treasury>;
    let furnace: SignerWithAddress;
    let nft: MockContract<NFT>;
    let market: MockContract<Marketplace>;
    let token: MockContract<BabiesOfMars>;
    let pancake;
    let busd: ERC, weth: ERC;

    beforeEach(async () => {
        // await ethers.provider.send("hardhat_reset", []);

        [ admin, furnace ] = await ethers.getSigners();

        console.log(`block ${await ethers.provider.getBlockNumber()}`);

        treasury = await (await smock.mock<Treasury__factory>('Treasury')).deploy();
        nft = await (await smock.mock<NFT__factory>('NFT')).deploy();
        market = await (await smock.mock<Marketplace__factory>('Marketplace')).deploy();
        token = await (await smock.mock<BabiesOfMars__factory>('BabiesOfMars')).deploy();

        // treasury = await ethers.getContractAt('Treasury', '0xcC54B2b303789BFa48895eC4750C873d575B0cC4');
        // nft = await ethers.getContractAt('NFT', '0x6539ABB7a32B17a18d3C27AEbEdCbC8d19b8f005');
        // market = await ethers.getContractAt('Marketplace', '0x8226476d393eC96fd0D560E5B969E6Eeb8d5eDc5');
        // token = await ethers.getContractAt('BabiesOfMars', '0x026F2786324230FDDb7189A5ecA1b2eE9d7E1027');

        console.log(`Treasury: ${treasury.address}\nRedFurnace: ${furnace.address}\nNFT: ${nft.address}\nMarketplace: ${market.address}\nBabiesOfMars: ${token.address}`);

        pancake = await ethers.getContractAt('IPancakeSwapRouter', PancakeRouter);
        busd = await ethers.getContractAt('ERC', BUSD);
        weth = await ethers.getContractAt('ERC', WETH);

        await treasury.initialize(admin.address);
        await token.initialize(PancakeRouter, admin.address, treasury.address, RedTrustWallet, nft.address, furnace.address, BUSD)
        await nft.initialize('NFT Name', 'NFTS', treasury.address, RedTrustWallet, token.address, 200, 200, 200, await token.pair(), PancakeRouter, BUSD, WETH)
        await market.initialize(200, treasury.address, nft.address, token.address);

        await busd.mint(admin.address, parseEther('100000000000000000000000000'));
        await weth.mint(admin.address, parseEther('100000000000000000000000000'));

        await token.approve(pancake.address, parseEther('1000000000000000000'));
        await weth.approve(pancake.address, parseEther('1000000000000000000'));
        await busd.approve(pancake.address, parseEther('1000000000000000000'));


        await pancake.addLiquidity(token.address, weth.address, 100, parseEther('10'), 0, 0, admin.address, getCurrentTimestamp() + 100);

        await pancake.addLiquidity(token.address, busd.address, 100, parseEther('1000'), 0, 0, admin.address, getCurrentTimestamp() + 100);
    });

    it('should initially have isPresale = true', async () => {
        await token.approve(nft.address, constants.MaxUint256);
        await nft.finishPresale();
        await nft.mint(10, 0);
        await nft.combineTokens([1, 2], { value: parseEther('.05') });
        // expect(await nft.isPresale()).to.be.true;
    })
});
