// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.18;

/**
 *  @title VaultAPI
 *  @notice Interface for interacting with a Vault contract to deposit and withdraw funds
*/
interface IBofRouter {
    function deposit(address _token, address _vault, uint256 _amount) external;

    function withdraw(address _token, address _vault, uint256 _amount ) external;
}

