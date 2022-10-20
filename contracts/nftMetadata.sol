// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.14;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "./interfaces/INFT.sol";

contract NFTMetadata {
    address[4] public rewardTokens = [
        0x0000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000002,
        0x0000000000000000000000000000000000000003
    ];

    string[] shiba = [
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Shiba-01.png",
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Shiba-02.png",
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Shiba-03.png",
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Shiba-04.png",
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Shiba-05.png"
    ];
    string[] floki = [
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Floki-01.png",
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Floki-02.png",
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Floki-03.png",
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Floki-04.png",
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Floki-05.png"
    ];
    string[] dogy = [
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Dogy-01.png",
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Dogy-02.png",
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Dogy-03.png",
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Dogy-04.png",
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Dogy-05.png"
    ];
    string[] doge = [
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Doge-01.png",
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Doge-02.png",
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Doge-03.png",
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Doge-04.png",
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Doge-05.png"
    ];

    string[] megaMin = [
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Mega%20NFT-01.png",
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Mega%20NFT-02.png",
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Mega%20NFT-03.png",
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Mega%20NFT-01.png",
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Mega%20NFT-02.png",
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Mega%20NFT-03.png"
    ];
    string[] megaMid = [
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Mega%20NFT-04.png",
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Mega%20NFT-05.png",
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Mega%20NFT-06.png",
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Mega%20NFT-07.png"
    ];
    string megaMax =
        "ipfs://QmbF534aUPpQAuQL5C7pS53TqppZFHJ22WQRZBdypb2gqd/Mega%20NFT-10.png";

    mapping(address => mapping(uint256 => string)) simpleImage;
    mapping(address => mapping(address => string)) minImage;
    mapping(address => mapping(address => mapping(address => string))) midImage;

    constructor() {
        _fillImageMappings();
    }

    function tokenURI(uint256 tokenId, INFT.TokenInfo calldata token)
        external
        view
        returns (string memory)
    {
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
                                _getImage(token),
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

    function _getImage(INFT.TokenInfo calldata token)
        internal
        view
        returns (string memory)
    {
        if (token.tokens.length == 1) {
            return simpleImage[token.tokens[0]][token.rate];
        } else if (token.tokens.length < 4) {
            return _getImageIpfs(token.tokens);
        } else {
            return megaMax;
        }
    }

    function _getImageIpfs(address[] memory tokens)
        internal
        view
        returns (string memory)
    {
        uint256[] memory indexes = new uint256[](3);
        for (uint256 i = 0; i < tokens.length; i++) {
            for (uint256 ind = 0; ind < 4; ind++) {
                if (tokens[i] == rewardTokens[ind]) {
                    indexes[i] = ind;
                    break;
                }
            }
        }
        uint256[] memory sorted = quickSort(indexes, 0, 2);
        if (sorted.length == 3) {
            return
                midImage[tokens[sorted[0]]][tokens[sorted[1]]][
                    tokens[sorted[2]]
                ];
        } else {
            return minImage[tokens[sorted[0]]][tokens[sorted[1]]];
        }
    }

    function quickSort(
        uint256[] memory arr,
        uint256 left,
        uint256 right
    ) internal pure returns (uint256[] memory) {
        if (left >= right) return arr;
        uint256 p = arr[(left + right) / 2];
        uint256 i = left;
        uint256 j = right;
        while (i < j) {
            while (arr[i] < p) ++i;
            while (arr[j] > p) --j;
            if (arr[i] > arr[j]) (arr[i], arr[j]) = (arr[j], arr[i]);
            else ++i;
        }

        if (j > left) return quickSort(arr, left, j - 1);
        return quickSort(arr, j + 1, right);
    }

    function compileStatString(INFT.TokenInfo calldata token)
        internal
        pure
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
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
                    '}, { "trait_type": "rating", "value": ',
                    Strings.toString(token.rate),
                    '}, { "trait_type": "recovery", "value": ',
                    Strings.toString(token.recover),
                    "} ] }"
                )
            );
    }

    function addressArrayToString(address[] memory addressArray)
        internal
        pure
        returns (string memory)
    {
        string memory result = "[";
        for (uint256 i = 0; i < addressArray.length; i++) {
            if (i == addressArray.length - 1) {
                result = string.concat(
                    result,
                    "'0x",
                    toAsciiString(addressArray[i]),
                    "'"
                );
            } else {
                result = string.concat(
                    result,
                    "'0x",
                    toAsciiString(addressArray[i]),
                    "',"
                );
            }
        }
        result = string.concat(result, "]");
        return result;
    }

    function toAsciiString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(x)) / (2**(8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string(s);
    }

    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    function _fillImageMappings() internal {
        uint256 rate = 1000;
        for (uint256 i = 0; i < 5; i++) {
            simpleImage[rewardTokens[0]][rate] = shiba[0];
            simpleImage[rewardTokens[1]][rate] = floki[0];
            simpleImage[rewardTokens[2]][rate] = dogy[0];
            simpleImage[rewardTokens[3]][rate] = doge[0];
            rate += 250;
        }
        minImage[rewardTokens[0]][rewardTokens[1]] = megaMin[0];
        minImage[rewardTokens[0]][rewardTokens[2]] = megaMin[1];
        minImage[rewardTokens[0]][rewardTokens[3]] = megaMin[2];
        minImage[rewardTokens[1]][rewardTokens[2]] = megaMin[3];
        minImage[rewardTokens[1]][rewardTokens[3]] = megaMin[4];
        minImage[rewardTokens[2]][rewardTokens[3]] = megaMin[5];
        midImage[rewardTokens[0]][rewardTokens[1]][rewardTokens[2]] = megaMid[
            0
        ];
        midImage[rewardTokens[0]][rewardTokens[1]][rewardTokens[3]] = megaMid[
            1
        ];
        midImage[rewardTokens[0]][rewardTokens[2]][rewardTokens[3]] = megaMid[
            2
        ];
        midImage[rewardTokens[1]][rewardTokens[2]][rewardTokens[3]] = megaMid[
            3
        ];
    }
}
