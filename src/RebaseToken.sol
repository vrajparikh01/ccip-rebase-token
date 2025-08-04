// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/*
* @title RebaseToken
* @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards.
* @notice The interest rate in the smart contract can only decrease 
* @notice Each will user will have their own interest rate that is the global interest rate at the time of depositing.
*/
contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 currentRate, uint256 newRate);

    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 public constant PRECISION_FACTOR = 1e18;

    uint256 public s_interestRate = 5e10; // Global interest rate of token=
    mapping(address => uint256) public s_userInterestRates; // User-specific interest rates
    mapping(address => uint256) public s_userLastUpdatedTimestamp; // User-specific last updated timestamps

    event InterestRateSet(uint256 newInterestRate);

    constructor()
        ERC20("RebaseToken", "RT")
        Ownable(msg.sender)
    {}

    function grantMintAndBurnRole(address account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, account);
    }

    /*
    * @notice Sets the global interest rate for the protocol.
    * @param _newInterestRate The new interest rate to be set.
    * @dev This function can only decrease the interest rate.
    */
    function setInterestRate(uint256 newInterestRate) public onlyOwner {
        if(newInterestRate > s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, newInterestRate);
        }
        s_interestRate = newInterestRate;
        emit InterestRateSet(newInterestRate);
    }

    /*
    * @notice Gets the principal balance of a user without any accrued interest.
    * @param user The address of the user to get the principal balance for.
    * @return The principal balance of the user.
    */
    function getPrincipalBalance(address user) external view returns (uint256) {
        return super.balanceOf(user);
    }

    /*
    * @notice Mints tokens to user when they deposit into the vault.
    * @param to The address of the user to mint tokens to.
    * @param amount The amount of tokens to mint.
    */
    function mint(address to, uint256 amount) external onlyRole(MINT_AND_BURN_ROLE) {
        // Mint the accrued interest to the user
        _mintAccruedInterest(to);

        // Set the user's interest rate to the current global interest rate
        s_userInterestRates[to] = s_interestRate;

        _mint(to, amount);
    }

    /*
    * @notice Burns tokens from the user when they withdraw from the vault.
    * @param from The address of the user to burn tokens from.
    * @param amount The amount of tokens to burn.
    * @dev If the amount is max uint256, it will burn the entire balance of the user.
    */
    function burn(address from, uint256 amount) external onlyRole(MINT_AND_BURN_ROLE) {
        // This allows users to burn all their tokens in one transaction if amount is max uint256
        if (amount == type(uint256).max) {
            amount = balanceOf(from);
        }

        // Burn the accrued interest for the user
        _mintAccruedInterest(from);

        // Burn the specified amount of tokens from the user
        _burn(from, amount);
    }

    /*
    * @notice Calculates balance of the user including accrued interest that has accumulated since the last update.
    * @param user The address of the user to calculate the balance for.
    * @return The balance of the user including accrued interest.
    */
    function balanceOf(address user) public view override returns (uint256) {
        // Fetch the principal balance of the user
        // Multiply the principal balance by the interest accrued since the last update
        return super.balanceOf(user) * _calculateUserInterestSinceLastUpdate(user) / PRECISION_FACTOR;
    }

    /*
    * @notice Transfers tokens from the sender to a recipient.
    * @param recipient The address of the recipient to transfer tokens to.
    * @param amount The amount of tokens to transfer.
    * @return A boolean indicating whether the transfer was successful.
    * @dev This function mints accrued interest for both the sender and recipient before transferring.
    */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        // Mint accrued interest before transferring
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(recipient);
        if(amount == type(uint256).max) {
            amount = balanceOf(msg.sender);
        }

        // if the recipient has no balance, set their interest rate to the sender's interest rate
        // This ensures that the recipient will start accruing interest at the same rate as the sender
        if(balanceOf(recipient) == 0){
            s_userInterestRates[recipient] = s_userInterestRates[msg.sender];
        }

        // Call the parent transfer function
        return super.transfer(recipient, amount);
    }

    /*
    * @notice Transfers tokens from one address to another.
    * @param sender The address of the sender to transfer tokens from.
    * @param recipient The address of the recipient to transfer tokens to.
    * @param amount The amount of tokens to transfer.
    * @return A boolean indicating whether the transfer was successful.
    * @dev This function mints accrued interest for both the sender and recipient before transferring.
    */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        // Mint accrued interest before transferring
        _mintAccruedInterest(sender);
        _mintAccruedInterest(recipient);
        if(amount == type(uint256).max) {
            amount = balanceOf(sender);
        }
        if(balanceOf(recipient) == 0){
            s_userInterestRates[recipient] = s_userInterestRates[sender];
        }

        return super.transferFrom(sender, recipient, amount);
    }

    /*
    * @notice Calculates the interest factor for a user based on their interest rate and time since last update.
    * @param user The address of the user to calculate the interest accumulated for.
    * @return The interest that has accumulated for the user
    */
    function _calculateUserInterestSinceLastUpdate(address user) internal view returns (uint256 linearInterest) {
        // Calculate the time since the last update (linear growth with time)
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[user];
        
        // Calculate the amount of linear growth
        // principal_amount + (principal_amount * interest rate * time elapsed)
        // principal_amount (1 + (interest rate * time elapsed))
        // eg: deposit 10 tokens, interest rate is 0.5% , time elapsed is 5 seconds
        // 10 + (10 * 0.5 * 5) 
        linearInterest = PRECISION_FACTOR + (s_userInterestRates[user] * timeElapsed);
    }

    /*
    * @notice Calculates the interest accrued for a user since their last time they interacted with the protocol
    * @param user The address of the user to calculate interest for.
    */
    function _mintAccruedInterest(address user) internal {
        // 1. Find the current balance of rebase token for the user - Principal balance
        uint256 principalBalance = super.balanceOf(user);
        // 2. Calcuate the current balance including interest -> balanceOf 
        uint256 currentBalance = balanceOf(user);
        // 3. Calculate no of tokens to mint = current balance - principal balance (2 - 1)
        uint256 tokensToMint = currentBalance - principalBalance;
        // set user's last updated timestamp to current block timestamp
        s_userLastUpdatedTimestamp[user] = block.timestamp;
        // 4. Mint the tokens to the user
        if (tokensToMint > 0) {
            _mint(user, tokensToMint);
        }
    }

    /*
    * @notice Returns the current interest rate set for the protocol.
    * @return The current interest rate.
    */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    /*
    * @notice Returns the interest rate for a specific user.
    * @param user The address of the user to get the interest rate for.
    * @return The interest rate for the user.
    * @dev This function retrieves the interest rate that was set for the user at the time
    * of their deposit into the vault.
    */
    function getUserInterestRate(address user) external view returns (uint256) {
        return s_userInterestRates[user];
    }
}
