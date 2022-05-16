pragma solidity 0.8.13;

import "forge-std/Test.sol";

import "../../contracts/messaging/GasFeePricing.sol";

contract GasFeePricingTest is Test {
    GasFeePricing public gasFeePricing;
    uint256 public expectedDstChainId = 43114;
    uint256 public expectedDstGasPrice = 30000000000;
    uint256 public expectedGasTokenPriceRatio = 25180000000000000;
    uint256 public currentGasLimit = 200000;
    uint256 public expectedFeeDst43114 = ((expectedDstGasPrice *
        expectedGasTokenPriceRatio *
        currentGasLimit) / 10**18);

    function addressToBytes32(address _addr) public pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function bytes32ToAddress(bytes32 bys) public pure returns (address) {
        return address(uint160(uint256(bys)));
    }

    function setUp() public {
        gasFeePricing = new GasFeePricing();
    }

    function testFailSetCostAsNotOwner() public {
        vm.prank(address(0));
        gasFeePricing.setCostPerChain(
            expectedDstChainId,
            expectedDstGasPrice,
            expectedGasTokenPriceRatio
        );
    }

    function testSetCostAsOwner() public {
        gasFeePricing.setCostPerChain(
            expectedDstChainId,
            expectedDstGasPrice,
            expectedGasTokenPriceRatio
        );
        assertEq(
            gasFeePricing.dstGasPriceInSrcAttoWei(expectedDstChainId),
            expectedDstGasPrice * expectedGasTokenPriceRatio
        );
    }

    function testNotSetData() public {
        // set data
        testSetCostAsOwner();

        uint256 fee = gasFeePricing.estimateGasFee(1, bytes(""));
        assertEq(fee, 0);
    }

    function testSetData() public {
        // set data
        testSetCostAsOwner();
        uint256 fee = gasFeePricing.estimateGasFee(43114, bytes(""));
        uint256 expectedFee = ((expectedDstGasPrice *
            expectedGasTokenPriceRatio *
            currentGasLimit) / 10**18);
        assertEq(fee, expectedFee);
    }

    function testTypeOneEncodeAndDecodeOptions() public {
        // test type 1
        bytes memory options = gasFeePricing.encodeOptions(1, 300000);

        (
            uint16 txType,
            uint256 gasLimit,
            uint256 dstAirdrop,
            bytes32 dstAddress
        ) = gasFeePricing.decodeOptions(options);
        assertEq(txType, 1);
        assertEq(gasLimit, 300000);
        assertEq(dstAirdrop, 0);
        assertEq(dstAddress, 0);
    }

    function testTypeTwoEncodeAndDecodeOptions(
        uint256 _gasLimit,
        uint256 _dstNativeAmt,
        bytes32 _address
    ) public {
        // test type 2
        vm.assume(_dstNativeAmt != 0);
        vm.assume(_address != bytes32(0));

        bytes memory options = gasFeePricing.encodeOptions(
            2,
            _gasLimit,
            _dstNativeAmt,
            _address
        );

        (
            uint16 txType,
            uint256 gasLimit,
            uint256 dstAirdrop,
            bytes32 dstAddress
        ) = gasFeePricing.decodeOptions(options);
        assertEq(txType, 2);
        assertEq(gasLimit, _gasLimit);
        assertEq(dstAirdrop, _dstNativeAmt);
        assertEq(dstAddress, _address);
    }

    function testFailRevertNoDstNativeAddress() public {
        bytes memory options = gasFeePricing.encodeOptions(
            2,
            300000,
            100000000000000000,
            bytes32(0)
        );

        (
            uint16 txType,
            uint256 gasLimit,
            uint256 dstAirdrop,
            bytes32 dstAddress
        ) = gasFeePricing.decodeOptions(options);
        assertEq(txType, 2);
        assertEq(gasLimit, 300000);
        assertEq(dstAirdrop, 100000000000000000);
    }

    function testEstimateFeeWithOptionsTypeOne(uint64 _gasLimit) public {
        vm.assume(_gasLimit != 0);
        testSetCostAsOwner();
        bytes memory options = gasFeePricing.encodeOptions(
            1,
            uint256(_gasLimit)
        );
        uint256 fee = gasFeePricing.estimateGasFee(43114, options);
        uint256 expectedFee = ((expectedDstGasPrice *
            expectedGasTokenPriceRatio *
            _gasLimit) / 10**18);
        assertEq(fee, expectedFee);
    }
}
