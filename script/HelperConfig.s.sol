// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

contract HelperConfig is Script {

    struct NetworkConfig {
        address oracle;
        uint256 deployerKey;
        string rpcUrl;
    }

    uint256 public constant ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    NetworkConfig public s_activeConfig;

    constructor() {
        if (block.chainid == 84532) {
            s_activeConfig = getBaseSepoliaConfig();
        } else {
            s_activeConfig = getAnvilConfig();
        }
    }

    function activeConfig() external view returns (NetworkConfig memory) {
        return s_activeConfig;
    }

    function getBaseSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            oracle: vm.envAddress("ORACLE_ADDRESS"),
            deployerKey: vm.envUint("PRIVATE_KEY"),
            rpcUrl: vm.envString("BASE_SEPOLIA_RPC")
        });
    }

    function getAnvilConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            oracle: address(1),
            deployerKey: ANVIL_PRIVATE_KEY,
            rpcUrl: "http://127.0.0.1:8545"
        });
    }
}