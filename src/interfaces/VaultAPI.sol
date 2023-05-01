// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.18;

/**
 *  @title VaultAPI
 *  @notice Interface for interacting with a Vault contract to deposit and withdraw funds
*/
interface VaultAPI {
    function deposit(uint256 amount) external returns (uint256);

    function withdraw(uint256 maxShares) external returns (uint256);

    function token() external view returns (address);

    function pricePerShare() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

	function decimals() external view returns (uint256);
}

