// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {CREATE3Script} from "./base/CREATE3Script.sol";
import {RouterProxyAdmin} from "../src/RouterProxyAdmin.sol";
import {BofRouterFactory} from "../src/BofRouterFactory.sol";
import {BofRouter} from "../src/BofRouter.sol";
import {ChainZapTUP} from "../src/ChainZapTUP.sol";
import {FugaziToken} from "../src/Fugazi.sol";
import {DecoyRouter} from "../src/DecoyRouter.sol";

import {CREATE3} from "../lib/solmate/src/utils/CREATE3.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";


contract DeployDecoyRouterScript is CREATE3Script {
    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() external returns (DecoyRouter _decoy) {
      uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

      vm.startBroadcast(deployerPrivateKey);
      _decoy = new DecoyRouter();
      vm.stopBroadcast();
    }
}