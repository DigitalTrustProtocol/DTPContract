import { Signer } from "ethers";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DTPContract, DTPContract__factory } from "../typechain";
import 'dotenv-flow/config';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    let accounts: Signer[];
    let dtpContract: DTPContract;

    accounts = await hre.ethers.getSigners();
    const contractOwner = process.env.DTP_CONTRACT_OWNER_ADDRESS || await accounts[0].getAddress();

    console.log(await accounts[0].getAddress());

    const tokenFactory = (await hre.ethers.getContractFactory(
        "DTPContract",
        accounts[0]
    )) as DTPContract__factory;

    dtpContract = await tokenFactory.deploy();
    console.log(`DTPContract address: ${dtpContract.address}`);
    await dtpContract.deployed();
    console.log("DTPContract Deployed.");

    const tx = await dtpContract.setNativeToken(true, 0);
    await tx.wait();
    console.log("Native token set to true and fee set to 0");

};
export default func;
func.id = "dtp_contract_deploy";
func.tags = ["local"];
