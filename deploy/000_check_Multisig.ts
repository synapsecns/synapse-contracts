import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { CHAIN_ID } from "../utils/network"
import {includes} from "lodash";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, execute, save, getOrNull } = deployments
  const { deployer } = await getNamedAccounts()

  // If it's on hardhat, mint test tokens
  if ((await getChainId()) == CHAIN_ID.HARDHAT) {
    await save("DevMultisig", {
      abi: [
        {
          type: "function",
          stateMutability: "view",
          payable: false,
          outputs: [{ type: "address", name: "" }],
          name: "owners",
          inputs: [{ type: "uint256", name: "" }],
          constant: true,
        },
        {
          type: "function",
          stateMutability: "nonpayable",
          payable: false,
          outputs: [],
          name: "removeOwner",
          inputs: [{ type: "address", name: "owner" }],
          constant: false,
        },
        {
          type: "function",
          stateMutability: "nonpayable",
          payable: false,
          outputs: [],
          name: "revokeConfirmation",
          inputs: [{ type: "uint256", name: "transactionId" }],
          constant: false,
        },
        {
          type: "function",
          stateMutability: "view",
          payable: false,
          outputs: [{ type: "bool", name: "" }],
          name: "isOwner",
          inputs: [{ type: "address", name: "" }],
          constant: true,
        },
        {
          type: "function",
          stateMutability: "view",
          payable: false,
          outputs: [{ type: "bool", name: "" }],
          name: "confirmations",
          inputs: [
            { type: "uint256", name: "" },
            { type: "address", name: "" },
          ],
          constant: true,
        },
        {
          type: "function",
          stateMutability: "view",
          payable: false,
          outputs: [{ type: "uint256", name: "" }],
          name: "calcMaxWithdraw",
          inputs: [],
          constant: true,
        },
        {
          type: "function",
          stateMutability: "view",
          payable: false,
          outputs: [{ type: "uint256", name: "count" }],
          name: "getTransactionCount",
          inputs: [
            { type: "bool", name: "pending" },
            { type: "bool", name: "executed" },
          ],
          constant: true,
        },
        {
          type: "function",
          stateMutability: "view",
          payable: false,
          outputs: [{ type: "uint256", name: "" }],
          name: "dailyLimit",
          inputs: [],
          constant: true,
        },
        {
          type: "function",
          stateMutability: "view",
          payable: false,
          outputs: [{ type: "uint256", name: "" }],
          name: "lastDay",
          inputs: [],
          constant: true,
        },
        {
          type: "function",
          stateMutability: "nonpayable",
          payable: false,
          outputs: [],
          name: "addOwner",
          inputs: [{ type: "address", name: "owner" }],
          constant: false,
        },
        {
          type: "function",
          stateMutability: "view",
          payable: false,
          outputs: [{ type: "bool", name: "" }],
          name: "isConfirmed",
          inputs: [{ type: "uint256", name: "transactionId" }],
          constant: true,
        },
        {
          type: "function",
          stateMutability: "view",
          payable: false,
          outputs: [{ type: "uint256", name: "count" }],
          name: "getConfirmationCount",
          inputs: [{ type: "uint256", name: "transactionId" }],
          constant: true,
        },
        {
          type: "function",
          stateMutability: "view",
          payable: false,
          outputs: [
            { type: "address", name: "destination" },
            { type: "uint256", name: "value" },
            { type: "bytes", name: "data" },
            { type: "bool", name: "executed" },
          ],
          name: "transactions",
          inputs: [{ type: "uint256", name: "" }],
          constant: true,
        },
        {
          type: "function",
          stateMutability: "view",
          payable: false,
          outputs: [{ type: "address[]", name: "" }],
          name: "getOwners",
          inputs: [],
          constant: true,
        },
        {
          type: "function",
          stateMutability: "view",
          payable: false,
          outputs: [{ type: "uint256[]", name: "_transactionIds" }],
          name: "getTransactionIds",
          inputs: [
            { type: "uint256", name: "from" },
            { type: "uint256", name: "to" },
            { type: "bool", name: "pending" },
            { type: "bool", name: "executed" },
          ],
          constant: true,
        },
        {
          type: "function",
          stateMutability: "view",
          payable: false,
          outputs: [{ type: "address[]", name: "_confirmations" }],
          name: "getConfirmations",
          inputs: [{ type: "uint256", name: "transactionId" }],
          constant: true,
        },
        {
          type: "function",
          stateMutability: "view",
          payable: false,
          outputs: [{ type: "uint256", name: "" }],
          name: "transactionCount",
          inputs: [],
          constant: true,
        },
        {
          type: "function",
          stateMutability: "nonpayable",
          payable: false,
          outputs: [],
          name: "changeRequirement",
          inputs: [{ type: "uint256", name: "_required" }],
          constant: false,
        },
        {
          type: "function",
          stateMutability: "nonpayable",
          payable: false,
          outputs: [],
          name: "confirmTransaction",
          inputs: [{ type: "uint256", name: "transactionId" }],
          constant: false,
        },
        {
          type: "function",
          stateMutability: "nonpayable",
          payable: false,
          outputs: [{ type: "uint256", name: "transactionId" }],
          name: "submitTransaction",
          inputs: [
            { type: "address", name: "destination" },
            { type: "uint256", name: "value" },
            { type: "bytes", name: "data" },
          ],
          constant: false,
        },
        {
          type: "function",
          stateMutability: "nonpayable",
          payable: false,
          outputs: [],
          name: "changeDailyLimit",
          inputs: [{ type: "uint256", name: "_dailyLimit" }],
          constant: false,
        },
        {
          type: "function",
          stateMutability: "view",
          payable: false,
          outputs: [{ type: "uint256", name: "" }],
          name: "MAX_OWNER_COUNT",
          inputs: [],
          constant: true,
        },
        {
          type: "function",
          stateMutability: "view",
          payable: false,
          outputs: [{ type: "uint256", name: "" }],
          name: "required",
          inputs: [],
          constant: true,
        },
        {
          type: "function",
          stateMutability: "nonpayable",
          payable: false,
          outputs: [],
          name: "replaceOwner",
          inputs: [
            { type: "address", name: "owner" },
            { type: "address", name: "newOwner" },
          ],
          constant: false,
        },
        {
          type: "function",
          stateMutability: "nonpayable",
          payable: false,
          outputs: [],
          name: "executeTransaction",
          inputs: [{ type: "uint256", name: "transactionId" }],
          constant: false,
        },
        {
          type: "function",
          stateMutability: "view",
          payable: false,
          outputs: [{ type: "uint256", name: "" }],
          name: "spentToday",
          inputs: [],
          constant: true,
        },
        {
          type: "constructor",
          stateMutability: "nonpayable",
          payable: false,
          inputs: [
            { type: "address[]", name: "_owners" },
            { type: "uint256", name: "_required" },
            { type: "uint256", name: "_dailyLimit" },
          ],
        },
        { type: "fallback", stateMutability: "payable", payable: true },
        {
          type: "event",
          name: "DailyLimitChange",
          inputs: [{ type: "uint256", name: "dailyLimit", indexed: false }],
          anonymous: false,
        },
        {
          type: "event",
          name: "Confirmation",
          inputs: [
            { type: "address", name: "sender", indexed: true },
            { type: "uint256", name: "transactionId", indexed: true },
          ],
          anonymous: false,
        },
        {
          type: "event",
          name: "Revocation",
          inputs: [
            { type: "address", name: "sender", indexed: true },
            { type: "uint256", name: "transactionId", indexed: true },
          ],
          anonymous: false,
        },
        {
          type: "event",
          name: "Submission",
          inputs: [{ type: "uint256", name: "transactionId", indexed: true }],
          anonymous: false,
        },
        {
          type: "event",
          name: "Execution",
          inputs: [{ type: "uint256", name: "transactionId", indexed: true }],
          anonymous: false,
        },
        {
          type: "event",
          name: "ExecutionFailure",
          inputs: [{ type: "uint256", name: "transactionId", indexed: true }],
          anonymous: false,
        },
        {
          type: "event",
          name: "Deposit",
          inputs: [
            { type: "address", name: "sender", indexed: true },
            { type: "uint256", name: "value", indexed: false },
          ],
          anonymous: false,
        },
        {
          type: "event",
          name: "OwnerAddition",
          inputs: [{ type: "address", name: "owner", indexed: true }],
          anonymous: false,
        },
        {
          type: "event",
          name: "OwnerRemoval",
          inputs: [{ type: "address", name: "owner", indexed: true }],
          anonymous: false,
        },
        {
          type: "event",
          name: "RequirementChange",
          inputs: [{ type: "uint256", name: "required", indexed: false }],
          anonymous: false,
        },
      ],
      address: deployer,
    })
  }

  if ((includes([CHAIN_ID.MOONBEAM, CHAIN_ID.CRONOS, CHAIN_ID.METIS, CHAIN_ID.DFK], await getChainId()))) {
    await deploy("MultiSigWalletFactory", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
    })

    if ((await getOrNull("DevMultisig")) == null) {
      await execute(
        "MultiSigWalletFactory",
        { from: deployer, log: true },
        "create",
        [deployer],
        1,
      )
    }
  }
}

export default func
func.tags = ["DevMultisig"]
