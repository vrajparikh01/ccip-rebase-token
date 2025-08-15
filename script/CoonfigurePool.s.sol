// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";

contract ConfigurePoolScript is Script {
    function run(
        address localPool, 
        uint64 remoteChainSelector, 
        address remotePool, 
        address remoteToken, 
        bool outboundRateLimiterIsEnabled, 
        uint128 outboundrateLimiterCapacity,
        uint128 outboundrateLimiterRate,
        bool inboundRateLimiterIsEnabled, 
        uint128 inboundrateLimiterCapacity,
        uint128 inboundrateLimiterRate
    ) public {
        vm.startBroadcast();
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            allowed: true,
            remotePoolAddress: abi.encode(remotePool),
            remoteTokenAddress: abi.encode(remoteToken),
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: outboundRateLimiterIsEnabled,
                capacity: outboundrateLimiterCapacity,
                rate: outboundrateLimiterRate
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: inboundRateLimiterIsEnabled,
                capacity: inboundrateLimiterCapacity,
                rate: inboundrateLimiterRate
            })
        });
        TokenPool(localPool).applyChainUpdates(chainsToAdd);
        vm.stopBroadcast();
    }
}