// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.18;

/**
 *  @title IImmersvePaymentProtocol
 *  @dev Interface for the Immersve Payment Protocol contract.
*/
interface IImmersvePaymentProtocol {
    function deposit(uint256 tokenAmount) external;
    function depositTo(uint256 tokenAmount, address sender) external;
    function withdraw(uint256 tokenAmount) external;
    function withdrawTo(uint256 tokenAmount, address sender) external;
    function lockFunds(uint256 timeout, uint256 price) external returns (uint256);
    function lockFundsWithDeposit(uint256 timeout, uint256 price) external returns (uint256);
    function revokeLockedFunds(uint256 lockedFundId) external;
    function confirmLockedFundsPayment(uint256 lockedFundId, bytes calldata signature) external;
    function setTimeoutBlocks(uint32 timeoutBlocks) external;
    function setSafetyBlocks(uint16 _safetyBlocks) external;
    function balances(address account) external view returns (uint256);
    function getBalance() external view returns(uint256);
    function lockedFunds(address account, uint256 index) external view returns (uint256, uint256, uint256);
    function lockedFundsLength(address account) external view returns (uint256);
    function defaultTimeoutBlocks() external view returns (uint32);
    function safetyBlocks() external view returns (uint16);
    function tokenSmartContractAddress() external view returns (address);
    function settlerAddress() external view returns (address);
    function createLockedFund(uint256 tokenAmont) external;
    function getLockedFunds() external view returns (uint256);
}

