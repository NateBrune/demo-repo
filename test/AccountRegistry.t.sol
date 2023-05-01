// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "./BaseSetup.t.sol";
import "../src/AccountRegistry.sol";

contract MockVault {
    address public token;

    constructor (address _token) {
        token = _token;
    }
}

contract AccountRegistryTest is BaseSetup {

    AccountRegistry public accountRegistry;
    address public constant usdc = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address public constant random_address_1 = 0xEb9b53d7601a086661Bb02d43F5edA850d0955C2;
    address public constant random_address_2 = 0xD4EB788824779eE6AC7A8a2Cd943c41C0f3D947D;
    MockVault[] vaults;

    function setUp() public override {
        super.setUp();
        accountRegistry = new AccountRegistry(usdc, newGov); //Using a random address for immersve
        accountRegistry.setGovernance(gov);
        vm.prank(gov);
        accountRegistry.acceptGovernance();
        vaults.push(new MockVault(random_address_1));
        vaults.push(new MockVault(random_address_1));
        vaults.push(new MockVault(random_address_2));
        console.log("vaults[0] for token ", random_address_1, " -> ", address(vaults[0]));
        console.log("vaults[1] for token ", random_address_1, " -> ", address(vaults[1]));
        console.log("vaults[2] for token ", random_address_2, " -> ", address(vaults[2]));
    }

    function testChangeGov() public {
        console.log("Gov is: ", accountRegistry.gov());        
        vm.prank(rando);
        vm.expectRevert(bytes("!Gov"));
        accountRegistry.setGovernance(random_address_1);
        vm.prank(gov);
        accountRegistry.setGovernance(random_address_2);
        assertEq(accountRegistry.pendingGov(), random_address_2);
        vm.prank(rando);
        vm.expectRevert("!PendingGov");
        accountRegistry.acceptGovernance();
        vm.prank(random_address_2);
        accountRegistry.acceptGovernance();
        assertEq(accountRegistry.pendingGov(), address(0));
        assertEq(accountRegistry.gov(), random_address_2);
        console.log("Gov after: ", accountRegistry.gov());      
    }

    function testChangeUsdc() public {
        console.log("Gov is: ", accountRegistry.gov());        
        console.log("Usdc before: ", accountRegistry.usdc());        
        vm.prank(rando);
        vm.expectRevert(bytes("!Gov"));
        accountRegistry.setUsdc(random_address_1);
        vm.prank(gov);
        accountRegistry.setUsdc(random_address_2);
        assertEq(accountRegistry.usdc(), random_address_2);
        console.log("Usdc after: ", accountRegistry.usdc());        
    }

    function testChangeImmersve() public {
        console.log("Gov is: ", accountRegistry.gov());        
        console.log("Immersve before: ", accountRegistry.immersve());        
        vm.prank(rando);
        vm.expectRevert(bytes("!Gov"));
        accountRegistry.setImmersve(random_address_1);
        vm.prank(gov);
        accountRegistry.setImmersve(random_address_2);
        assertEq(accountRegistry.immersve(), random_address_2);
        console.log("Immersve after: ", accountRegistry.immersve());  
    }

    function testAddToken() public {
        vm.prank(rando);
        vm.expectRevert(bytes("!Gov"));
        accountRegistry.addToken(random_address_1);
        vm.prank(gov);
        accountRegistry.addToken(random_address_1);
        vm.prank(gov);
        // Can only add the token once
        vm.expectRevert("!AlreadySupported");
        accountRegistry.addToken(random_address_1);

        assert(accountRegistry.supportedTokens(random_address_1));

    }

    function testRemoveToken() public {
        vm.prank(rando);
        vm.expectRevert(bytes("!Gov"));
        accountRegistry.removeToken(random_address_1);
        
        vm.startPrank(gov);

        vm.expectRevert("!NotSupported");
        accountRegistry.removeToken(random_address_1);
        
        //Removing a token is ok if there are no vaults
        accountRegistry.addToken(random_address_1);
        assert(accountRegistry.supportedTokens(random_address_1));
        accountRegistry.removeToken(random_address_1);
        assert(!accountRegistry.supportedTokens(random_address_1));

        accountRegistry.addToken(random_address_1);

        //Add a vault, you can't remove the token
        accountRegistry.addVault(random_address_1, address(vaults[0]));

        vm.expectRevert("!StillActiveVaults");
        accountRegistry.removeToken(random_address_1);

        accountRegistry.retireVault(random_address_1, address(vaults[0]));
        accountRegistry.removeToken(random_address_1);
    }

    function testAddVault() public {
        vm.prank(rando);
        vm.expectRevert(bytes("!Gov"));
        accountRegistry.addVault(random_address_1, address(vaults[0]));
        vm.startPrank(gov);

        //Token should be supported first
        vm.expectRevert("!Supported");
        accountRegistry.addVault(random_address_1, address(vaults[0]));
        
        accountRegistry.addToken(random_address_1);
        accountRegistry.addToken(random_address_2);

        //VaultAPI wrong token
        vm.expectRevert("!WrongToken");
        accountRegistry.addVault(random_address_2, address(vaults[0]));

        accountRegistry.addVault(random_address_1, address(vaults[0]));
        assertEq(accountRegistry.getVaultsLength(random_address_1), 1);

        //Adding the same vaut twice fails
        vm.expectRevert("!AlreadyAdded");
        accountRegistry.addVault(random_address_1, address(vaults[0]));

        //Retire the vault, check that still i can't add it
        accountRegistry.retireVault(random_address_1, address(vaults[0]));
        assertEq(accountRegistry.getVaultsLength(random_address_1), 0);
        assertEq(accountRegistry.getLegacyVaultsLength(random_address_1), 1);

        vm.expectRevert("!AlreadyAdded");
        accountRegistry.addVault(random_address_1, address(vaults[0]));
    }

    function testRetireVault() public {
        vm.prank(rando);
        vm.expectRevert(bytes("!Gov"));
        accountRegistry.retireVault(random_address_1, address(vaults[0]));
        vm.startPrank(gov);

        //Token should be supported first
        vm.expectRevert("!Supported");
        accountRegistry.retireVault(random_address_1, address(vaults[0]));
        
        accountRegistry.addToken(random_address_1);
        accountRegistry.addToken(random_address_2);


        accountRegistry.addVault(random_address_1, address(vaults[0]));
        assertEq(accountRegistry.getVaultsLength(random_address_1), 1);

        //VaultAPI wrong token
        vm.expectRevert("!WrongToken");
        accountRegistry.retireVault(random_address_2, address(vaults[0]));

        //Retire the vault
        accountRegistry.retireVault(random_address_1, address(vaults[0]));

        assertEq(accountRegistry.getVaultsLength(random_address_1), 0);
        assertEq(accountRegistry.getLegacyVaultsLength(random_address_1), 1);

        //Retiring the same vaut twice fails
        vm.expectRevert("!AlreadyRetired");
        accountRegistry.retireVault(random_address_1, address(vaults[0]));

        //Cannot retire a vault that is not active
        vm.expectRevert("!NotPresent");
        accountRegistry.retireVault(random_address_1, address(vaults[1]));
    }

    function testReactivateVault() public {
        vm.prank(rando);
        vm.expectRevert(bytes("!Gov"));
        accountRegistry.reactivateVault(random_address_1, address(vaults[0]));
        vm.startPrank(gov);

        //Token should be supported first
        vm.expectRevert("!Supported");
        accountRegistry.reactivateVault(random_address_1, address(vaults[0]));
        
        accountRegistry.addToken(random_address_1);
        accountRegistry.addToken(random_address_2);


        accountRegistry.addVault(random_address_1, address(vaults[0]));

        // A vault that is already active 
        vm.expectRevert("!StillActive");
        accountRegistry.reactivateVault(random_address_1, address(vaults[0]));

        accountRegistry.retireVault(random_address_1, address(vaults[0]));
        assertEq(accountRegistry.getLegacyVaultsLength(random_address_1), 1);
        assertEq(accountRegistry.getVaultsLength(random_address_1), 0);

        //VaultAPI wrong token
        vm.expectRevert("!WrongToken");
        accountRegistry.reactivateVault(random_address_2, address(vaults[0]));

        accountRegistry.reactivateVault(random_address_1, address(vaults[0]));
        assertEq(accountRegistry.getLegacyVaultsLength(random_address_1), 0);
        assertEq(accountRegistry.getVaultsLength(random_address_1), 1);

        //Cannot retire a vault that is not in the legacy
        vm.expectRevert("!NotPresent");
        accountRegistry.retireVault(random_address_1, address(vaults[1]));
    }



}
