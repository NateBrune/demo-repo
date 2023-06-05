// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {CREATE3Script} from "./base/CREATE3Script.sol";
import {RouterProxyAdmin} from "../src/RouterProxyAdmin.sol";
import {BofRouterFactory} from "../src/BofRouterFactory.sol";
import {BofRouter} from "../src/BofRouter.sol";
import {ChainZapTUP} from "../src/ChainZapTUP.sol";

import {CREATE3} from "../lib/solmate/src/utils/CREATE3.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";


contract DeployScript is CREATE3Script {
	constructor() CREATE3Script(vm.envString("VERSION")) {}

	function run() external returns (BofRouterFactory factory) {
		uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

		ChainZapTUP newImpl = new ChainZapTUP();
		ProxyAdmin proxyAdmin = ProxyAdmin(0x150a0ee7393294442EE4d4F5C7d637af01dF93ee);
		address ccipRouterSepolia = 0xA5bD184D05C7535C8A022905558974752e646a88;
		address chainlinkSepolia = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
		address gov = 0x74DE73F2C586ba6Ed7B154c5460A7Ef42e8194cE;
		ITransparentUpgradeableProxy proxy = ITransparentUpgradeableProxy(0xc5f502Ae5972c938940b33308f8845cbe80211B5);
		
		vm.startBroadcast(deployerPrivateKey);
		//BofRouter wallet = new BofRouter();
		// factory = new BofRouterFactory();
		proxyAdmin.upgradeAndCall(proxy, address(newImpl), abi.encodeWithSelector(
				ChainZapTUP.initialize.selector, 
				address(proxyAdmin),
				ccipRouterSepolia,
				chainlinkSepolia,
				gov,
				address(0)
			));

		// new TransparentUpgradeableProxy(
		// 	address(factory), 
		// 	proxyAdmin, 
		// 	abi.encodeWithSelector(
		// 		ChainZapTUP.initialize.selector, 
		// 		address(proxyAdmin),
		// 		ccipRouterSepolia,
		// 		chainlinkSepolia,
		// 		gov,
		// 		address(0)
		// 	)
		// );

		vm.stopBroadcast();
	}
}