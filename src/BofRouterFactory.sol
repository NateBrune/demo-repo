// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.18;

import "./BofRouter.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
// Initializable
/**
 * @title BofRouterFactory
 * @dev A contract for creating and managing BOF routers/wallets.
 */
contract BofRouterFactory is Initializable {
    //--- public variables ---//
    address public gov;
    address public pendingGov;
    address public walletWhitelister; //the only account that can whitelist wallets
    address public accountRegistry;
    mapping(address => address) public wallets; //maps owner -> wallet
    mapping(address => bool) public isWhitelisted; //maps owner -> if it can create a wallet or not
    address public routerImplementation;
	address public routerProxyAdmin;
	

    //--- events ---//
    event WalletWhitelisterUpdated(address indexed walletWhitelister);
    event AccountRegistryUpdated(address indexed accountRegistry);
    event GovernanceUpdated(address indexed newGov, address indexed oldGov);
    event WalletCreated(address indexed owner, address indexed wallet);
    event WalletCreatedFor(address indexed owner, address indexed wallet);
    event WhitelistUpdated(address indexed user, bool whitelist);
	event RouterImplementationUpdated(address implmentation);
	event RouterProxyAdminUpdated(address routerProxyAdmin);

    //--- modifiers ---//
    modifier onlyGov() {
        require(msg.sender == gov, "!Gov");
        _;
    }
    modifier onlyPendingGov() {
        require(msg.sender == pendingGov, "!PendingGov");
        _;
    }
    modifier onlyWalletWhitelister() {
        require(msg.sender == walletWhitelister || msg.sender == gov, "!WalletWhitelister");
        _;
    }

    //--- constructor ---//
    /**
     * @dev Initializes the contract with the provided wallet whitelister and account registry
     * @param _walletWhitelister The address of the wallet whitelister
     * @param _accountRegistry The address of the account registry contract
     */
    function initialize(
		address _walletWhitelister,
		address _accountRegistry,
		address _routerImplementation,
		address _routerProxyAdmin
    ) public payable initializer {
        gov = msg.sender;
        walletWhitelister = _walletWhitelister;
        accountRegistry = _accountRegistry;
		routerImplementation = _routerImplementation;
		routerProxyAdmin = _routerProxyAdmin;
    }
	
    //--- setter functions ---//
    /**
     * @dev Sets the pending governance to the provided address
     * @param newGov The address of the new pending governance
     */
    function setGovernance(address newGov) external onlyGov {
        pendingGov = newGov;
    }

    /**
     * @dev Accepts the pending governance as the new governance
     */
    function acceptGovernance() external onlyPendingGov {
        emit GovernanceUpdated(pendingGov, gov);
        gov = pendingGov;
        pendingGov = address(0);
    }

    /**
     * @dev This function sets router implementation
     * @param _routerImplementation The address of the new router implementation
     */
    function setRouterImplementation(address _routerImplementation) external onlyGov {
		routerImplementation = _routerImplementation;
		emit RouterImplementationUpdated(routerImplementation);
    }


    /**
     * @dev This function sets router proxy admin
     * @param _routerProxyAdmin The address of the new router proxy admin
	 */	
	function setRouterProxyAdmin(address _routerProxyAdmin) external onlyGov {
		routerProxyAdmin = _routerProxyAdmin;
		emit RouterProxyAdminUpdated(_routerProxyAdmin);
	}

    /**
     * @dev Sets the wallet whitelister to the provided address
     * @param _walletWhitelister The address of the new wallet whitelister
     */
    function setWalletWhitelister(address _walletWhitelister) external onlyGov {
        walletWhitelister = _walletWhitelister;
        emit WalletWhitelisterUpdated(walletWhitelister);
    }

    /**
     * @dev Sets the whitelist. Gov and walletWhitelister can call this function
     * @param _user  the account to enable/disable
     * @param _isWhitelisted true if the account can create a bof router, false otherwise
     */
    function setWhitelist(address _user, bool _isWhitelisted) external onlyWalletWhitelister {
        isWhitelisted[_user] = _isWhitelisted;
        emit WhitelistUpdated(_user, _isWhitelisted);
    }

    /**
     * @dev Sets the account registry to the provided address
     * @param _accountRegistry The address of the new accountRegistry
     */
    function setAccountRegistry(address _accountRegistry) external onlyGov {
        accountRegistry = _accountRegistry;
        emit AccountRegistryUpdated(accountRegistry);
    }

    /**
     * @dev Creates a new wallet/router for the msg.sender
     */
    function createWallet() external {
		_createWalletFor(msg.sender);
    }

    /**
     * @dev Creates a new wallet/router for the msg.sender
     */
    function createWalletFor(address _user) external {
		_createWalletFor(_user);
    }

    /**
     * @dev removes a wallet for a given user
     * @param _user user to remove wallet for
     */
    function removeWallet(address _user) external onlyGov {
		wallets[_user] = address(0);
    }

    /**
     * @dev Creates a new wallet/router for user
	 * @param _user user to create wallet for
     */
    function _createWalletFor(address _user) internal {
        require(isWhitelisted[_user], "!Whitelisted");
        require(wallets[_user] == address(0), "!WalletAlreadyCreated");

		TransparentUpgradeableProxy router = new TransparentUpgradeableProxy(
			routerImplementation, 
			routerProxyAdmin, 
			abi.encodeWithSelector(BofRouter.initialize.selector, _user, accountRegistry)
		);
		
		wallets[_user] = address(router);
        emit WalletCreated(_user, address(router));
    }
}
