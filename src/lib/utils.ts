//import { LedgerSigner } from "@northmann/ethers-ledger";
import { BigNumber } from "ethers";
import { parseUnits } from "ethers/lib/utils";


export async function setBalance(hre: any, address: string, amount: BigNumber) {
  
  await hre.network.provider.request({
    method: "hardhat_setBalance",
    params: [address, amount.toHexString()],
  });
}


export async function getSigner(hre: any) {
    //Instantiate the Signer
    let signer: any;
  
    const testing = ["hardhat", "localhost"].includes(hre.network.name);
    console.log("network is testing: ", testing);
  
    signer = await hre.ethers.getSigner();
    console.log("Default hardhat Signer: ", await signer.getAddress());

    return signer;
  }
  
  
  export function getFunctionSignatures(contract: any) : string[] {
    const signatures = Object.keys(contract.interface.functions)
    const names = signatures.reduce((acc: any, val: string) => {
        if (val !== 'init(bytes)') {
            acc.push(val)
        }
        return acc
    }, [])
    return names;
  }

  
export async function deployContract(hre: any, contractName: any, signer: any, ...args: any) {
  const Contract = await hre.ethers.getContractFactory(contractName, signer);
  const instance = await Contract.deploy(...args);
  console.log(`${contractName} contract deployed to ${instance.address}`);

  return instance;
}