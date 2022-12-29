import { task, types } from "hardhat/config";
import { BigNumber, constants } from "ethers";
import { setBalance }  from "@nomicfoundation/hardhat-network-helpers";



// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (args, hre) => {
    const accounts = await hre.ethers.getSigners();

    for (const account of accounts) {
        console.log(await account.address);
    }
});


task("setBalance", "Fund an account with ethers")
  .addOptionalParam("account", "The account to fund in ethers", "0xF046bCa0D18dA64f65Ff2268a84f2F5B87683C47", types.string)
  .addOptionalParam("amount", "The amount to fund", 100, types.int)
  .setAction(
    async (taskArgs: any, hre: any) => {

    const amount = BigNumber.from(taskArgs.amount).mul(constants.WeiPerEther);

    console.log("Set Balance of account", taskArgs.account, "with", amount.toString(), "wei");

    setBalance(taskArgs.account, amount);

    });

task("fund", "Fund an account with ethers")
    .addOptionalParam("account", "The account to fund in ethers", "0xF046bCa0D18dA64f65Ff2268a84f2F5B87683C47", types.string)
    .addOptionalParam("amount", "The amount to fund", 100, types.int)
    .setAction(
      async (taskArgs: any, hre: any) => {
  
      const accounts = await hre.ethers.getSigners();
      const owner = accounts[0]
  
      const amount = BigNumber.from(taskArgs.amount).mul(constants.WeiPerEther);
  
      console.log("Funding account", taskArgs.account, "with", amount.toString(), "wei");
  
 
      let tx = await owner.sendTransaction({
          to: taskArgs.account,
          value: amount // 100 ether
        });
      
    });
  

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

export default {
    solidity: "0.8.4",
};
