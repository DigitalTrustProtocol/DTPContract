import "@nomiclabs/hardhat-ethers";
import { task, types } from "hardhat/config";
import { DTPContract, ClaimStruct } from "../typechain/contracts/DTPContract";

import { getDTPContract, getDTPContractLogs, claimTypeId, scope, context } from '../src/contract';
import { BigNumber, utils, BytesLike, Wallet, Signer } from 'ethers';
import { hardhatArguments } from "hardhat";


//import { ethers } from "hardhat";


//.addOptionalParam("contract", "The address of the ERC721 contract")

task("create-trust", "Creates a new trust claim item")
    .addOptionalParam("subject", "The address of the subject", undefined, types.string)
    .addOptionalParam("value", "Value of the trust", "1", types.string)
    .setAction(async (taskArgs, hre) => {
        const accounts = await hre.ethers.getSigners();
        const contractSubject = taskArgs.subject || await accounts[1].getAddress();

        const chainId: number = 1337;

        const contract: DTPContract = getDTPContract(chainId, hre.ethers.provider.getSigner());

        const claim: ClaimStruct = {
            typeId: claimTypeId.Trust1,
            issuer: "0x0000000000000000000000000000000000000000", // Will automatically be set to the siger in the contract
            subject: contractSubject,
            value: taskArgs.value,
            scope: scope.contract,
            context: context.chainLocal,
            comment: "This is a test trust claim",
            link: "",
            expire: BigNumber.from(0),
            activate: BigNumber.from(0)
        }

        console.log("Creating Trust claim");
        const tx = await contract.publishClaim(claim, "0x0000000000000000000000000000000000000000", BigNumber.from(0));
        const receipt = await tx.wait();
        console.log(`Transaction receipt: ${receipt.transactionHash}`);
    });

task("create-displayname", "Creates a new claim with display name")
    .addOptionalParam("value", "The value of the claim", "John Doe", types.string)
    .setAction(async (taskArgs, hre) => {
        const accounts = await hre.ethers.getSigners();
        const contractSubject = await accounts[0].getAddress();
        // hre.network.config.chainId ||

        const chainId: number = 1337;

        const contract: DTPContract = getDTPContract(chainId, hre.ethers.provider.getSigner());

        const claim: ClaimStruct = {
            typeId: claimTypeId.DisplayName,
            issuer: "0x0000000000000000000000000000000000000000", // Will automatically be set to the siger in the contract
            subject: contractSubject,
            value: taskArgs.value,
            scope: scope.entity,
            context: "",
            comment: "This is a test claim for displayname",
            link: "",
            expire: BigNumber.from(0),
            activate: BigNumber.from(0)
        }

        console.log("Creating Trust claim");
        const tx = await contract.publishClaim(claim, "0x0000000000000000000000000000000000000000", BigNumber.from(0));
        const receipt = await tx.wait();
        console.log(`Transaction receipt: ${receipt.transactionHash}`);
    });


task("getClaim", "Get claim data")
    // .addParam("typeId", "Type Id")
    // .addParam("issuer", "Issuer")
    // .addParam("subject", "Subject")
    // .addParam("scope", "Scope")
    // .addParam("context", "Context")
    .setAction(
        async (taskArgs: any, hre: any) => {
            const chainId: number = 1337;
            //const contract: DTPContract = getDTPContract(chainId, hre.ethers.provider.getSigner());

            //async function mineBlocks(blockNumber) {
                //while (blockNumber > 0) {
//                  blockNumber--;
                  await hre.network.provider.request({
                    method: "evm_mine",
                    params: [],
                  });
  //              }
    //          }

            const latestBlock = await hre.ethers.provider.getBlock("latest");
            console.log("Latest block: ", latestBlock);


        });

task("logs", "Get claim event data")
    .addOptionalParam("start", "The start block", 0, types.int)
    .addOptionalParam("end", "The end block", 999999999, types.int)
    .setAction(
        async (taskArgs: any, hre: any) => {
            const chainId: number = 1337;
            const contract: DTPContract = getDTPContract(chainId);

            const filter = await contract.filters.ClaimPublished();
            console.log("Filter: ", filter);

            const logs = await contract.queryFilter(filter, taskArgs.start, taskArgs.end);
            //const logs = await getDTPContractLogs(chainId);

            console.log(logs);
    });



task("create-claims", "Creates a new trust claim items for all accounts")
    .addOptionalParam("filename", "The Data file", undefined, types.string)
    .setAction(async (taskArgs, hre) => {

        const chainId: number = 1337;

        let data = require('./trustdata.json').claims;
        //console.log(data);


        const reducer = (acc: any, curr: any) => {
            if (!acc[curr[0]]) {
              acc[curr[0]] = [];
            }
            acc[curr[0]].push(curr);
            return acc;
          }
          
        const groupedData = data.reduce(reducer, {});
        const accounts = await hre.ethers.getSigners();
        async function call(key: any, index: any) {
            console.log(key, groupedData[key]);
            const innerData = groupedData[key];
            const issuer = await accounts[key];

            let claims: ClaimStruct[] = [];
            console.log("InnerData: ", innerData.length, " claims");
            for (let i = 0; i < innerData.length; i++) {
    
                let subject: string = (typeof innerData[i][1] === "number") ? await accounts[(innerData[i][1] as number)].getAddress() : (innerData[i][1] as string);
                let typeId = innerData[i][2];
                let value = innerData[i][3];
                
               
                let claim: ClaimStruct = {
                    typeId: typeId,
                    issuer: "0x0000000000000000000000000000000000000000",
                    subject: subject,
                    value: value+"",
                    scope: scope.contract,
                    context: context.chainLocal,
                    comment: "",
                    link: "",
                    expire: BigNumber.from(0),
                    activate: BigNumber.from(0)
                }
                claims[i] = claim;
            }

            console.log("Claims: ", claims.length);
    
            const contract: DTPContract = getDTPContract(chainId, issuer);
            const tx = await contract.publishClaims(claims, "0x0000000000000000000000000000000000000000", BigNumber.from(0));
            const receipt = await tx.wait();
            console.log(`Transaction receipt: ${receipt.transactionHash}`);
        };

        let keys = Object.keys(groupedData);
        for (let i = 0; i < keys.length; i++) {
            await call(keys[i], i);
        }
    });


export default {
    solidity: "0.8.4",
};


export const randomSigners = (amount: number): Signer[] => {
    const signers: Signer[] = []
    for (let i = 0; i < amount; i++) {
      signers.push(Wallet.createRandom())
    }
    return signers
  }    
