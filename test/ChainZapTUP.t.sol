// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "./BaseSetup.t.sol";
import "../src/BofRouterFactory.sol";
import "../src/AccountRegistry.sol";
import "../src/RouterProxyAdmin.sol";
import "../src/ChainZapTUP.sol";
import "../src/libraries/Client.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";

contract ZapTest is BaseSetup {    
    ChainZapTUP zap = ChainZapTUP(address(0));
    address ccipRouterSepolia = (0x0A36795B3006f50088c11ea45b960A1b0406f03b);
    address chainlinkSepolia = (0x779877A7B0D9E8603169DdbD7836e478b4624789);
    address proxyAdmin = 0x150a0ee7393294442EE4d4F5C7d637af01dF93ee;

    function setUp() public override {
      uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
      gov = (0x74DE73F2C586ba6Ed7B154c5460A7Ef42e8194cE);
      //vm.startBroadcast(deployerPrivateKey);
      ChainZapTUP _zap = new ChainZapTUP();
      zap = ChainZapTUP(address(new TransparentUpgradeableProxy(
        address(_zap), 
        proxyAdmin, 
        abi.encodeWithSelector(
          ChainZapTUP.initialize.selector, 
          proxyAdmin,
          ccipRouterSepolia,
          chainlinkSepolia,
          gov,
          address(0)
        )
      )));
    }

    function testSetGovernance() public {
        assertEq(gov, address(zap.gov()));
        newGov = createUsers(1)[0];

        //Must be called by owner
        vm.prank(newGov);
        vm.expectRevert();
        zap.setGovernance(newGov);
        vm.prank(gov);
        zap.setGovernance(newGov);
        vm.prank(newGov);
        zap.acceptGovernance();
        assertEq(newGov, zap.gov());
    }

    function testSetCCIPRouter() public {
        address rando = createUsers(1)[0];
        assertEq(ccipRouterSepolia, address(zap.i_router()));
        vm.prank(gov);
        zap.setCCIPRouter(address(rando));
        assertEq(rando, address(zap.i_router()));
    }

    function testSetBofRouter() public {
        address rando = createUsers(1)[0];
        assertEq(ccipRouterSepolia, address(zap.bofRouter()));
        vm.prank(gov);
        zap.setBofRouter(address(rando));
        assertEq(rando, address(zap.bofRouter()));
    }

    // bytes4 public constant EVM_EXTRA_ARGS_V1_TAG = 0x97a657c9;
    // struct EVMExtraArgsV1 {
    //   uint256 gasLimit; // ATTENTION!!! MAX GAS LIMIT 4M FOR ALPHA TESTING
    //   bool strict; // See strict sequencing details below. 
    // }
    function testEnableAndDisableChain() public {
        uint64 chainId = 10101;

        Client.EVMExtraArgsV1 memory extraArgs = Client.EVMExtraArgsV1(1000000, false);
        vm.prank(gov);
        zap.enableChain(chainId, Client._argsToBytes(extraArgs));
        assertEq(rando, address(zap.bofRouter()));
    }
}
