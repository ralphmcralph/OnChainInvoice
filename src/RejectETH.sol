// SPDX-License-Identifier: LGPL-3.0-only

pragma solidity 0.8.24;

contract RejectETH {
    receive() external payable {
        revert("I don't want your ETH");
    }
}
