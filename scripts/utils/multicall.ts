
import { Interface } from '@ethersproject/abi'
import { Contract } from '@ethersproject/contracts'

export function chunkArray(arr: any[], len: number): any[][] {
    let chunks = [];
    let i = 0;
    let n = arr.length;

    while (i < n) {
        chunks.push(arr.slice(i, i += len));
    }

    return chunks;
}

export interface Call {
    address: string // Address of the contract
    functionName: string // Function name on the contract (exemple: balanceOf)
    params?: any[] // Function params
}

export async function multicall(multi: Contract, abi: any[], calls: Call[], maxCallsPerTx = 1000): Promise<any[]> {
    const itf = new Interface(abi)

    const chunkedCalls = chunkArray(calls, maxCallsPerTx);

    let finalData: any[] = []
    for (const currentCalls of chunkedCalls) {
        const calldata = currentCalls.map((call) => [call.address.toLowerCase(), itf.encodeFunctionData(call.functionName, call.params)])
        const { returnData } = await multi.callStatic.aggregate(calldata);
        const res = returnData.map((call: any, i: number) => itf.decodeFunctionResult(currentCalls[i].functionName, call))
        finalData = [...finalData, ...res];
    }

    return finalData
}

