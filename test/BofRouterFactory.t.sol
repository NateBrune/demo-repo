// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "./BaseSetup.t.sol";
import "../src/BofRouterFactory.sol";
import "../src/RouterProxyAdmin.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";

contract BofRouterFactoryTest is BaseSetup {

	address public constant usdc = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address public constant random_address_1 = 0xEb9b53d7601a086661Bb02d43F5edA850d0955C2;
    address public constant random_address_2 = 0xD4EB788824779eE6AC7A8a2Cd943c41C0f3D947D;
    address public constant random_address_account_registry = 0xD123B70Ced1EEfa4d14c4dF62106E8d018f9dA8C;
    BofRouterFactory public routerFactory;
	OwnerCallProxy ownerCallProxy = new OwnerCallProxy();
	RouterProxyAdmin routerProxyAdmin = new RouterProxyAdmin(ownerCallProxy);
	
    address public whitelister;

    function setUp() public override {
        super.setUp();
        whitelister = createUsers(1)[0];
        vm.label(whitelister, "whitelister");
		BofRouter routerImpl = new BofRouter();
		ProxyAdmin proxyAdmin = new ProxyAdmin();
        BofRouterFactory impl = new BofRouterFactory();
		routerFactory = BofRouterFactory(address(new TransparentUpgradeableProxy(
			address(impl), 
			address(proxyAdmin), 
			abi.encodeWithSelector(
				BofRouterFactory.initialize.selector, 
				whitelister, 
				random_address_account_registry, 
				address(routerImpl),
				address(routerProxyAdmin)
			)
		)));
        routerFactory.setGovernance(gov);
        vm.prank(gov);
        routerFactory.acceptGovernance();
    }

    function testChangeGov() public {
        console.log("Gov is: ", routerFactory.gov());        
        vm.prank(rando);
        vm.expectRevert(bytes("!Gov"));
        routerFactory.setGovernance(random_address_1);
        vm.prank(gov);
        routerFactory.setGovernance(random_address_2);
        assertEq(routerFactory.pendingGov(), random_address_2);
        vm.prank(rando);
        vm.expectRevert("!PendingGov");
        routerFactory.acceptGovernance();
        vm.prank(random_address_2);
        routerFactory.acceptGovernance();
        assertEq(routerFactory.pendingGov(), address(0));
        assertEq(routerFactory.gov(), random_address_2);
        console.log("Gov after: ", routerFactory.gov());      
    }

    function testChangeAccountRegistry() public {
        console.log("Gov is: ", routerFactory.gov());        
        console.log("AccountRegistry before: ", routerFactory.accountRegistry());        
        vm.prank(rando);
        vm.expectRevert(bytes("!Gov"));
        routerFactory.setAccountRegistry(random_address_1);
        vm.prank(gov);
        routerFactory.setAccountRegistry(random_address_2);
        assertEq(routerFactory.accountRegistry(), random_address_2);
        console.log("AccountRegistry after: ", routerFactory.accountRegistry());        
    }

    function testChangeImmersve() public {
        console.log("Gov is: ", routerFactory.gov());        
        console.log("Whitelister before: ", routerFactory.walletWhitelister());        
        vm.prank(rando);
        vm.expectRevert(bytes("!Gov"));
        routerFactory.setWalletWhitelister(random_address_1);
        vm.prank(gov);
        routerFactory.setWalletWhitelister(random_address_2);
        assertEq(routerFactory.walletWhitelister(), random_address_2);
        console.log("WalletWhitelister after: ", routerFactory.walletWhitelister());  
    }

    function testSetWhitelist() public {
        vm.prank(rando);
        vm.expectRevert("!WalletWhitelister");
        routerFactory.setWhitelist(random_address_1, true);

        vm.prank(gov);
        routerFactory.setWhitelist(random_address_1, true);
        assertEq(routerFactory.isWhitelisted(random_address_1), true);


        vm.prank(whitelister);
        routerFactory.setWhitelist(random_address_1, false);
        assertEq(routerFactory.isWhitelisted(random_address_1), false);
    }

    function testCreateWallet() public {
        vm.prank(whitelister);
        routerFactory.setWhitelist(user, true);

        //rando can't create a wallet, while user can
        vm.prank(rando);
        vm.expectRevert("!Whitelisted");
        routerFactory.createWallet();

        vm.prank(user);
        routerFactory.createWallet();

        assertTrue(address(routerFactory.wallets(user)) != address(0));

        vm.prank(user);
        vm.expectRevert("!WalletAlreadyCreated");
        routerFactory.createWallet();

    }

    function testCreateWalletFor() public {
        vm.prank(whitelister);
        routerFactory.setWhitelist(user, true);

        //rando can't create a wallet, while user can
        vm.prank(whitelister);
        vm.expectRevert("!Whitelisted");
        routerFactory.createWalletFor(rando);

        vm.prank(whitelister);
        routerFactory.createWalletFor(user);

        assertTrue(address(routerFactory.wallets(user)) != address(0));

        vm.prank(whitelister);
        vm.expectRevert("!WalletAlreadyCreated");
        routerFactory.createWalletFor(user);

    }

    function testUpdadeBofRouter() public {
		BofRouter newImpl = new BofRouter();
        vm.prank(whitelister);
        routerFactory.setWhitelist(user, true);

        //rando can't create a wallet, while user can
        vm.prank(user);
        routerFactory.createWallet();
		address walletProxy = routerFactory.wallets(user);

        vm.prank(whitelister);
        vm.expectRevert("RouterProxyAdmin: caller is not the owner");
		routerProxyAdmin.upgrade(walletProxy, address(newImpl));

        vm.prank(user);
		routerProxyAdmin.upgrade(walletProxy, address(newImpl));
    }
}
