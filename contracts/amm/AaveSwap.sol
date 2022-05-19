// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./Swap.sol";

/**
 * @title AaveSwap - A StableSwap implementation in solidity, integrated with Aave.
 * @notice This contract is responsible for custody of closely pegged assets (eg. group of stablecoins)
 * and automatic market making system. Users become an LP (Liquidity Provider) by depositing their tokens
 * in desired ratios for an exchange of the pool token that represents their share of the pool.
 * Users can burn pool tokens and withdraw their share of token(s).
 *
 * Each time a swap between the pooled tokens happens, a set fee incurs which effectively gets
 * distributed to the LPs.
 *
 * In case of emergencies, admin can pause additional deposits, swaps, or single-asset withdraws - which
 * stops the ratio of the tokens in the pool from changing.
 * Users can always withdraw their tokens via multi-asset withdraws.
 *
 * @dev Most of the logic is stored as a library `SwapUtils` for the sake of reducing contract's
 * deployment size.
 */

contract AaveSwap is Swap {
    address internal AAVE_REWARDS;
    address internal AAVE_LENDING_POOL;
    address internal REWARD_TOKEN;
    address internal REWARD_RECEIVER;
    address[] internal AAVE_ASSETS;

    /**
     * @notice Initializes this Swap contract with the given parameters.
     * This will also clone a LPToken contract that represents users'
     * LP positions. The owner of LPToken will be this contract - which means
     * only this contract is allowed to mint/burn tokens.
     *
     * @param _pooledTokens an array of ERC20s this pool will accept
     * @param decimals the decimals to use for each pooled token,
     * eg 8 for WBTC. Cannot be larger than POOL_PRECISION_DECIMALS
     * @param lpTokenName the long-form name of the token to be deployed
     * @param lpTokenSymbol the short symbol for the token to be deployed
     * @param _a the amplification coefficient * n * (n - 1). See the
     * StableSwap paper for details
     * @param _fee default swap fee to be initialized with
     * @param _adminFee default adminFee to be initialized with
     * @param lpTokenTargetAddress the address of an existing LPToken contract to use as a target
     */
    function initialize(
        IERC20[] memory _pooledTokens,
        uint8[] memory decimals,
        string memory lpTokenName,
        string memory lpTokenSymbol,
        uint256 _a,
        uint256 _fee,
        uint256 _adminFee,
        address lpTokenTargetAddress
    ) public virtual override initializer {
        Swap.initialize(_pooledTokens, decimals, lpTokenName, lpTokenSymbol, _a, _fee, _adminFee, lpTokenTargetAddress);
        AAVE_REWARDS = 0x01D83Fe6A10D2f2B7AF17034343746188272cAc9;
        AAVE_LENDING_POOL = 0x4F01AeD16D97E3aB5ab2B501154DC9bb0F1A5A2C;
        REWARD_TOKEN = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
        AAVE_ASSETS = [0x53f7c5869a859F0AeC3D334ee8B4Cf01E3492f21];
        REWARD_RECEIVER = msg.sender;
    }

    function setRewardReceiver(address _reward_receiver) external onlyOwner {
        REWARD_RECEIVER = _reward_receiver;
    }

    function claimAaveRewards() external {
        AAVE_REWARDS.call(
            abi.encodeWithSignature(
                "claimRewards(address[],uint256,address)",
                AAVE_ASSETS,
                type(uint256).max,
                REWARD_RECEIVER
            )
        );
    }
}
