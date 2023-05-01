// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.18;

import "./interfaces/VaultAPI.sol";

/**
 *   @title AccountRegistry
 *  @dev A smart contract for managing supported tokens and their associated vaults.
 *  The contract is owned by a governance address that can add, retire or reactivate associated vaults. 
 *  Vault status is tracked in two mappings, vaults and legacyVaults. Vaults added to the contract are stored in `vaults` while
 *  retired or inactive vaults are moved to `legacyVaults`. 
 *  The contract has a set of access control modifiers, such as onlyGov and onlyPendingGov, which restrict access to certain functions.
*/
contract AccountRegistry {
    //--- public variables ---//

    address public gov; //the current governance address
    address public pendingGov; //the proposed governance address
    mapping(address => bool) public supportedTokens; //mapping of supported tokens
    mapping(address => address[]) public vaults; //map asset address to list of active vaults
    mapping(address => address[]) public legacyVaults; //map asset address to list of legacy vaults
    address public immersve; //the address of the Immersve contract
    address public usdc; //the address of the USDC contract

    //--- events ---//

    event ImmersveUpdated(address indexed immersve);
    event UsdcUpdated(address indexed usdc);
    event GovernanceUpdated(address indexed newGov, address indexed oldGov);
    event VaultAdded(address indexed token, address indexed vault);
    event VaultRetired(address indexed token, address indexed vault);
    event VaultReactivated(address indexed token, address indexed vault);

    //--- modifiers ---//

    modifier onlyGov() {
        require(msg.sender == gov, "!Gov");
        _;
    }

    modifier onlyPendingGov() {
        require(msg.sender == pendingGov, "!PendingGov");
        _;
    }

    //--- constructor ---//

    /**
     * @dev Initializes the contract with the address of the USDC contract and sets the governance address to the deployer address.
     * @param _usdc The address of the USDC contract.
     * @param _immersve The address of the immersve contract.
     */
    constructor(address _usdc, address _immersve) {
        gov = msg.sender;
        usdc = _usdc;
        immersve = _immersve;
    }

    //--- governance functions ---//

    /**
     * @dev Allows the governance address to set the pending governance address.
     * @param _newGov The proposed new governance address.
     */
    function setGovernance(address _newGov) external onlyGov {
        pendingGov = _newGov;
    }

    /**
     * @dev Allows the pending governance address to accept the governance role.
     */
    function acceptGovernance() external onlyPendingGov {
        emit GovernanceUpdated(pendingGov, gov);
        gov = pendingGov;
        pendingGov = address(0);
    }

    //--- setter functions ---//

    /**
     * @dev Allows the governance address to set the Immersve contract address.
     * @param _immersve The address of the Immersve contract.
     */
    function setImmersve(address _immersve) external onlyGov {
        immersve = _immersve;
        emit ImmersveUpdated(immersve);
    }

    /**
     * @notice Sets the USDC address for the protocol.
     * @param _usdc The address of the USDC token contract.
     */
    function setUsdc(address _usdc) external onlyGov {
        usdc = _usdc;
        emit UsdcUpdated(usdc);
    }

    /**
     * @notice Adds support for a new token to the protocol.
     * @param _token The address of the token contract to add support for.
     */
    function addToken(address _token) external onlyGov {
        require(!supportedTokens[_token], "!AlreadySupported");
        supportedTokens[_token] = true;
    }

    /**
     * @notice Removes support for a token from the protocol. The token should not have any active vaults anymore
     * @param _token The address of the token contract to remove support for.
     */
    function removeToken(address _token) external onlyGov {
        require(supportedTokens[_token], "!NotSupported");
        require(vaults[_token].length == 0, "!StillActiveVaults");
        supportedTokens[_token] = false;
    }

    /**
     * @notice Adds a new vault to the protocol for a specific token.
     * @param _token The address of the token contract the vault is for.
     * @param _vault The address of the vault contract to add.
     */
    function addVault(address _token, address _vault) external onlyGov {
        require(supportedTokens[_token], "!Supported");
        require(VaultAPI(_vault).token() == _token, "!WrongToken");
        //Check that the vault is not already in vaults or in legacyVaults
        for (uint256 i = 0; i < vaults[_token].length; i++) {
            require(vaults[_token][i] != _vault, "!AlreadyAdded");
        }
        for (uint256 i = 0; i < legacyVaults[_token].length; i++) {
            require(legacyVaults[_token][i] != _vault, "!AlreadyAdded");
        }

        vaults[_token].push(_vault);
        emit VaultAdded(_token, _vault);
    }

    /**
     * @dev Retires the given vault for the specified token.
     * @param _token The address of the token to retire the vault for.
     * @param _vault The address of the vault to retire.
     * Emits a VaultRetired event on success.
     */
    function retireVault(address _token, address _vault) external onlyGov {
        require(supportedTokens[_token], "!Supported");
        require(VaultAPI(_vault).token() == _token, "!WrongToken");

        //The vault shouldn't already be retired
        for (uint256 i = 0; i < legacyVaults[_token].length; i++) {
            require(legacyVaults[_token][i] != _vault, "!AlreadyRetired");
        }
        uint256 oldLenght = vaults[_token].length;
        //Retire the vault
        for (uint256 i = 0; i < oldLenght; i++) {
            if (vaults[_token][i] == _vault) {
                vaults[_token][i] = vaults[_token][oldLenght - 1];
                vaults[_token].pop();
                legacyVaults[_token].push(_vault);
                break;
            }
        }
        require(oldLenght == vaults[_token].length + 1, "!NotPresent");
        emit VaultRetired(_token, _vault);
    }

    /**
     * @dev Reactivates the given retired vault for the specified token.
     * @param _token The address of the token to reactivate the vault for.
     * @param _vault The address of the vault to reactivate.
     * Emits a VaultReactivated event on success.
     */
    function reactivateVault(address _token, address _vault) external onlyGov {
        require(supportedTokens[_token], "!Supported");
        require(VaultAPI(_vault).token() == _token, "!WrongToken");

        //The vault shouldn't be active
        for (uint256 i = 0; i < vaults[_token].length; i++) {
            require(vaults[_token][i] != _vault, "!StillActive");
        }
        uint256 oldLenght = legacyVaults[_token].length;
        //Retire the vault
        for (uint256 i = 0; i < oldLenght; i++) {
            if (legacyVaults[_token][i] == _vault) {
                legacyVaults[_token][i] = legacyVaults[_token][oldLenght - 1];
                legacyVaults[_token].pop();
                vaults[_token].push(_vault);
                break;
            }
        }
        require(oldLenght == legacyVaults[_token].length + 1, "!NotPresent");
        emit VaultReactivated(_token, _vault);
    }

    /**
     * @dev Returns the number of active vaults for the specified token.
     * @param _token The address of the token to get the active vaults length for.
     * @return The number of active vaults for the specified token.
     */
    function getVaultsLength(address _token) external view returns (uint256) {
        return vaults[_token].length;
    }

    /**
     * @dev Returns the number of retired vaults for the specified token.
     * @param _token The address of the token to get the retired vaults length for.
     * @return The number of retired vaults for the specified token.
     */
    function getLegacyVaultsLength(address _token)
        external
        view
        returns (uint256)
    {
        return legacyVaults[_token].length;
    }

    /**
     * @dev Checks whether the given vault is supported by the protocol for the specified token.
     * @param _token The address of the token to check the vault support for.
     * @param _vault The address of the vault to check.
     * @return true if the vault is supported by the protocol for the specified token, false otherwise.
     */
    function isSupported(address _token, address _vault)
        external
        view
        returns (bool)
    {
        for (uint256 i = 0; i < vaults[_token].length; i++) {
            if (vaults[_token][i] == _vault) return true;
        }
        return false;
    }
}
