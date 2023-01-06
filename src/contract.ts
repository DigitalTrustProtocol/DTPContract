import { getAppSettings } from './appSettings';
import { Contract, Signer, BigNumber, getDefaultProvider, providers } from 'ethers';
import { parseUnits } from "ethers/lib/utils";
import { DTPContract, DTPContract__factory } from "../typechain";
import Provider from '@ethersproject/providers';

export const Claim = {
    
}


export type Claim = {
    claimId: string;
    typeId: string; // The cliam type. e.g. trust.1
    issuer: string;
    subject: string;
    value: string; // 1,0,-1 (-x to +x) are the primary. Anything goes as its the typeId
    context: string; // The context of the claim. E.g. (crypto.evm.chain:1)
    comment: string; // short message, including keywords (#). Safe?!
    link: string; // link to a resource. Eg. a website or email etc.
    activate: any;
    expires: any;
    }

export const claimTypeId = {
    Delegate1: "Delegate1", // Delegate the the graph to another entity. Entity can delegate to another entity, by signing a message of both entities.
    Trust1: "Trust1", // Trust another entity. Entity can trust another entity.
    Distance: "Distance", // Distance between two entities. Entity can set the distance between two entities.
    Audit100: "Audit100", // Audit100, the entity has been audited. The entity has been audited by the issuing party. The value range is 0-100.
    Rating100: "Rating100", // Rating100, the entity has been rated. The entity has been rated by the issuing party. The value range is 0-100.
    Confirm: "Confirm", // Confirm the entity, that entity exists. That the entity is not a fake. The entity has been confirmed by the issuing party.
    Follow: "Follow", // Follow the entity. The entity has been followed by the issuing party.
    DisplayName: "DisplayName", // Display name of the entity. The entity has been given a display name by the issuing party.
    Name: "Name", // Name of the entity. The entity address has been calculated from the name.
}


export const context = {
    chainLocal: "crypto.evm.chain:1337",
    chainEthereum: "crypto.evm.chain:1",
    chainBSC: "crypto.evm.chain:56",
    chainPolygon: "crypto.evm.chain:137",
    chainArbitrum: "crypto.evm.chain:42161",
    chainFantom: "crypto.evm.chain:250",
    chainAvalanche: "crypto.evm.chain:43114",
    chainHarmony: "crypto.evm.chain:1666600000",
    chainxDai: "crypto.evm.chain:100",
    chainMoonbeam: "crypto.evm.chain:1287",
    chainCelo: "crypto.evm.chain:42220",
    chainOptimism: "crypto.evm.chain:10",
    chainKovan: "crypto.evm.chain:42",
    chainRinkeby: "crypto.evm.chain:4",
    chainRopsten: "crypto.evm.chain:3",
    chainGoerli: "crypto.evm.chain:5",
    chainBSCTestnet: "crypto.evm.chain:97",
}


export const DTPContractABI = DTPContract__factory.abi;

export function getDTPContract(chainId: number, signer?: Signer | providers.Provider | undefined) : DTPContract {
    let settings: any = getAppSettings(chainId);

    //console.log(`Connecting to DTP contract: ${settings.dtpContract} on network ${chainId}`);
    
    if(!signer) {
        // Default: http://localhost:8545
        let provider = new providers.JsonRpcProvider("http://0.0.0.0:8545", 1337);

        signer = provider.getSigner();
    }

    const result = new Contract(settings.dtpContract, DTPContract__factory.abi, signer) as DTPContract;
    //console.log("Connected to DTP contract");
    return result;
}

export async function getDTPContractLogs(chainId: number) : Promise<any> {
    const contract = getDTPContract(chainId, undefined);
    const filter = await contract.filters.ClaimPublished();
    const logs = await contract.queryFilter(filter, 0, "latest");
    return logs;
}



export async function setBalance(hre: any, signer: any, amount: BigNumber) {
  
  await hre.network.provider.request({
    method: "hardhat_setBalance",
    params: [signer, amount.toHexString()],
  });
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

