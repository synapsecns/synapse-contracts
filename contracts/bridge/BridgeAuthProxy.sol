// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/Initializable.sol';
import {AccessControlUpgradeable} from '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import {ReentrancyGuardUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import {PausableUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol';

import {SafeMath} from '@openzeppelin/contracts/math/SafeMath.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC20Mintable} from "./interfaces/IERC20Mintable.sol";

import {ERC20Burnable} from '@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol';

import {IMetaSwapDeposit} from './interfaces/IMetaSwapDeposit.sol';
import {ISwap} from './interfaces/ISwap.sol';
import {IWETH9} from './interfaces/IWETH9.sol';
import {ISynapseBridge} from './interfaces/ISynapseBridge.sol';

import {Signatures} from './utils/Signatures.sol';

contract BridgeAuthProxy is Initializable, AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Mintable;
    using SafeMath for uint256;

    ISynapseBridge public BRIDGE;

    bytes32 public constant GOVERNANCE_ROLE = keccak256('GOVERNANCE_ROLE');

    // here we define the event types that prefix the arguments in each
    // hashing operation. These prevent signatures with the same arguments
    // from being used cross event
    /// @dev if these are modified, they should be updated in contracts/bridgeauth/bridgeauth_test.go
    uint constant public WITHDRAW_EVENT_TYPE = 5;
    uint constant public MINT_EVENT_TYPE = 6;
    uint constant public MINT_AND_SWAP_TYPE = 7;
    uint constant public WITHDRAW_AND_REMOVE_TYPE = 8;

    // schnorr_pubkey contains the public key schnorr signatures are verified against.
    uint256 public signingPubKeyX;
    uint8 public pubKeyYParity;

    function initialize()
        external
        initializer
    {
        // initialize initializes the auth proxy
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        __AccessControl_init();
    }

    modifier isGovernance() {
        require(
            hasRole(GOVERNANCE_ROLE, msg.sender),
            "msg.sender not governance"
        );

        _;
    }

    function setBridgeAddress(address payable _bridgeAddress)
        external
        isGovernance
    {
        BRIDGE = ISynapseBridge(_bridgeAddress);
    }

    // TODO: this needs to be callable by a schnorr sig function
    function setSchnorrPubKey(
        uint256 _signingPubKeyX,
        uint8 _pubKeyYParity
    )
        external
        isGovernance
    {
        require(
            _signingPubKeyX < Signatures.HALF_Q,
            "Public-key x >= HALF_Q"
        );

        require(_signingPubKeyX > 0);

        signingPubKeyX =  _signingPubKeyX;
        pubKeyYParity = _pubKeyYParity;
    }

    /**
     * @notice verifySignature returns true if passed a valid Schnorr signature.
     *
     * @dev See https://en.wikipedia.org/wiki/Schnorr_signature for reference.
     *
     * @dev In what follows, let d be your secret key, PK be your public key,
     *      PKx be the x ordinate of your public key, and PKyp be the parity bit for
     *      the y ordinate (i.e., 0 if PKy is even, 1 if odd.)
     * @dev TO CREATE A VALID SIGNATURE FOR THIS METHOD:
     *     First PKx must be less than HALF_Q. Then follow these instructions (see evm/test/schnorr_test.js, for an example of carrying them out):
     *
     *     1. Hash the target message to a uint256, called _msgHash here, using keccak256
     *     2. Pick k uniformly and cryptographically securely randomly from
     *         {0,...,Q-1}. It is critical that k remains confidential, as your
     *         private key can be reconstructed from k and the signature.
     *     3. Compute k*g in the secp256k1 group, where g is the group
     *         generator. (This is the same as computing the public key from the
     *         secret key k. But it's OK if k*g's x ordinate is greater than
     *         HALF_Q.)
     *     4. Compute the ethereum address for k*g. This is the lower 160 bits
     *         of the keccak hash of the concatenated affine coordinates of k*g,
     *         as 32-byte big-endians. (For instance, you could pass k to
     *         ethereumjs-utils's privateToAddress to compute this, though that
     *         should be strictly a development convenience, not for handling
     *         live secrets, unless you've locked your javascript environment
     *         down very carefully.) Call this address
     *         nonceTimesGeneratorAddress.
     *     5. Compute e=uint256(keccak256(PKx as a 32-byte big-endian
     *                                 ‖ PKyp as a single byte
     *                                 ‖ _msgHash
     *                                 ‖ nonceTimesGeneratorAddress))
     *         This value e is called "msgChallenge" in verifySignature's source
     *         code below. Here "‖" means concatenation of the listed byte
     *         arrays.
     *     6. Let x be your secret key. Compute s = (k - d * e) % Q. Add Q to
     *         it, if it's negative. This is your _signature. (d is your secret
     *         key.)
     *
     * @dev TO VERIFY A SIGNATURE
     *     Given a signature (s, e) of _msgHash, constructed as above, compute
     *     S=e*PK+s*generator in the secp256k1 group law, and then the ethereum
     *     address of S, as described in step 4. Call that
     *     _nonceTimesGeneratorAddress. Then call the verifySignature method as:
     *         verifySignature(PKx, PKyp, s, _msgHash, _nonceTimesGeneratorAddress)
     *
     * @dev This signing scheme deviates slightly from the classical Schnorr
     *      signature, in that the address of k*g is used in place of k*g itself,
     *      both when calculating e and when verifying sum S as described in the
     *      verification paragraph above. This reduces the difficulty of
     *      brute-forcing a signature by trying random secp256k1 points in place of
     *      k*g in the signature verification process from 256 bits to 160 bits.
     *      However, the difficulty of cracking the public key using "baby-step,
     *      giant-step" is only 128 bits, so this weakening constitutes no compromise
     *      in the security of the signatures or the key.
     *
     * @dev The constraint signingPubKeyX < HALF_Q comes from Eq. (281), p. 24
     *      of Yellow Paper version 78d7b9a. ecrecover only accepts "s" inputs less
     *      than HALF_Q, to protect against a signature- malleability vulnerability in
     *      ECDSA. Schnorr does not have this vulnerability, but we must account for
     *      ecrecover's defense anyway. And since we are abusing ecrecover by putting
     *      signingPubKeyX in ecrecover's "s" argument the constraint applies to
     *      signingPubKeyX, even though it represents a value in the base field, and
     *      has no natural relationship to the order of the curve's cyclic group.
     *
     * @param _signingPubKeyX is the x ordinate of the public key. This must be less than HALF_Q.
     * @param _pubKeyYParity is 0 if the y ordinate of the public key is even, 1 if it's odd.
     * @param signature is the actual signature, described as s in the above instructions.
     * @param msgHash is a 256-bit hash of the message being signed.
     * @param nonceTimesGeneratorAddress is the ethereum address of k*g in the above instructions
     *
     * @return True if passed a valid signature, false otherwise.
    */
    function verifySignature(
        uint256 _signingPubKeyX,
        uint8 _pubKeyYParity,
        uint256 signature,
        uint256 msgHash,
        address nonceTimesGeneratorAddress
    )
        public
        pure
        returns (bool)
    {
        return Signatures.verifySignature(
            _signingPubKeyX,
            _pubKeyYParity,
            signature,
            msgHash,
            nonceTimesGeneratorAddress
        );
    }

    function verifySignature(
        uint256 signature,
        uint256 msgHash,
        address nonceTimesGeneratorAddress
    )
        internal
        view
        returns (bool)
    {
        return verifySignature(
            signingPubKeyX,
            pubKeyYParity,
            signature,
            msgHash,
            nonceTimesGeneratorAddress
        );
    }

    /**
     * @notice Function to be called by the node group to withdraw the underlying assets from the contract
     * @param to address on chain to send underlying assets to
     * @param token ERC20 compatible token to withdraw from the bridge
     * @param amount Amount in native token decimals to withdraw
     * @param fee Amount in native token decimals to save to the contract as fees
     * @param kappa kappa
     */
    function withdraw(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa,
        uint256 signature,
        address commitmentAddress
    ) external  {
        uint256 hash = uint256(keccak256(
            abi.encode(
                WITHDRAW_EVENT_TYPE,
                to,
                token,
                amount,
                fee,
                kappa
            )
        ));

        require(verifySignature(signature, hash, commitmentAddress));

        BRIDGE.withdraw(to, token, amount, fee, kappa);
    }

    /**
     * @notice Nodes call this function to mint a SynERC20 (or any asset that the bridge is given minter access to). This is called by the nodes after a TokenDeposit event is emitted.
     * @dev This means the SynapseBridge.sol contract must have minter access to the token attempting to be minted
     * @param to address on other chain to redeem underlying assets to
     * @param token ERC20 compatible token to deposit into the bridge
     * @param amount Amount in native token decimals to transfer cross-chain post-fees
     * @param fee Amount in native token decimals to save to the contract as fees
     * @param kappa kappa
     */
    function mint(
        address payable to,
        IERC20Mintable token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa,
        uint256 signature,
        address commitmentAddress
    ) external  {
        // TODO: https://ethereum.stackexchange.com/questions/56749/retrieve-chain-id-of-the-executing-chain-from-a-solidity-contract
        // each of these need to add a chainid() for replay protection.
        uint256 hash = uint256(keccak256(
            abi.encode(
                MINT_EVENT_TYPE,
                to,
                token,
                amount,
                fee,
                kappa
            )
        ));

        require(verifySignature(signature, hash, commitmentAddress));

        BRIDGE.mint(to, token, amount, fee, kappa);
    }

    /**
     * @notice Nodes call this function to mint a SynERC20 (or any asset that the bridge is given minter access to), and then attempt to swap the SynERC20 into the desired destination asset. This is called by the nodes after a TokenDepositAndSwap event is emitted.
     * @dev This means the BridgeDeposit.sol contract must have minter access to the token attempting to be minted
     * @param to address on other chain to redeem underlying assets to
     * @param token ERC20 compatible token to deposit into the bridge
     * @param amount Amount in native token decimals to transfer cross-chain post-fees
     * @param fee Amount in native token decimals to save to the contract as fees
     * @param pool Destination chain's pool to use to swap SynERC20 -> Asset. The nodes determine this by using PoolConfig.sol.
     * @param tokenIndexFrom Index of the SynERC20 asset in the pool
     * @param tokenIndexTo Index of the desired final asset
     * @param minDy Minumum amount (in final asset decimals) that must be swapped for, otherwise the user will receive the SynERC20.
     * @param deadline Epoch time of the deadline that the swap is allowed to be executed.
     * @param kappa kappa
     */
    function mintAndSwap(
        address payable to,
        IERC20Mintable token,
        uint256 amount,
        uint256 fee,
        IMetaSwapDeposit pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline,
        bytes32 kappa,
        uint256 signature,
        address commitmentAddress
    )
        external
    {
        uint256 hash = uint256(keccak256(
            abi.encode(
                MINT_AND_SWAP_TYPE,
                to,
                token,
                amount,
                fee,
                pool,
                tokenIndexFrom,
                tokenIndexTo,
                minDy,
                deadline,
                kappa
            )
        ));

        require(verifySignature(signature, hash, commitmentAddress));

        BRIDGE.mintAndSwap(to, token, amount, fee, pool, tokenIndexFrom, tokenIndexTo, minDy, deadline, kappa);
    }

    /**
     * @notice Function to be called by the node group to withdraw the underlying assets from the contract
     * @param to address on chain to send underlying assets to
     * @param token ERC20 compatible token to withdraw from the bridge
     * @param amount Amount in native token decimals to withdraw
     * @param fee Amount in native token decimals to save to the contract as fees
     * @param pool Destination chain's pool to use to swap SynERC20 -> Asset. The nodes determine this by using PoolConfig.sol.
     * @param swapTokenIndex Specifies which of the underlying LP assets the nodes should attempt to redeem for
     * @param swapMinAmount Specifies the minimum amount of the underlying asset needed for the nodes to execute the redeem/swap
     * @param swapDeadline Specificies the deadline that the nodes are allowed to try to redeem/swap the LP token
     * @param kappa kappa
     */
    function withdrawAndRemove(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        ISwap pool,
        uint8 swapTokenIndex,
        uint256 swapMinAmount,
        uint256 swapDeadline,
        bytes32 kappa,
        uint256 signature,
        address commitmentAddress
    )
        external
    {
        uint256 hash = uint256(keccak256(
            abi.encode(
                WITHDRAW_AND_REMOVE_TYPE,
                to,
                token,
                amount,
                fee,
                pool,
                swapTokenIndex,
                swapMinAmount,
                swapDeadline,
                kappa
            )
        ));

        require(verifySignature(signature, hash, commitmentAddress));

        BRIDGE.withdrawAndRemove(to, token, amount, fee, pool, swapTokenIndex, swapMinAmount, swapDeadline, kappa);
    }

    // <------------------------------->
    // FOR DEBUGGNIG: WILL REMOVE LATER
    function toAsciiString(address x)
        internal
        pure
        returns (string memory)
    {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint(uint160(x)) / (2**(8*(19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2*i] = char(hi);
            s[2*i+1] = char(lo);
        }

        return string(s);
    }

    function char(bytes1 b)
        internal
        pure
        returns (bytes1 c)
    {
        if (uint8(b) < 10) {
            c = bytes1(uint8(b) + 0x30);
        } else {
            c = bytes1(uint8(b) + 0x57);
        }
    }

    function uint2str(
        uint256 _i
    )
        internal
        pure
        returns (string memory)
    {
        if (_i == 0)
        {
            return "0";
        }

        uint256 length;

        uint256 j = _i;
        while (j != 0)
        {
            length++;
            j /= 10;
        }

        bytes memory bstr = new bytes(length);
        uint256 k = length;

        j = _i;
        while (j != 0)
        {
            bstr[--k] = bytes1(uint8(48 + j % 10));
            j /= 10;
        }

        return string(bstr);
    }
}
