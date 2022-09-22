import { DeployFunction } from 'hardhat-deploy/dist/types';

const deployFunc: DeployFunction = async ({ getNamedAccounts, deployments, ethers }) => {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    await deploy('Treasury', {
        from: deployer,
        args: [],
        log: true,
    });
};

const tags = ['Treasury'];

export default deployFunc;
export { tags };
