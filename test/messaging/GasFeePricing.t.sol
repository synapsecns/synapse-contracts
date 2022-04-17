pragma solidity 0.8.13;

import "forge-std/Test.sol";

import "../../contracts/messaging/GasFeePricing.sol";

contract GasFeePricingTest is Test {
    GasFeePricing public gasFeePricing;
    uint256 public expectedDstChainId = 43114;
    uint256 public expectedDstGasPrice = 30000000000;
    uint256 public expectedGasTokenPriceRatio = 25180000000000000;
    uint256 public currentGasLimit = 200000;
    uint256 public expectedFeeDst43114 = (expectedDstGasPrice*expectedGasTokenPriceRatio*currentGasLimit / 10**18);

    function setUp() public {
        gasFeePricing = new GasFeePricing();
    }

    function testFailSetCostAsNotOwner() public {
        vm.prank(address(0));
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
        uint256 fee = gasFeePricing.estimateGasFee(43114, bytes("0"));
        uint256 expectedFee = (expectedDstGasPrice*expectedGasTokenPriceRatio*currentGasLimit / 10**18);
        assertEq(fee, expectedFee);
    }
}

