// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));

        // grant the mint and burn role to the vault
        rebaseToken.grantMintAndBurnRole(address(vault));

        // (bool success, ) = payable(address(vault)).call{value: 1 ether}("");
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 amount) public{
        (bool success, ) = payable(address(vault)).call{value: amount}("");
        require(success, "Failed to add rewards to vault");
    }

    function testDepositLinear(uint256 amount) public {
        // use bound to ensure the amount is within a reasonable range (instead of using assume)
        amount = bound(amount, 1e5, type(uint96).max);

        vm.startPrank(user);
        vm.deal(user, amount);

        // User deposits into the vault
        vault.deposit{value: amount}();

        // Check that start balance is amount deposited
        uint256 startBalance = rebaseToken.balanceOf(user);
        assertEq(startBalance, amount);

        // warp the time and check balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        assertGt(middleBalance, startBalance);

        // warp the time again and check balance
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        assertGt(endBalance, middleBalance);

        // amount of growth should be same
        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);

        vm.stopPrank();
    }

    function testRedeem(uint256 amount) public {
        // use bound to ensure the amount is within a reasonable range (instead of using assume)
        amount = bound(amount, 1e5, type(uint96).max);

        vm.startPrank(user);
        vm.deal(user, amount);

        // User deposits into the vault
        vault.deposit{value: amount}();

        // Check that start balance is amount deposited
        uint256 startBalance = rebaseToken.balanceOf(user);
        assertEq(startBalance, amount);

        // User redeems from the vault
        vault.redeem(type(uint256).max);

        // Check that balance after redeem is zero
        uint256 endBalance = rebaseToken.balanceOf(user);
        assertEq(endBalance, 0);

        assertEq(address(user).balance, amount);

        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 depositAmount, uint256 time) public{
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);
        time = bound(time, 1000, type(uint96).max);

        // deposit amount
        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposit{value: depositAmount}();

        // warp the time
        vm.warp(block.timestamp + time);
        uint256 balance = rebaseToken.balanceOf(user);

        // Add rewards to the vault
        vm.prank(owner);
        vm.deal(owner, balance - depositAmount);
        addRewardsToVault(balance - depositAmount);

        // User redeems from the vault
        vm.prank(user);
        vault.redeem(type(uint256).max);

        uint256 ethBalance = address(user).balance;
        assertEq(ethBalance, balance);
        assertGt(ethBalance, depositAmount);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        // use bound to ensure the amount is within a reasonable range (instead of using assume)
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        // User deposits into the vault
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address user2 = makeAddr("user2");
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 user2Balance = rebaseToken.balanceOf(user2);
        assertEq(userBalance, amount);
        assertEq(user2Balance, 0);

        // reduce the interest rate
        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        // Transfer some tokens to another user
        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);

        uint256 userBalanceAfter = rebaseToken.balanceOf(user);
        uint256 user2BalanceAfter = rebaseToken.balanceOf(user2);
        assertEq(userBalanceAfter, userBalance - amountToSend);
        assertEq(user2BalanceAfter, amountToSend);

        // check the user interest rates have been inherited
        assertEq(rebaseToken.getUserInterestRate(user), 5e10);
    }

    function testUserCannotSetInterestRate() public {
        vm.prank(user);
        vm.expectPartialRevert(bytes4(Ownable.OwnableUnauthorizedAccount.selector));
        rebaseToken.setInterestRate(6e10);
    }

    function testUserCannotMintAndBurn() public {
        vm.prank(user);
        vm.expectPartialRevert(bytes4(IAccessControl.AccessControlUnauthorizedAccount.selector));
        rebaseToken.mint(user, 1e18);

        vm.prank(user);
        vm.expectPartialRevert(bytes4(IAccessControl.AccessControlUnauthorizedAccount.selector));
        rebaseToken.burn(user, 1e18);
    }

    function testGetPrincialBalance() public {
        vm.deal(user, 1e18);
        vm.prank(user);
        vault.deposit{value: 1e18}();

        uint256 principalBalance = rebaseToken.getPrincipalBalance(user);
        assertEq(principalBalance, 1e18);

        // warp the time and check principal balance remains the same
        vm.warp(block.timestamp + 1 hours);
        uint256 principalBalanceAfter = rebaseToken.getPrincipalBalance(user);
        assertEq(principalBalanceAfter, principalBalance);
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 initialInterestRate = rebaseToken.getInterestRate();
        newInterestRate = bound(newInterestRate, initialInterestRate, type(uint96).max);

        vm.prank(owner);
        vm.expectPartialRevert(bytes4(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector));
        rebaseToken.setInterestRate(newInterestRate);
        assertEq(rebaseToken.getInterestRate(), initialInterestRate);
    }
}