import "@nomiclabs/hardhat-ethers";
import { task } from "hardhat/config";

task("evm_mine", "mine a block")
    .setAction(
        async (taskArgs: any, hre: any) => {
            await hre.network.provider.request({
                method: "evm_mine",
                params: [],
            });
        });


task("getlatestblock", "get a block")
    .setAction(
        async (taskArgs: any, hre: any) => {
            const latestBlock = await hre.ethers.provider.getBlock("latest");
            console.log(latestBlock);
            return latestBlock;
        });