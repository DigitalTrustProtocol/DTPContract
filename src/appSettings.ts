import { BigNumber  } from 'ethers';
import { parseUnits } from 'ethers/lib/utils';
import _ from "lodash";  
//import { DTPContract__factory } from "../typechain";


export const eth1 = parseUnits("1.0", "ether");

const data: any = {
    generic: {
        baseCostFee: eth1, // The base cost of the first item

        //dtpContractABI: DTPContract__factory.abi,
        stableCoins: {
            dai: {
                decimals: 18,
                symbol: 'DAI',
                name: 'Dai Stablecoin',
                icon: 'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0x6B175474E89094C44Da98b954EedeAC495271d0F/logo.png',
                price: eth1,
            },
            usdc: {
                decimals: 6,
                symbol: 'USDC',
                name: 'USD Coin',
                icon: 'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48/logo.png',
                price: eth1,
            },
        }
    },
    1: { // Mainnet    
        dtpContract: "0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0",
        stableCoins: {
            dai: {
                address: '0x6B175474E89094C44Da98b954EedeAC495271d0F',
            },
            usdc: {
                address: '0xA0b86991'
            },
        }
    },
    1337: { // Localhost

        dtpContract: "0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0",
        stableCoins: {
            dai: {
                address: '0x6B175474E89094C44Da98b954EedeAC495271d0F',
            },
            usdc: {
                address: '0xA0b86991'
            },
        }
    },
    31337: { // Localhost

        dtpContract: "0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0",
        stableCoins: {
            dai: {
                address: '0x6B175474E89094C44Da98b954EedeAC495271d0F',
            },
            usdc: {
                address: '0xA0b86991'
            },
        }
    }
}

export function getAppSettings(chainId: number) : any {
    return _.merge({}, data.generic, data[chainId]);
}