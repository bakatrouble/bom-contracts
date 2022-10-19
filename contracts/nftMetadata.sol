// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.14;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "./interfaces/INFT.sol";

contract NFTMetadata {
    function tokenURI(uint256 tokenId, INFT.TokenInfo calldata token) external view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name": "Babies of Mars #',
                                Strings.toString(tokenId),
                                '", "description": "adasdasdasd", "image": "',
                                token.image,
                                '",{ "attributes": [ {"trait_type": "tokens", "value": ',
                                addressArrayToString(token.tokens),
                                '}, { "trait_type": "attack", "value": ',
                                compileStatString(token)
                            )
                        )
                    )
                )
            );
    }

    function compileStatString(INFT.TokenInfo calldata token) internal view returns (string memory) {
        return string(abi.encodePacked(
                '}, { "trait_type": "attack", "value": ',
                Strings.toString(token.attack),
                '}, { "trait_type": "defense", "value": ',
                Strings.toString(token.defense),
                '}, { "trait_type": "health", "value": ',
                Strings.toString(token.health),
                '}, { "trait_type": "critical rate", "value": ',
                Strings.toString(token.critChance),
                '}, { "trait_type": "critical damage", "value": ',
                Strings.toString(token.critDmg),
                '}, { "trait_type": "recovery", "value": ',
                Strings.toString(token.recover),
                "} ] }"
            ));
    }

    function addressArrayToString(address[] memory addressArray) internal pure returns (string memory) {
        string memory result = "[";
        for(uint256 i = 0; i < addressArray.length; i++) {
            if(i == addressArray.length-1) {
                result = string.concat(result,"'0x",toAsciiString(addressArray[i]),"'");
            } else {

                result = string.concat(result,"'0x",toAsciiString(addressArray[i]),"',");
            }
        }
        result = string.concat(result,"]");
        return result;
    }

    function toAsciiString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint(uint160(x)) / (2**(8*(19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2*i] = char(hi);
            s[2*i+1] = char(lo);
        }
        return string(s);
    }

    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10)
            return bytes1(uint8(b) + 0x30);
        else
            return bytes1(uint8(b) + 0x57);
    }
}
