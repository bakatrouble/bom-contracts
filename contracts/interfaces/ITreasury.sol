// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.14;

interface ITreasury {
    function isAdmin(address who) external returns (bool);
    function isOperator(address who) external returns (bool);
}