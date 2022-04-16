pragma solidity 0.8.13;

import "ds-test/test.sol";
import "../../contracts/messaging/GasFeePricing.sol";

interface CheatCodes {
    function prank(address) external;
}

contract GasFeePricingTest is DSTest {
    CheatCodes public cheats = CheatCodes(HEVM_ADDRESS);
    GasFeePricing gasFeePricing;
    uint256 expectedDstChainId = 43114;
    uint256 expectedDstGasPrice = 30000000000;
    uint256 expectedGasTokenPriceRatio = 25180000000000000;

    function setUp() public {
        gasFeePricing = new GasFeePricing();
    }

    function testFailSetCostAsNotOwner() public {
        cheats.prank(address(0));
        gasFeePricing.setCostPerChain(expectedDstChainId, expectedDstGasPrice, expectedGasTokenPriceRatio);
    }

    function testSetCostAsOwner() public {
        gasFeePricing.setCostPerChain(expectedDstChainId, expectedDstGasPrice, expectedGasTokenPriceRatio);
        assertEq(gasFeePricing.dstGasPriceInWei(expectedDstChainId), expectedDstGasPrice);
        assertEq(gasFeePricing.dstGasTokenRatio(expectedDstChainId), expectedGasTokenPriceRatio);
    }

    function testNotSetData() public {
        // set data
        testSetCostAsOwner();

        uint256 fee = gasFeePricing.estimateGasFee(1, bytes("0"));
        assertEq(fee, 0);
    }

    function testSetData() public {
        // set data
        testSetCostAsOwner();
        uint256 currentGasLimit = 200000;
        uint256 fee = gasFeePricing.estimateGasFee(43114, bytes("0"));
        uint256 expectedFee = (expectedDstGasPrice*expectedGasTokenPriceRatio*currentGasLimit / 10**18);
        assertEq(fee, expectedFee);
    }
}

