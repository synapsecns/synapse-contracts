import {web3} from "hardhat";

import configure from "@openzeppelin/test-helpers/configure";
// enable the open zeppelin test helpers
// require('@openzeppelin/test-helpers/configure')({ provider: web3.currentProvider, environment: 'truffle' });

configure({provider: web3.currentProvider, enviornment: "web3"})
