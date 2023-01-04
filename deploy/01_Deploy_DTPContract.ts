import { Signer } from "ethers";
import { keccak256, toUtf8Bytes } from "ethers/lib/utils";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DTPContract, DTPContract__factory } from "../typechain";
import 'dotenv-flow/config';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    let accounts: Signer[];
    let dtpContract: DTPContract;

    accounts = await hre.ethers.getSigners();
    let owner = accounts[0];
    const contractOwner = process.env.DTP_CONTRACT_OWNER_ADDRESS || await owner.getAddress();

    console.log("contractOwner: ", contractOwner);

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

    // const FEE_ROLE = keccak256(toUtf8Bytes("FEE_ROLE"));
    // let feeAccountAddress = await accounts[1].getAddress();
    // const roletx = await dtpContract.grantRole(FEE_ROLE, feeAccountAddress);
    // await roletx.wait();
    // console.log("FEE Role have been granted to ", feeAccountAddress);

    
};
export default func;
func.id = "dtp_contract_deploy";
func.tags = ["local"];
