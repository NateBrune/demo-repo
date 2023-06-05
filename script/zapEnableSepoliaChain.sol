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
import "../src/libraries/Client.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";


contract zapEnableChainScript is CREATE3Script{
  constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() external {
      uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

      vm.startBroadcast(deployerPrivateKey);
      //DecoyRouter _decoy = DecoyRouter(address(0x1fe0d4c77bf322b7726d37b2f84fb51c470f7514));
      ChainZapTUP zap = ChainZapTUP(address(0x89Eccc61B2d35eACCe08284CF22c2D6487B80A3A));

      Client.EVMExtraArgsV1 memory extraArgs = Client.EVMExtraArgsV1(4000000, false);
      zap.enableChain(uint64(11155111), Client._argsToBytes(extraArgs));
      vm.stopBroadcast();
    }
}