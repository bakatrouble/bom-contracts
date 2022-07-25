/**
 * @type import('hardhat/config').HardhatUserConfig
 */

import { task } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import "@openzeppelin/hardhat-upgrades";
import "@typechain/hardhat";
import "hardhat-tracer";
import "hardhat-gas-reporter";
import "hardhat-dependency-compiler";
import "hardhat-deploy";

require('dotenv').config();

let {
    ETHERSCAN_TOKEN,
    BSCSCAN_TOKEN,
    PRIVATE_KEY
} = process.env;

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

task("accounts", "Prints the list of accounts", async (args, { ethers }) => {
    const accounts = await ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
let networks;

if(PRIVATE_KEY) {
    let accounts = [
        PRIVATE_KEY
    ]
    networks = {
        hardhat: {},
        bsc: {
            url: "https://bsc-dataseed.binance.org/",
            chainId: 56,
            gasPrice: 5000000000,
            accounts
        },
        bscTestnet: {
            url: "https://data-seed-prebsc-1-s1.binance.org:8545",
            chainId: 97,
            gasPrice: 10000000000,
            accounts
        },
        rinkeby: {
            url: "https://eth-rinkeby.alchemyapi.io/v2/v92DVe9FFvr2lzRB4wjtk-z4DdsQjBhs",
            gasPrice: 5000000000,
            accounts
        },
        ropsten: {
            url: "https://eth-ropsten.alchemyapi.io/v2/v92DVe9FFvr2lzRB4wjtk-z4DdsQjBhs",
            gasPrice: 20000000000,
            accounts
        },
        kovan: {
            url: "https://eth-kovan.alchemyapi.io/v2/v92DVe9FFvr2lzRB4wjtk-z4DdsQjBhs",
            gasPrice: 20000000000,
            accounts
        },
        goerli: {
            url: "https://eth-goerli.alchemyapi.io/v2/v92DVe9FFvr2lzRB4wjtk-z4DdsQjBhs",
            gasPrice: 20000000000,
            accounts
        },
    };
} else {
    networks = {
        hardhat: {},
    };
}

module.exports = {
    defaultNetwork: "hardhat",
    networks: networks,
    etherscan: {
        apiKey: {
            mainnet:ETHERSCAN_TOKEN,
            rinkeby:ETHERSCAN_TOKEN,
            ropsten:ETHERSCAN_TOKEN,
            kovan:ETHERSCAN_TOKEN,
            bscTestnet:BSCSCAN_TOKEN,
            goerli:ETHERSCAN_TOKEN
        }
    },
    dependencyCompiler: {
    },
    namedAccounts: {
        deployer: 0,
    },
    abiExporter: {
        path: './artifacts/abi',
        clear: true,
        flat: true,
        only: [':Bithotel'],
        spacing: 2
    },
    solidity: {
        version: "0.8.15",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200
            }
        }
    },
    typechain: {
        outDir: "typechain",
        target: "ethers-v5",
    },
};

