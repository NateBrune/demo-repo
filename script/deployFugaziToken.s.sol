// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {CREATE3Script} from "./base/CREATE3Script.sol";
import {RouterProxyAdmin} from "../src/RouterProxyAdmin.sol";
import {BofRouterFactory} from "../src/BofRouterFactory.sol";
import {BofRouter} from "../src/BofRouter.sol";
import {ChainZapTUP} from "../src/ChainZapTUP.sol";
import {FugaziToken} from "../src/Fugazi.sol";

import {CREATE3} from "../lib/solmate/src/utils/CREATE3.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";


contract DeployFugaziScript is CREATE3Script {
    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() external returns (TransparentUpgradeableProxy _fugazi) {
      uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

      address proxyAdmin = 0x7c5Dd78e4585d1Ba3CEc8e4acC1037a4854B2aB0;
      address gov = (0x74DE73F2C586ba6Ed7B154c5460A7Ef42e8194cE);

      vm.startBroadcast(deployerPrivateKey);
      FugaziToken fugazi = new FugaziToken();
      _fugazi = new TransparentUpgradeableProxy(
        address(fugazi), 
        proxyAdmin, 
        abi.encodeWithSelector(
          FugaziToken.initialize.selector
        )
      );
	
      vm.stopBroadcast();
    }
}