pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../contracts/messaging/AuthVerifier.sol";
import "./ChainConfig.sol";

contract SetAuthVerifier is Test {
    ChainConfig public chainConfig;
    AuthVerifier public authVerifier;
    function setUp() public {
        chainConfig = new ChainConfig();
    }
    function deploy() public {
        vm.broadcast(address(0x0AF91FA049A7e1894F480bFE5bBa20142C6c29a9));
        AuthVerifier(0xA67b7147DcE20D6F25Fd9ABfBCB1c3cA74E11f0B).setNodeGroup(address(0xE1DD28e1CB0D473Fd819449bf3aBfC3152582A66));
        // if (block.chainid == chainConfig.FUJI()) {
        //     address FUJI_AUTHVERIFIER = chainConfig.FUJI_AUTHVERIFIER();
        //     vm.broadcast(address(0x0AF91FA049A7e1894F480bFE5bBa20142C6c29a9));
        //     AuthVerifier(FUJI_AUTHVERIFIER).setNodeGroup(address(0xE1DD28e1CB0D473Fd819449bf3aBfC3152582A66));
        // }

        // if (block.chainid == chainConfig.GOERLI()) {
        //     address GOERLI_AUTHVERIFIER = chainConfig.GOERLI_AUTHVERIFIER();
        //     vm.broadcast(address(0x0AF91FA049A7e1894F480bFE5bBa20142C6c29a9));
        //     AuthVerifier(GOERLI_AUTHVERIFIER).setNodeGroup(address(0xE1DD28e1CB0D473Fd819449bf3aBfC3152582A66));
        // }
    }
}