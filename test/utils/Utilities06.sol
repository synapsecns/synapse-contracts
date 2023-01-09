// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "forge-std/Test.sol";

import {Swap} from "../../contracts/amm/Swap.sol";
import {SwapDeployer} from "../../contracts/amm/SwapDeployer.sol";
import {LPToken} from "../../contracts/amm/LPToken.sol";

import {SynapseBridge} from "../../contracts/bridge/SynapseBridge.sol";
import {SynapseERC20} from "../../contracts/bridge/SynapseERC20.sol";
import {ISwap} from "../../contracts/bridge/interfaces/ISwap.sol";
import {IWETH9} from "../../contracts/bridge/interfaces/IWETH9.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20, Ownable {
    constructor(string memory name_, uint8 decimals_) public ERC20(name_, name_) {
        _setupDecimals(decimals_);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function burnFrom(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}

contract Utilities06 is Test {
    address internal constant NODE = 0x230A1AC45690B9Ae1176389434610B9526d2f21b;

    LPToken private _lpToken;
    Swap private _swap;
    SwapDeployer private _deployer;

    // Bridge "OUT" Events. `IERC20` replaced with `address` to reduce amount of casts
    event TokenDeposit(address indexed to, uint256 chainId, address token, uint256 amount);
    event TokenRedeem(address indexed to, uint256 chainId, address token, uint256 amount);
    event TokenDepositAndSwap(
        address indexed to,
        uint256 chainId,
        address token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    );
    event TokenRedeemAndSwap(
        address indexed to,
        uint256 chainId,
        address token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    );
    event TokenRedeemAndRemove(
        address indexed to,
        uint256 chainId,
        address token,
        uint256 amount,
        uint8 swapTokenIndex,
        uint256 swapMinAmount,
        uint256 swapDeadline
    );

    function setUp() public virtual {
        _lpToken = new LPToken();
        _swap = new Swap();
        _deployer = new SwapDeployer();
        vm.label(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, "ETH");
    }

    /// @notice Shortcut for concatenation of two strings.
    function concat(string memory a, string memory b) public pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }

    /// @notice Shortcut for concatenation of three strings.
    function concat(
        string memory a,
        string memory b,
        string memory c
    ) public pure returns (string memory) {
        return string(abi.encodePacked(a, b, c));
    }

    function castToArray(IERC20 token0, IERC20 token1) public pure returns (IERC20[] memory tokens) {
        tokens = new IERC20[](2);
        tokens[0] = token0;
        tokens[1] = token1;
    }

    function castToArray(
        IERC20 token0,
        IERC20 token1,
        IERC20 token2
    ) public pure returns (IERC20[] memory tokens) {
        tokens = new IERC20[](3);
        tokens[0] = token0;
        tokens[1] = token1;
        tokens[2] = token2;
    }

    function castToArray(
        IERC20 token0,
        IERC20 token1,
        IERC20 token2,
        IERC20 token3
    ) public pure returns (IERC20[] memory tokens) {
        tokens = new IERC20[](4);
        tokens[0] = token0;
        tokens[1] = token1;
        tokens[2] = token2;
        tokens[3] = token3;
    }

    /// @notice Shortcut for string comparison.
    function equals(string memory a, string memory b) public pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    /**
     * @notice Deploys and labels an ERC20 mock.
     */
    function deployERC20(string memory name, uint8 decimals) public returns (ERC20 token) {
        token = new ERC20Mock(name, decimals);
        vm.label(address(token), name);
    }

    /**
     * @notice Deploys and labels a SynapseERC20 token.
     */
    function deploySynapseERC20(string memory name) public returns (SynapseERC20 token) {
        token = new SynapseERC20();
        token.initialize(name, name, 18, address(this));
        vm.label(address(token), name);
    }

    function deployWETH() public returns (IWETH9 token) {
        token = deployWETH("WETH");
    }

    function deployWETH(string memory name) public returns (IWETH9 token) {
        address weth = deployCode("WETH9.sol");
        vm.label(weth, name);
        token = IWETH9(payable(weth));
    }

    /**
     * @notice Deploys a test pool given the pool tokens.
     */
    function deployPool(IERC20[] memory tokens) public returns (address pool) {
        uint8[] memory decimals = new uint8[](tokens.length);
        for (uint256 i = 0; i < tokens.length; ++i) {
            decimals[i] = ERC20(address(tokens[i])).decimals();
        }
        pool = _deployer.deploy(address(_swap), tokens, decimals, "LP", "LP", 100, 1e6, 0, address(_lpToken));
    }

    /**
     * @notice Deploys a test pool given the pool tokens, and provides initial liquidity.
     * @dev For better readability, `amounts` are provided without decimals.
     */
    function deployPoolWithLiquidity(IERC20[] memory tokens, uint256[] memory amounts) public returns (address pool) {
        pool = deployPool(tokens);
        uint256[] memory amountsWithDecimals = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; ++i) {
            uint256 decimals = ERC20(address(tokens[i])).decimals();
            amountsWithDecimals[i] = amounts[i] * 10**decimals;
            deal(address(tokens[i]), address(this), amountsWithDecimals[i]);
            tokens[i].approve(pool, type(uint256).max);
        }
        ISwap(pool).addLiquidity(amountsWithDecimals, 0, type(uint256).max);
    }

    function deployBridge() public returns (SynapseBridge bridge) {
        bridge = new SynapseBridge();
        setupBridge(bridge);
    }

    function deployBridge(address where) public returns (SynapseBridge bridge) {
        // Deploy code at requested address
        address _bridge = address(new SynapseBridge());
        bytes memory code = codeAt(_bridge);
        vm.etch(where, code);
        bridge = SynapseBridge(payable(where));
        setupBridge(bridge);
    }

    function setupBridge(SynapseBridge bridge) public {
        bridge.initialize();
        bridge.grantRole(bridge.NODEGROUP_ROLE(), NODE);
        vm.label(address(bridge), "BRIDGE");
    }

    function expectOnlyOwnerRevert() public {
        vm.expectRevert("Ownable: caller is not the owner");
    }

    function calculateAddLiquidity(
        ISwap pool,
        uint8 indexFrom,
        uint256 amount,
        uint256 tokens
    ) public returns (uint256 amountOut) {
        try this.addLiquidityAndRevert(pool, indexFrom, amount, tokens) {
            revert("This should've reverted");
        } catch (bytes memory reason) {
            bytes memory s = bytes(getRevertMsg(reason));
            require(s.length == 32, "More than one word returned");
            amountOut = abi.decode(s, (uint256));
        }
    }

    function addLiquidityAndRevert(
        ISwap pool,
        uint8 indexFrom,
        uint256 amount,
        uint256 tokens
    ) external {
        uint256[] memory amounts = new uint256[](tokens);
        amounts[indexFrom] = amount;
        uint256 amountOut = pool.addLiquidity(amounts, 0, type(uint256).max);
        revert(string(abi.encode(amountOut)));
    }

    function getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Transaction reverted silently";

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }

    // https://docs.soliditylang.org/en/v0.6.12/assembly.html#example
    function codeAt(address _addr) public view returns (bytes memory o_code) {
        assembly {
            // retrieve the size of the code, this needs assembly
            let size := extcodesize(_addr)
            // allocate output byte array - this could also be done without assembly
            // by using o_code = new bytes(size)
            o_code := mload(0x40)
            // new "memory end" including padding
            mstore(0x40, add(o_code, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            // store length in memory
            mstore(o_code, size)
            // actually retrieve the code, this needs assembly
            extcodecopy(_addr, add(o_code, 0x20), 0, size)
        }
    }
}
