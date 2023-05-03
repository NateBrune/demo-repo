// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {CREATE3Script} from "./base/CREATE3Script.sol";
import {RouterProxyAdmin} from "../src/RouterProxyAdmin.sol";
import {BofRouterFactory} from "../src/BofRouterFactory.sol";
import {BofRouter} from "../src/BofRouter.sol";
import {ChainZapTUP} from "../src/ChainZapTUP.sol";

import {CREATE3} from "../lib/solmate/src/utils/CREATE3.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";


contract DeployZapSepoliaScript is CREATE3Script {
    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() external returns (TransparentUpgradeableProxy _tup) {
      uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

      address proxyAdmin = 0x150a0ee7393294442EE4d4F5C7d637af01dF93ee;
      address gov = (0x74DE73F2C586ba6Ed7B154c5460A7Ef42e8194cE);
      address ccipRouterSepolia = (0x0A36795B3006f50088c11ea45b960A1b0406f03b);
      address chainlinkSepolia = (0x779877A7B0D9E8603169DdbD7836e478b4624789);

      vm.startBroadcast(deployerPrivateKey);
      ChainZapTUP zap = new ChainZapTUP();
      _tup = new TransparentUpgradeableProxy(
        address(zap), 
        proxyAdmin, 
        abi.encodeWithSelector(
          ChainZapTUP.initialize.selector, 
          proxyAdmin,
          ccipRouterSepolia,
          chainlinkSepolia,
          gov,
          address(0),
          uint64(11155111)
        )
      );
	
      vm.stopBroadcast();
    }
}