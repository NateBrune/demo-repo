// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

interface IRouter {
    function owner() external view returns (address);
}

interface ITransparentUpgradeableProxy {
  function admin (  ) external returns ( address admin_ );
  function changeAdmin ( address newAdmin ) external;
  function implementation (  ) external returns ( address implementation_ );
  function upgradeTo ( address newImplementation ) external payable;
  function upgradeToAndCall ( address newImplementation, bytes calldata data ) external payable;
}


// Get around the fallback issue with the proxy. This causes a brick risk. All routers MUST have an owner function
contract OwnerCallProxy {
	function owner(address router) external view returns (address) {
		return IRouter(router).owner();
	}
}

/**
 * @dev This is an auxiliary contract meant to be assigned as the admin of a {TransparentUpgradeableProxy}. For an
 * explanation of why you would want to use this see the documentation for {TransparentUpgradeableProxy}.
 */
contract RouterProxyAdmin {
	OwnerCallProxy public ownerCallProxy;
	constructor(OwnerCallProxy _ownerCallProxy) {
		ownerCallProxy = _ownerCallProxy;
	}
    /**
     * @dev Throws if called by any account other than the owner.
     */
    function _onlyOwner(address router) internal view {
        require(ownerCallProxy.owner(router) == msg.sender, "RouterProxyAdmin: caller is not the owner");
    }

    /**
     * @dev Returns the current implementation of `proxy`.
     *
     * Requirements:
     *
     * - This contract must be the admin of `proxy`.
     */
    function getProxyImplementation(address proxy) public view virtual returns (address) {
        // We need to manually run the static call since the getter cannot be flagged as view
        // bytes4(keccak256("implementation()")) == 0x5c60da1b
        (bool success, bytes memory returndata) = address(proxy).staticcall(hex"5c60da1b");
        require(success);
        return abi.decode(returndata, (address));
    }

    /**
     * @dev Returns the current admin of `proxy`.
     *
     * Requirements:
     *
     * - This contract must be the admin of `proxy`.
     */
    function getProxyAdmin(address proxy) public view virtual returns (address) {
        // We need to manually run the static call since the getter cannot be flagged as view
        // bytes4(keccak256("admin()")) == 0xf851a440
        (bool success, bytes memory returndata) = address(proxy).staticcall(hex"f851a440");
        require(success);
        return abi.decode(returndata, (address));
    }

    /**
     * @dev Changes the admin of `proxy` to `newAdmin`.
     *
     * Requirements:
     *
     * - This contract must be the current admin of `proxy`.
     */
    function changeProxyAdmin(address proxy, address newAdmin) public virtual {
		_onlyOwner(proxy);
        ITransparentUpgradeableProxy(proxy).changeAdmin(newAdmin);
    }

    /**
     * @dev Upgrades `proxy` to `implementation`. See {TransparentUpgradeableProxy-upgradeTo}.
     *
     * Requirements:
     *
     * - This contract must be the admin of `proxy`.
     */
    function upgrade(address proxy, address implementation) public virtual {
		_onlyOwner(proxy);
        ITransparentUpgradeableProxy(proxy).upgradeTo(implementation);
    }

    /**
     * @dev Upgrades `proxy` to `implementation` and calls a function on the new implementation. See
     * {TransparentUpgradeableProxy-upgradeToAndCall}.
     *
     * Requirements:
     *
     * - This contract must be the admin of `proxy`.
     */
    function upgradeAndCall(address proxy, address implementation, bytes memory data) public payable virtual {
		_onlyOwner(proxy);
        ITransparentUpgradeableProxy(proxy).upgradeToAndCall{value: msg.value}(implementation, data);
    }
}
