// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

contract BridgeTokensScript is Script {
    function run(address receiverAddress, address tokenToSendAddress, uint256 amountToBridge, address linkAddress, address routerAddress, uint64 destinationChainSelector) public {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(tokenToSendAddress),
            amount: amountToBridge
        });

        // The message to be sent to the remote chain
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiverAddress), // The user will receive the tokens on the remote chain
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: linkAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV2({gasLimit: 500_000, allowOutOfOrderExecution: false}))
        });

        uint256 fee = IRouterClient(routerAddress).getFee(destinationChainSelector, message);
        IERC20(linkAddress).approve(routerAddress, fee);
        IERC20(address(tokenToSendAddress)).approve(routerAddress, amountToBridge);
        IRouterClient(routerAddress).ccipSend(destinationChainSelector, message);
    }
}