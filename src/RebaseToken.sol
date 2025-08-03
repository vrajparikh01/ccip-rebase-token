// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
* @title RebaseToken
* @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards.
* @notice The interest rate in the smart contract can only decrease 
* @notice Each will user will have their own interest rate that is the global interest rate at the time of depositing.
*/
contract RebaseToken is ERC20, Ownable {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 currentRate, uint256 newRate);

    uint256 public s_interestRate = 5e10; // Global interest rate of token=
    uint256 public constant PRECISION_FACTOR = 1e18;
    mapping(address => uint256) public s_userInterestRates; // User-specific interest rates
    mapping(address => uint256) public s_userLastUpdatedTimestamp; // User-specific last updated timestamps

    event InterestRateSet(uint256 newInterestRate);

    constructor(address initialOwner)
        ERC20("RebaseToken", "RT")
        Ownable(initialOwner)
    {}

    /*
    * @notice Sets the global interest rate for the protocol.
    * @param _newInterestRate The new interest rate to be set.
    * @dev This function can only decrease the interest rate.
    */
    function setInterestRate(uint256 _newInterestRate) public onlyOwner {
        if(_newInterestRate > s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    /*
    * @notice Mints tokens to user when they deposit into the vault.
    * @param to The address of the user to mint tokens to.
    * @param amount The amount of tokens to mint.
    */
    function mint(address to, uint256 amount) external onlyOwner {
        // Mint the accrued interest to the user
        _mintAccruedInterest(to);

        // Set the user's interest rate to the current global interest rate
        s_userInterestRates[to] = s_interestRate;

        _mint(to, amount);
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
    * @notice Calculates the interest accrued for a user since their last update.
    * @param user The address of the user to calculate interest for.
    * @return The interest accrued for the user since their last update.
    */
    function _mintAccruedInterest(address user) internal {
        // 1. Find the current balance of rebase token for the user - Principal balance
        // 2. Calcuate the current balance including interest -> balanceOf 
        // 3. Calculate no of tokens to mint = current balance - principal balance (2 - 1)
        // 4. Mint the tokens to the user
        // set user's last updated timestamp to current block timestamp
        s_userLastUpdatedTimestamp[user] = block.timestamp;
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
