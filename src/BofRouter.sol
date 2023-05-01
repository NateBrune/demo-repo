// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.18;

import "./AccountRegistry.sol";
import "./interfaces/VaultAPI.sol";
import "./interfaces/IImmersvePaymentProtocol.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

/**
 *  @title BofRouter
 *  @dev This contract manages the funds of a single user, which are spread across different vaults, including Immersve Protocol.
 *  The contract owner is the only entity that can move the funds around.
 *  This contract emits events for balance changes.
*/
contract BofRouter is Initializable, OwnableUpgradeable {
    //--- public variables ---//
    AccountRegistry public accountRegistry;
    address public pendingAccountRegistry;

    //--- events ---//
    event AccountRegistryUpdated(address indexed newAccountRegistry, address indexed oldAccountRegistry);
    event Transfer(address indexed token, address indexed from, address indexed to, uint256 amount);
    event Deposit(address indexed token, address indexed vault, uint256 amount);
    event Withdraw(address indexed token, address indexed vault, uint256 amount);
    event Sweep(address indexed token, uint256 amount);
    event NewLockImmersve(uint256 amount);

    //--- modifiers ---//

    modifier onlyGov() {
        require(msg.sender == gov(), "!Gov");
        _;
    }

    //--- constructor ---//
    /**
     * @dev Initializes the contract with the address of the owner and the accountRegistry.
     * @param _owner the address that will own this BofWallet
     * @param _accountRegistry address of the accountRegistry
     */
    function initialize(
        address _owner,
        address _accountRegistry
    ) public payable initializer {
		_transferOwnership(_owner);
        accountRegistry = AccountRegistry(_accountRegistry);
    }
	
    //--- setter functions ---//

    /**
     * @dev This function sets the address of the pending account registry.
     * @param _newAccountRegistry The address of the new account registry.
     */
    function setAccountRegistry(address _newAccountRegistry) external onlyGov {
        pendingAccountRegistry = _newAccountRegistry;
    }


    /**
     * @dev This function accepts the new account registry address and updates the current account registry address.
     */
    function acceptAccountRegistry() external onlyOwner {
        emit AccountRegistryUpdated(
            pendingAccountRegistry,
            address(accountRegistry)
        );
        accountRegistry = AccountRegistry(pendingAccountRegistry);
        pendingAccountRegistry = address(0);
    }

    //--- view functions ---//

    /**
     * @dev Returns the address of the gov of the account registry
     * @return Gov address
    */
    function gov() public view returns (address) {
        return accountRegistry.gov();
    }

    /**
     * @dev Returns the balance of the owner held in a particular vault
     * @param _vault Address of the vault 
     * @return Balance of the owner in the specified vault
    */
    function _balanceOf(address _vault) internal view returns (uint256) {
        return VaultAPI(_vault).pricePerShare() * VaultAPI(_vault).balanceOf(address(this)) / (10 ** VaultAPI(_vault).decimals());
    }

    /**
     * @dev Returns the balance of the specified token in a specified vault
     * @param _token Address of the token 
     * @param _vault Address of the vault
     * @return Balance of the owner in the vault
    */
    function balanceOf(address _token, address _vault) external view returns (uint256) {
        require(VaultAPI(_vault).token() == _token);
        return _balanceOf(_vault);
    }

    /**
     * @dev Returns the balance locked in the immersve contract
     * @notice only usdc is supported by immersve at this time
     * @return The amount locked in the immersve contract
     */
    function balanceImmersveLocked() public view returns (uint256) {
        return IImmersvePaymentProtocol(accountRegistry.immersve()).getLockedFunds();
    }

    /**
     * @dev Returns the balance free in the immersve contract
     * @notice only usdc is supported by immersve at this time
     * @return The amount free in the immersve contract
     */
    function balanceImmersveFree() public view returns (uint256) {
        return IImmersvePaymentProtocol(accountRegistry.immersve()).getBalance();
    }

    /**
     * @dev Returns the balance in this wallet 
     * @param _token the token to check
     * @return The amount of token ready to be deployed 
     */
    function balanceUnallocated(address _token) public view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    /**
     * @dev Returns the balance deployed in vaults from this wallet
     * @param _token the token to check
     * @return The amount of token deployed to active vaults
     */
    function balanceInVaults(address _token) public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < accountRegistry.getVaultsLength(_token); i++) {
            total += _balanceOf(accountRegistry.vaults(_token, i));
        }
        return total;
    }

    /**
     * @dev Returns the balance deployed in vaults that have been retired, the user should withdraw as soon as possible
     * @param _token the token to check
     * @return The amount of token deployed to legacy vaults 
     */
    function balanceInLegacyVaults(address _token) public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < accountRegistry.getLegacyVaultsLength(_token); i++) {
            total += _balanceOf(accountRegistry.legacyVaults(_token, i));
        }
        return total;
    }

    /**
     * @dev Returns the total balance of this wallet
     * @param _token the token to check
     * @return total The amount of token either unallocated, in immersve or in vaults 
     */
    function balanceOf(address _token) external view returns (uint256 total) {
        if(_token == accountRegistry.usdc()) {
            total += balanceImmersveFree();
            total += balanceImmersveLocked();
        }
        total = total + balanceUnallocated(_token) + balanceInVaults(_token) + balanceInLegacyVaults(_token);
    }

    //--- ERC 1271 ---//
    function isValidSignature(
        bytes32 _hash,
        bytes calldata _signature
    ) public view returns (bytes4 magicValue) {
        return ECDSA.recover(_hash, _signature) == owner() ? this.isValidSignature.selector : bytes4(0);
    }

    //--- write functions ---//

    /**
     * @dev Internal function to deposit tokens to a specific vault
     * @param _token Address of the token to be deposited
     * @param _vault Address of the vault to deposit tokens in
     * @param _amount Amount of tokens to be deposited
     */
    function _depositVault(address _token, address _vault, uint256 _amount) internal {
        require(accountRegistry.isSupported(_token, _vault), "!Supported");
        require(balanceUnallocated(_token) >= _amount, "!Enough");
        IERC20(_token).approve(_vault, _amount);
        VaultAPI(_vault).deposit(_amount);
    }

    /**
     * @dev Function to deposit tokens into a specific vault
     * @param _token Address of the token to be deposited
     * @param _vault Address of the vault to deposit tokens in
     * @param _amount Amount of tokens to be deposited
     */
    function deposit(address _token, address _vault, uint256 _amount) external onlyOwner {
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
		if (_vault == accountRegistry.immersve()) {
			_depositImmersve(_amount);
		} else {
        	_depositVault(_token, _vault, _amount);
		}
        emit Deposit(_token, _vault, _amount);
    }

    /**
     * @dev Internal function to withdraw tokens from a specific vault
     * @param _token Address of the token to be withdrawn
     * @param _vault Address of the vault to withdraw tokens from
     * @param _amount Amount of tokens to be withdrawn
     */
    function _withdrawVault(address _token, address _vault, uint256 _amount) internal {
        require(accountRegistry.isSupported(_token, _vault), "!Supported");
        VaultAPI(_vault).withdraw(_amount); //TODO amount is in shares, or do we want to withdraw an amount in # of tokens?
    }

    /**
     @dev Function to withdraw tokens from a specific vault
     @param _token Address of the token to be withdrawn
     @param _vault Address of the vault to withdraw tokens from
     @param _amount Amount of tokens to be withdrawn
     */     
    function withdraw(address _token, address _vault, uint256 _amount ) external onlyOwner {
		if (_vault == accountRegistry.immersve()) {
			_withdrawImmersve(_amount);
		} else {
			_withdrawVault(_token, _vault, _amount);
		}
		IERC20(_token).transfer(owner(), _amount);
        emit Withdraw(_token, _vault, _amount);
    }

    /**
     @dev Function to withdraw tokens from the router
     @param _token Address of the token to be withdrawn
     @param _amount Amount of tokens to be withdrawn
     */     
    function sweep(address _token, uint256 _amount ) external onlyOwner {
		IERC20(_token).transfer(owner(), _amount);
        emit Sweep(_token, _amount);
    }

    /**
     * @dev Internal function to deposit USDC to the Immersve protocol
     * @param _amount Amount of USDC to be deposited
     */
    function _depositImmersve(uint256 _amount) internal {
        require(balanceUnallocated(accountRegistry.usdc()) >= _amount, "!EnoughDeposit");
        IERC20(accountRegistry.usdc()).approve(accountRegistry.immersve(), _amount);
        IImmersvePaymentProtocol(accountRegistry.immersve()).deposit(_amount);
    }

    /**
     * @dev Internal function to withdraw USDC from Immersve protocol
     * @param _amount Amount of USDC to withdraw
     */
    function _withdrawImmersve(uint256 _amount) internal {
        require(balanceImmersveFree() >= _amount, "!EnoughWithdraw");
        IImmersvePaymentProtocol(accountRegistry.immersve()).withdraw(_amount);
    }

    /**
     * @dev Locks a specified amount of tokens into the Immersve contract
     * @param _amount The amount of tokens to lock
     */
    function _lockAmountImmersve(uint256 _amount) internal {
        require(IImmersvePaymentProtocol(accountRegistry.immersve()).getBalance() >= _amount, "!EnoughLock");
        IImmersvePaymentProtocol(accountRegistry.immersve()).createLockedFund(_amount);
    }

    /**
     * @dev Allows the contract owner to lock a specified amount of tokens into the Immersve contract
     * @param _amount The amount of tokens to lock
     */
    function lockAmountImmersve(uint256 _amount) external onlyOwner {
        _lockAmountImmersve(_amount);
        emit NewLockImmersve(_amount);
    }

    /**
     * @dev Allows the contract owner to transfer a token from a vault/immersve to another vault/immersve
     * @param _token The address of the token being transferred
     * @param _from The address the tokens are currently held in, this can be either a vault or immersve
     * @param _to The address the tokens must be transferred to, this can be either a vault or immersve
     * @param _amount The amount of tokens to transfer
     */
    function transfer(address _token, address _from, address _to, uint256 _amount) external onlyOwner {
        require(_from != _to, "!TransferSameAddresses");
        require(_from != address(0), "!TransferZero");
        require(_to != address(0), "!TransferZero");

        if (_from == accountRegistry.immersve()) {
            // Case 1: _from immersve to a vault
            require(_token == accountRegistry.usdc(), "!Supported");
            _withdrawImmersve(_amount);
            _depositVault(_token, _to, _amount);
        } else if (_to == accountRegistry.immersve()) {
            require(_token == accountRegistry.usdc(), "!Supported");
            // Case 2: from a vault to immersve
            _withdrawVault(_token, _from, _amount);
            _depositImmersve(_amount);
        } else {
            // Case 3: from a vault to another vault
            _withdrawVault(_token, _from, _amount);
            _depositVault(_token, _to, _amount);
        }

        emit Transfer(_token, _from, _to, _amount);
    }
}
