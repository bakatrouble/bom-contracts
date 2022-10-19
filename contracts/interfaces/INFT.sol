// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.14;

interface INFT {
    struct TokenInfo {
        string image;
        address[] tokens;
        uint256 rate;
        uint256 attack;
        uint256 defense;
        uint256 health;
        uint256 critChance;
        uint256 critDmg;
        uint256 recover;
    }

    function raiseRewardPool(uint256 amount) external;
}
