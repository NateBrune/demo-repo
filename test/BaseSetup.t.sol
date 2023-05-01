// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

contract BaseSetup is Test {
    address payable[] public users;

    address public gov;
    address public rando;
    address public newGov;
    address public user;
    
    bytes32 internal nextUser = keccak256(abi.encodePacked("user address"));

    function getNextUserAddress() external returns (address payable) {
        //bytes32 to address conversion
        address payable current = payable(address(uint160(uint256(nextUser))));
        nextUser = keccak256(abi.encodePacked(nextUser));
        return current;
    }

    //create users with 100 ether balance
    function createUsers(uint256 userNum)
        internal
        returns (address payable[] memory)
    {
        address payable[] memory u = new address payable[](userNum);
        for (uint256 i = 0; i < userNum; i++) {
            address payable current = this.getNextUserAddress();
            vm.deal(current, 100 ether);
            u[i] = current;
        }
        return u;
    }

    function setUp() public virtual {
        users = createUsers(5);
        gov = users[0];
        vm.label(gov, "gov");
        rando = users[1];
        vm.label(rando, "rando");
        newGov = users[2];
        vm.label(newGov, "newGov");
        user = users[3];
        vm.label(user, "user");

    }

    
}