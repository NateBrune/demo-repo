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

      address proxyAdmin = 0x882094c153D83DA48Df9660e7470a478199f1bd5;
      address gov = (0x74DE73F2C586ba6Ed7B154c5460A7Ef42e8194cE);
      address ccipRouterFuji = 0xb352E636F4093e4F5A4aC903064881491926aaa9;
      address chainlinkFuji = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846;

      vm.startBroadcast(deployerPrivateKey);
      ChainZapTUP zap = new ChainZapTUP();
      _tup = new TransparentUpgradeableProxy(
        address(zap), 
        proxyAdmin, 
        abi.encodeWithSelector(
          ChainZapTUP.initialize.selector, 
          proxyAdmin,
          ccipRouterFuji,
          chainlinkFuji,
          gov,
          address(0)
        )
      );
	
      vm.stopBroadcast();
    }
}