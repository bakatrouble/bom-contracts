import { MockContract, smock } from '@defi-wonderland/smock';
import { expect, use } from 'chai';
import { NFT, NFT__factory } from '../typechain';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from 'hardhat';

use(smock.matchers);


describe('nft', async () => {
    let nft: MockContract<NFT>;
    let admin: SignerWithAddress;

    beforeEach(async () => {
        [ admin ] = await ethers.getSigners();

        const nftMockFactory = await smock.mock<NFT__factory>('NFT');
        nft = await nftMockFactory.deploy();
    });

    it('should initially have isPresale = true', async () => {
        expect(await nft.isPresale()).to.be.true;
    })
});
