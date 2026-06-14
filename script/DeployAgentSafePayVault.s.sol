// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/Script.sol";
import { AgentSafePayVault } from "../src/AgentSafePayVault.sol";

/**
 * @title DeployAgentSafePayVault
 * @notice Deploys the AgentSafePayVault with AGENT_ADDRESS from the environment.
 */
contract DeployAgentSafePayVault is Script {
    function run() external returns (AgentSafePayVault vault) {
        address initialAgent = vm.envOr("AGENT_ADDRESS", address(0));

        vm.startBroadcast();
        vault = new AgentSafePayVault(initialAgent);
        vm.stopBroadcast();

        console2.log("AgentSafePayVault:", address(vault));
        console2.log("Owner:", vault.owner());
        console2.log("Agent:", vault.agent());
    }
}
