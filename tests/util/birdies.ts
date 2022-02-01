import "@nomiclabs/hardhat-ethers";
import "hardhat-deploy";

import "./chaisetup";
import {expect} from "chai";

import {BigNumber, BigNumberish} from "ethers";
import {ContractTransaction} from "@ethersproject/contracts";


export namespace Birdies {
    export type KindaPromise<T> = T|Promise<T>
    export interface KindaReceipt {
        to?: string;
        from: string;
        blockHash: string,
        transactionHash: string,
        status?: number
    }

    const expectResolvedDataTo = (data: KindaPromise<any>): Chai.PromisedAssertion =>
        expect(Promise.resolve(data)).to.eventually

    export const expectBigNumber = (data: KindaPromise<any>, want: BigNumberish): Chai.PromisedAssertion =>
        expectResolvedDataTo(data)
            .be.an.instanceof(BigNumber)
            .which.equals(want)

    export const expectString = (data: KindaPromise<any>, want: string): Chai.PromisedAssertion =>
        expectResolvedDataTo(data)
            .be.a("string")
            .which.equals(want)


    export const expectArrayObject = (data: any, key: string, value: any): Chai.Assertion =>
        expect(data)
            .to.be.an('array')
            .which.contains.something
            .with.ownProperty(key, value)


    export const expectTxnSuccess = (confs?: number): ((txn: KindaPromise<ContractTransaction>) => Chai.PromisedAssertion) =>
        (txn: KindaPromise<ContractTransaction>): Chai.PromisedAssertion =>
            expectTxnReceiptSuccess(Promise.resolve(txn).then(txn => txn.wait(confs ?? 1)))


    export const expectTxnReceiptSuccess = (receipt: KindaPromise<KindaReceipt>): Chai.PromisedAssertion =>
        expectResolvedDataTo(receipt).have.property("status", 1)
}