// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.14;

import "./INFT.sol";

interface INFTMetadata {
    function tokenURI(uint256 tokenId, INFT.TokenInfo memory token) external view returns (string memory);
}
