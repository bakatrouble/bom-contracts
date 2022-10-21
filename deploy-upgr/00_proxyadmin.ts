module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  await deploy("BoMProxyAdmin", {
    from: deployer,
  });
};
module.exports.tags = ["BoMProxyAdmin"];
