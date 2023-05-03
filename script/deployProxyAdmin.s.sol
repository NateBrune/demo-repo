// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {CREATE3Script} from "./base/CREATE3Script.sol";
//import {RouterProxyAdmin} from "../src/RouterProxyAdmin.sol";
//import {BofRouterFactory} from "../src/BofRouterFactory.sol";
//import {BofRouter} from "../src/BofRouter.sol";
//import {ChainZapTUP} from "../src/ChainZapTUP.sol";

import {CREATE3} from "../lib/solmate/src/utils/CREATE3.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";



contract DeployProxyAdminScript is CREATE3Script {
    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() external returns (ProxyAdmin _proxyAdmin) {
      address gov = (0x74DE73F2C586ba6Ed7B154c5460A7Ef42e8194cE);
      uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
      vm.startBroadcast(deployerPrivateKey);
      _proxyAdmin = new ProxyAdmin();
      vm.stopBroadcast();
    }
}