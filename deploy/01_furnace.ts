import { DeployFunction } from 'hardhat-deploy/dist/types';

const deployFunc: DeployFunction = async ({ getNamedAccounts, deployments, ethers }) => {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    await deploy('RedFurnace', {
        from: deployer,
        args: [],
        log: true,
    });
};

const tags = ['Furnace'];

export default deployFunc;
export { tags };
