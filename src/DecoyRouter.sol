// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract DecoyRouter {
    event Deposit(address _token, address _vault, uint256 _amount);
    event Withdraw(address _token, address _vault, uint256 _amount);

    function deposit(address _token, address _vault, uint256 _amount) public {
        IERC20 token = IERC20(_token);
        token.transferFrom(msg.sender, address(this), _amount);
        emit Deposit(_token, _vault, _amount);
    }

    function withdraw(address _token, address _vault, uint256 _amount ) public {
        IERC20 token = IERC20(_token);
        token.transfer(msg.sender, _amount);
        emit Withdraw(_token, _vault, _amount);
    }
}