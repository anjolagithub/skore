// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/SkoreSBT.sol";
import "../src/SkoreOracle.sol";
import "./HelperConfig.s.sol";

contract Deploy is Script {
    function run() external {
        HelperConfig config = new HelperConfig();
        (address oracle, uint256 deployerKey,) = getConfig(config);
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        // Deploy SkoreSBT with oracle as initial oracle
        SkoreSBT skoreSBT = new SkoreSBT(oracle);
        console.log("SkoreSBT deployed:", address(skoreSBT));

        // Deploy SkoreOracle pointing to SkoreSBT
        SkoreOracle skoreOracle = new SkoreOracle(address(skoreSBT));
        console.log("SkoreOracle deployed:", address(skoreOracle));

        // Update SkoreSBT oracle to point to SkoreOracle
        skoreSBT.setOracle(address(skoreOracle));
        console.log("SkoreSBT oracle updated to SkoreOracle");

        vm.stopBroadcast();

        console.log("\n--- Copy these into your .env ---");
        console.log("SKORE_SBT_ADDRESS=%s", address(skoreSBT));
        console.log("SKORE_ORACLE_ADDRESS=%s", address(skoreOracle));
        console.log("DEPLOYER=%s", deployer);
    }

    function getConfig(HelperConfig config)
        internal
        view
        returns (address, uint256, string memory)
    {
        HelperConfig.NetworkConfig memory cfg = config.activeConfig();
        return (cfg.oracle, cfg.deployerKey, cfg.rpcUrl);
    }
}