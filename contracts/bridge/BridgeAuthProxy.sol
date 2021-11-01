// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '@openzeppelin/contracts-upgradeable/proxy/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import './interfaces/IMetaSwapDeposit.sol';
import './interfaces/ISwap.sol';
import './interfaces/IWETH9.sol';
import "./interfaces/ISynapseBridge.sol";

contract BridgeAuthProxy is Initializable, AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Mintable;
    using SafeMath for uint256;

    ISynapseBridge public BRIDGE;

    bytes32 public constant GOVERNANCE_ROLE = keccak256('GOVERNANCE_ROLE');

    // See https://en.bitcoin.it/wiki/Secp256k1 for this constant.
    uint256 constant public Q = // Group order of secp256k1
    // solium-disable-next-line indentation
    0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
    // solium-disable-next-line zeppelin/no-arithmetic-operations
    uint256 constant public HALF_Q = (Q >> 1) + 1;

    // here we define the event types that prefix the arguments in each
    // hashing operation. These prevent signatures with the same arguments
    // from being used cross event
    uint constant WITHDRAW_EVENT_TYPE = 5;
    uint constant MINT_EVENT_TYPE = 6;
    uint constant MNINT_AND_SWAP_TYPE = 7;
    uint constant WITHDRAW_AND_REMOVE_TYPE = 8;

    // schnorr_pubkey contains the public key schnorr signatures are verified against.
    address schnorr_pubkey;
    uint256 signingPubKeyX;
    uint8 pubKeyYParity;

    function initialize() external initializer {
        // initialize initializes the auth proxy
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        __AccessControl_init();
    }

    function setSchnorrPubKey(uint256 _signingPubKeyX, uint8 _pubKeyYParity, address _schnorr_pubkey) external {
        require(hasRole(GOVERNANCE_ROLE, msg.sender));
        require(_signingPubKeyX < HALF_Q, "Public-key x >= HALF_Q");

        // Forbid trivial inputs, to avoid ecrecover edge cases. The main thing to
        // avoid is something which causes ecrecover to return 0x0: then trivial
        // signatures could be constructed with the nonceTimesGeneratorAddress input
        // set to 0x0.
        //
        // solium-disable-next-line indentation
        require(_schnorr_pubkey != address(0) && _signingPubKeyX > 0);

        signingPubKeyX =  _signingPubKeyX;
        schnorr_pubkey = _schnorr_pubkey;
        pubKeyYParity = _pubKeyYParity;
    }

    /** **************************************************************************
@notice verifySignature returns true iff passed a valid Schnorr signature.
      @dev See https://en.wikipedia.org/wiki/Schnorr_signature for reference.
      @dev In what follows, let d be your secret key, PK be your public key,
      PKx be the x ordinate of your public key, and PKyp be the parity bit for
      the y ordinate (i.e., 0 if PKy is even, 1 if odd.)
      **************************************************************************
      @dev TO CREATE A VALID SIGNATURE FOR THIS METHOD
      @dev First PKx must be less than HALF_Q. Then follow these instructions
           (see evm/test/schnorr_test.js, for an example of carrying them out):
      @dev 1. Hash the target message to a uint256, called _msgHash here, using
              keccak256
      @dev 2. Pick k uniformly and cryptographically securely randomly from
              {0,...,Q-1}. It is critical that k remains confidential, as your
              private key can be reconstructed from k and the signature.
      @dev 3. Compute k*g in the secp256k1 group, where g is the group
              generator. (This is the same as computing the public key from the
              secret key k. But it's OK if k*g's x ordinate is greater than
              HALF_Q.)
      @dev 4. Compute the ethereum address for k*g. This is the lower 160 bits
              of the keccak hash of the concatenated affine coordinates of k*g,
              as 32-byte big-endians. (For instance, you could pass k to
              ethereumjs-utils's privateToAddress to compute this, though that
              should be strictly a development convenience, not for handling
              live secrets, unless you've locked your javascript environment
              down very carefully.) Call this address
              nonceTimesGeneratorAddress.
      @dev 5. Compute e=uint256(keccak256(PKx as a 32-byte big-endian
                                        ‖ PKyp as a single byte
                                        ‖ _msgHash
                                        ‖ nonceTimesGeneratorAddress))
              This value e is called "msgChallenge" in verifySignature's source
              code below. Here "‖" means concatenation of the listed byte
              arrays.
      @dev 6. Let x be your secret key. Compute s = (k - d * e) % Q. Add Q to
              it, if it's negative. This is your _signature. (d is your secret
              key.)
      **************************************************************************
      @dev TO VERIFY A SIGNATURE
      @dev Given a signature (s, e) of _msgHash, constructed as above, compute
      S=e*PK+s*generator in the secp256k1 group law, and then the ethereum
      address of S, as described in step 4. Call that
      _nonceTimesGeneratorAddress. Then call the verifySignature method as:
      @dev    verifySignature(PKx, PKyp, s, _msgHash,
                              _nonceTimesGeneratorAddress)
      **************************************************************************
      @dev This signging scheme deviates slightly from the classical Schnorr
      signature, in that the address of k*g is used in place of k*g itself,
      both when calculating e and when verifying sum S as described in the
      verification paragraph above. This reduces the difficulty of
      brute-forcing a signature by trying random secp256k1 points in place of
      k*g in the signature verification process from 256 bits to 160 bits.
      However, the difficulty of cracking the public key using "baby-step,
      giant-step" is only 128 bits, so this weakening constitutes no compromise
      in the security of the signatures or the key.
      @dev The constraint _signingPubKeyX < HALF_Q comes from Eq. (281), p. 24
      of Yellow Paper version 78d7b9a. ecrecover only accepts "s" inputs less
      than HALF_Q, to protect against a signature- malleability vulnerability in
      ECDSA. Schnorr does not have this vulnerability, but we must account for
      ecrecover's defense anyway. And since we are abusing ecrecover by putting
      _signingPubKeyX in ecrecover's "s" argument the constraint applies to
      _signingPubKeyX, even though it represents a value in the base field, and
      has no natural relationship to the order of the curve's cyclic group.
      **************************************************************************
      @param signature to validate against schnorr pub key
      @param msgHash hash of the signed message.
      **************************************************************************
      @return True if passed a valid signature, false otherwise. */
    function verifySignature(
        uint256 signature,
        uint256 msgHash) internal returns (bool) {
        // ignore trivial inputs
        require(signature > 0 && msgHash > 0, "no zero inputs allowed");
        require(signature < Q, "signature must be reduced modulo Q");

        // solium-disable-next-line indentation
        uint256 msgChallenge = // "e"
        // solium-disable-next-line indentation
        uint256(keccak256(abi.encodePacked(signingPubKeyX, pubKeyYParity,
            msgHash, schnorr_pubkey))
        );

        // Verify msgChallenge * signingPubKey + signature * generator ==
        //        nonce * generator
        //
        // https://ethresear.ch/t/you-can-kinda-abuse-ecrecover-to-do-ecmul-in-secp256k1-today/2384/9
        // The point corresponding to the address returned by
        // ecrecover(-s*r,v,r,e*r) is (r⁻¹ mod Q)*(e*r*R-(-s)*r*g)=e*R+s*g, where R
        // is the (v,r) point. See https://crypto.stackexchange.com/a/18106
        //
        // solium-disable-next-line indentation
        address recoveredAddress = ecrecover(
        // solium-disable-next-line zeppelin/no-arithmetic-operations
            bytes32(Q - mulmod(signingPubKeyX, signature, Q)),
        // https://ethereum.github.io/yellowpaper/paper.pdf p. 24, "The
        // value 27 represents an even y value and 28 represents an odd
        // y value."
            (pubKeyYParity == 0) ? 27 : 28,
            bytes32(signingPubKeyX),
            bytes32(mulmod(msgChallenge, signingPubKeyX, Q)));
        return schnorr_pubkey == recoveredAddress;
    }

    function setBridgeAddress(address payable _bridgeAddress) external {
        require(hasRole(GOVERNANCE_ROLE, msg.sender));
        BRIDGE = ISynapseBridge(_bridgeAddress);
    }

    /**
     * @notice Function to be called by the node group to withdraw the underlying assets from the contract
   * @param to address on chain to send underlying assets to
   * @param token ERC20 compatible token to withdraw from the bridge
   * @param amount Amount in native token decimals to withdraw
   * @param fee Amount in native token decimals to save to the contract as fees
   * @param kappa kappa
   **/
    function withdraw(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa,
        uint256 signature
    ) external  {
        uint256 hash = uint256(keccak256(abi.encodePacked(WITHDRAW_EVENT_TYPE, to, token, amount, fee, kappa)));
        require(verifySignature(signature, hash));
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
   **/
    function mint(
        address payable to,
        IERC20Mintable token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa,
        uint256 signature
    ) external  {
        uint256 hash = uint256(keccak256(abi.encodePacked(MINT_EVENT_TYPE, to, token, amount, fee, kappa)));
        require(verifySignature(signature, hash));
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
   **/
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
        uint256 signature
    ) external  {
        uint256 hash = uint256(keccak256(abi.encodePacked(MINT_EVENT_TYPE, to, token, amount, fee, pool, tokenIndexFrom, tokenIndexTo, minDy, deadline, kappa)));
        require(verifySignature(signature, hash));
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
   **/
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
        uint256 signature
    ) external  {
        uint256 hash = uint256(keccak256(abi.encodePacked(WITHDRAW_AND_REMOVE_TYPE, to, token, amount, fee, pool, swapTokenIndex, swapMinAmount, swapDeadline, kappa)));
        require(verifySignature(signature, hash));
        BRIDGE.withdrawAndRemove(to, token, amount, fee, pool, swapTokenIndex, swapMinAmount, swapDeadline, kappa);
    }
}
