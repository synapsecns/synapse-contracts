// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;


import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

interface IERC20Mintable {
    function mint(address to, uint256 amount) external;

    function mintMultiple(address to, uint256 amount, address feeAddress, uint256 feeAmount) external;
}

contract BridgeDeposit is Initializable, AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    bytes32 public constant NODEGROUP_ROLE = keccak256("NODEGROUP_ROLE");

    mapping(address => uint256) private fees;
    uint256 private ethFees;

    function initialize() public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        __AccessControl_init();
    }
    
    event TokenDeposit(address from, address to, uint256 chainId, IERC20 token, uint256 amount);
    event TokenRedeem(address to, uint256 chainId, IERC20 token, uint256 amount);
    event TokenWithdraw(address to, IERC20 token, uint256 amount, uint256 fee);
    event TokenMint(address to, IERC20Mintable token, uint256 amount, uint256 fee);


    // VIEW FUNCTIONS ***/
    function getFeeBalance(address tokenAddress) external view returns (uint256) {
        return fees[tokenAddress];
    }

    function getETHFeeBalance() external view returns (uint256) {
        return ethFees;
    }

    // FEE FUNCTIONS ***/
    /**
     * @notice withdraw specified ERC20 token fees to a given address
     * @param token ERC20 token in which fees acccumulated to transfer
     * @param to Address to send the fees to
     */
    function withdrawFees(IERC20 token, address to) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        if (fees[address(token)] != 0) {
            token.safeTransfer(to, fees[address(token)]);
        }
    }

    /**
     * @notice withdraw gas token fees to a given address
     * @param to Address to send the gas fees to
     */
    function withdrawETHAdminFees(address payable to) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        if (ethFees != 0) {
            to.transfer(ethFees);
        }
    }


    /**
    @notice Relays to nodes to transfers the underlying chain gas token cross-chain
    @param to address on other chain to bridge assets to
    @param chainId which chain to bridge assets onto
    @param amount Amount in native token decimals to transfer cross-chain pre-fees
    **/
    function depositETH(address to, uint256 chainId, uint256 amount) public payable {
        require(msg.value == amount);
        emit TokenDeposit(msg.sender, to, chainId, IERC20(address(0)), amount);
    }

    /**
    @notice Relays to nodes to transfers an ERC20 token cross-chain
    @param to address on other chain to bridge assets to
    @param chainId which chain to bridge assets onto
    @param token ERC20 compatible token to deposit into the bridge
    @param amount Amount in native token decimals to transfer cross-chain pre-fees
    **/
    function deposit(address to, uint256 chainId, IERC20 token, uint256 amount) public {
        token.safeTransferFrom(msg.sender, address(this), amount);
        emit TokenDeposit(msg.sender, to, chainId, token, amount);
    }
    
    /**
    @notice Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain
    @param to address on other chain to redeem underlying assets to
    @param chainId which underlying chain to bridge assets onto
    @param token ERC20 compatible token to deposit into the bridge
    @param amount Amount in native token decimals to transfer cross-chain pre-fees
    **/
    function redeem(address to, uint256 chainId, ERC20Burnable token, uint256 amount) public {
        token.burnFrom(msg.sender, amount);
        emit TokenRedeem(to, chainId, token, amount);
    }
    
    /**
    @notice Function to be called by the node group to withdraw the underlying assets from the contract
    @param to address on chain to send underlying assets to
    @param token ERC20 compatible token to withdraw from the bridge
    @param amount Amount in native token decimals to withdraw
    @param fee Amount in native token decimals to save to the contract as fees
    **/
    function withdraw(address to, IERC20 token, uint256 amount, uint256 fee) public {
        require(hasRole(NODEGROUP_ROLE, msg.sender), "Caller is not a node group");
        fees[address(token)].add(fee);
        token.safeTransferFrom(address(this), to, amount);
        emit TokenWithdraw(to, token, amount, fee);
    }

    /**
    @notice Function to be called by the node group to withdraw the underlying gas asset from the contract
    @param to address on chain to send gas asset to
    @param amount Amount in gas token decimals to withdraw (after subtracting fee already)
    @param fee Amount in gas token decimals to save to the contract as fees
    **/
    function withdrawETH(address payable to, uint256 amount, uint256 fee) public {
        require(hasRole(NODEGROUP_ROLE, msg.sender), "Caller is not a node group");
        ethFees.add(fee);
        to.transfer(amount);
        emit TokenWithdraw(to, IERC20(address(0)), amount, fee);
    }

    /**
    @notice Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain
    @dev This means the BridgeDeposit.sol contract must have minter access to the token attempting to be minted
    @param to address on other chain to redeem underlying assets to
    @param token ERC20 compatible token to deposit into the bridge
    @param amount Amount in native token decimals to transfer cross-chain post-fees
    @param fee Amount in native token decimals to save to the contract as fees
    **/
    function mint(address to, IERC20Mintable token, uint256 amount, uint256 fee) public {
        require(hasRole(NODEGROUP_ROLE, msg.sender), "Caller is not a node group");
        fees[address(token)].add(fee);
        token.mintMultiple(to, amount, address(this), fee);
        emit TokenMint(to, token, amount, fee);
    }
}
