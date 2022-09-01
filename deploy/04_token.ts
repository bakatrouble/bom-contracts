import { DeployFunction } from 'hardhat-deploy/dist/types';

const deployFunc: DeployFunction = async ({ getNamedAccounts, deployments, getChainId }) => {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    await deploy('BabiesOfMars', {
        from: deployer,
        args: [],
        log: true,
    });

};

const tags = ['Token'];

export default deployFunc;
export { tags };
