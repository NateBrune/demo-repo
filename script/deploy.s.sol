// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {CREATE3Script} from "./base/CREATE3Script.sol";
import {RouterProxyAdmin,OwnerCallProxy} from "../src/RouterProxyAdmin.sol";
import {BofRouterFactory} from "../src/BofRouterFactory.sol";
import {BofRouter} from "../src/BofRouter.sol";

import {CREATE3} from "../lib/solmate/src/utils/CREATE3.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";


contract DeployScript is CREATE3Script {
    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() external returns (BofRouterFactory factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        // address whitelister = 0x87e40BCd15c66e01fc08e36b7933bD021909eF99;
		// address registry = 0xcA1616C955dfad8957cCDCf499Ce2853F6F87a58;
		// address routerProxyAdmin = 0xcab90fF4AEcb25b98Aaf51f375Cb6783f6EcBE44;
		// address proxyAdmin = 0x2282eed7b42d259C7230Df4B611885a1dC479E9a;
		address ownerCallProxy = 0x6F520449438c834B13321f946487A26Bc9AA14a2;
    
        vm.startBroadcast(deployerPrivateKey);
		// RouterProxyAdmin routerProxyAdmin = new RouterProxyAdmin(OwnerCallProxy(ownerCallProxy));
		// OwnerCallProxy ownerCallProxy = new OwnerCallProxy();
		// BofRouter wallet = new BofRouter();
		factory = new BofRouterFactory();
		// new TransparentUpgradeableProxy(
		// 	address(factory), 
		// 	proxyAdmin, 
		// 	abi.encodeWithSelector(
		// 		BofRouterFactory.initialize.selector, 
		// 		whitelister, 
		// 		registry, 
		// 		address(wallet),
		// 		address(routerProxyAdmin)
		// 	)
		// );
	
        vm.stopBroadcast();
    }
}