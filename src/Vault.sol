// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IRebaseToken.sol";

contract Vault {
    IRebaseToken public immutable i_rebaseToken;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    error Vault__RedeemFailed();

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    /**
     * @notice Allows users to deposit ETH into the vault and mint RebaseTokens in return
     */
    function deposit() external payable {
        // we need to mint tokens to the user when they deposit ETH
        i_rebaseToken.mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Allows users to redeem their RebaseTokens for ETH
     * @param amount The amount of RebaseTokens to redeem
     */
    function redeem(uint256 amount) external {
        // we need to burn tokens from the user when they redeem
        i_rebaseToken.burn(msg.sender, amount);
        // and send them the equivalent amount of ETH
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if(!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeem(msg.sender, amount);
    }

    /**
     * @notice Returns the address of the RebaseToken contract
     */
    function getRebaseToken() external view returns (address) {
        return address(i_rebaseToken);
    }
}