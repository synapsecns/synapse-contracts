// Note: as per https://github.com/sc-forks/solidity-coverage/blob/3c0f3a5c7db26e82974873bbf61cf462072a7c6d/test/util/integration.js#L22
// this does not work as .solcover.ts
module.exports = {
    norpc: true,
    skipFiles: ["bridge /mocks/", "interfaces/", "MultisigWallet/", "auxiliary/", "testing/"],
    // see: https://github.com/sc-forks/solidity-coverage/blob/57319fae7e021cbe0f9a818100563f68b1fe6739/docs/faq.md
    configureYulOptimizer: true
}