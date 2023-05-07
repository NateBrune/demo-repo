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
    address bofRouter = 0x3c4d6c6ae4d219665E9E277Ba37B67A79881A865;

    function setUp() public override {
      uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
      rando = createUsers(1)[0];
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
          bofRouter //todo: this is BoF router on polygon but it need to be deployed on sepolia?
        )
      )));
    }

    function testSetGovernance(address _newGov) public {
        assertEq(gov, address(zap.gov()));
        vm.assume(_newGov != proxyAdmin);
        //Must be called by owner
        vm.prank(_newGov);
        vm.expectRevert();
        zap.setGovernance(newGov);
        vm.prank(gov);
        zap.setGovernance(_newGov);
        vm.prank(_newGov);
        zap.acceptGovernance();
        assertEq(_newGov, zap.gov());
    }

    function testSetCCIPRouter(address _router) public {
        assertEq(ccipRouterSepolia, address(zap.i_router()));
        vm.prank(gov);
        zap.setCCIPRouter(_router);
        assertEq(address(zap.i_router()), _router);
    }

    function testSetBofRouter(address _router) public {
        assertEq(bofRouter, address(zap.bofRouter()));
        vm.prank(gov);
        zap.setBofRouter(_router);
        assertEq(address(zap.bofRouter()), _router);
    }

    function testSendDataAndTokens(bytes memory _dummyBytes) public {
      //vm.assume(_amounts.length > 0);
      vm.prank(gov);
      Client.EVMExtraArgsV1 memory extraArgs = Client.EVMExtraArgsV1(1000000, false);
      zap.enableChain(uint64(421613), Client._argsToBytes(extraArgs));
      vm.prank(rando);
      Client.EVMTokenAmount[] memory amounts = new Client.EVMTokenAmount[](1);
      amounts[0] = (Client.EVMTokenAmount(address(1), uint256(1000)));
      bytes memory dummyBytes = "hi";
      zap.sendDataAndTokens(uint64(421613), _dummyBytes, _dummyBytes, amounts);
    }

    function testEnableAndDisableChain(uint64 _chainId, Client.EVMExtraArgsV1 memory _extraArgs) public {
        vm.prank(gov);
        zap.enableChain(_chainId, Client._argsToBytes(_extraArgs));
        assertEq(zap.s_chains(_chainId), Client._argsToBytes(_extraArgs));
    }
}
