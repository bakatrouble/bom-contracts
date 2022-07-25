// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.14;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

abstract contract RoleControl is AccessControlUpgradeable {

    bytes32 OPERATOR_ROLE = bytes32("OPERATOR_ROLE");

    function isAdmin(address account) public view returns(bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account);
    }

    modifier onlyAdmin() {
        require(isAdmin(msg.sender));
        _;
    }

    function grantOperator(address account) public onlyAdmin {
        grantRole(OPERATOR_ROLE, account);
    }

    function isOperator(address account) public view returns(bool) {
        return hasRole(OPERATOR_ROLE, account);
    }

    modifier onlyOperator() {
        require(isAdmin(msg.sender));
        _;
    }

    function grantAdminRole(address account) public onlyAdmin {
        grantRole(DEFAULT_ADMIN_ROLE, account);
    }


}

