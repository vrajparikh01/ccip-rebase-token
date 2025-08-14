// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";

import {CCIPLocalSimulatorFork} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";

contract RebaseTokenTest is Test {
    address constant owner = makeAddr("owner");

    uint256 sepoliaFork;
    uint256 arbSepoliaFork;

    CCIPLocalSimulatorFork ccipLocalSimulatorFork;

    RebaseToken sepoliaToken;
    RebaseToken arbSepoliaToken;

    Vault vault;

    function setUp() public {
        // alias which is named in the foundry.toml file
        sepoliaFork = vm.createSelectFork("sepolia");
        arbSepoliaFork = vm.createFork("arb-sepolia");

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        // Deploy and configure on sepolia
        vm.startPrank(owner);
        sepoliaToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(sepoliaToken)));
        vm.stopPrank();

        // Deploy and configure on arb-sepolia
        vm.selectFork(arbSepoliaFork);
        vm.startPrank(owner);
        arbSepoliaToken = new RebaseToken();
        vm.stopPrank();
    }
}