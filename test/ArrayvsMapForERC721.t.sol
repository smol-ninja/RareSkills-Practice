// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import { Test } from "forge-std/Test.sol";

contract ArrayvsMapForERC721 {
    mapping(address owner => mapping(uint256 index => uint256)) public ownedTokensMap;
    mapping(uint256 tokenId => uint256) public ownedTokensIndexForMap;
    mapping(address owner => uint256) public balancesForMap;

    mapping(address owner => uint256[]) public ownedTokensArray;
    mapping(uint256 tokenId => uint256) public ownedTokensIndexForArray;
    mapping(address owner => uint256) public balancesForArray;

    /*//////////////////////////////////////////////////////////////////////////
                        Read, Add, Remove functions for map
    //////////////////////////////////////////////////////////////////////////*/

    function readMap(address owner, uint256 index) public view returns (uint256) {
        require(index < balancesForMap[owner], "ERC721OutOfBoundsIndex");
        return ownedTokensMap[owner][index];
    }

    function addTokenToMap(address to, uint256 tokenId) public {
        uint256 length = balancesForMap[to]++;
        ownedTokensMap[to][length] = tokenId;
        ownedTokensIndexForMap[tokenId] = length;
    }

    function removeTokenFromMap(address from, uint256 tokenId) public {
        uint256 lastTokenIndex = --balancesForMap[from];
        uint256 tokenIndex = ownedTokensIndexForMap[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = ownedTokensMap[from][lastTokenIndex];
            ownedTokensMap[from][tokenIndex] = lastTokenId;
            ownedTokensIndexForMap[lastTokenId] = tokenIndex;
        }
        delete ownedTokensIndexForMap[tokenId];
        delete ownedTokensMap[from][lastTokenIndex];
    }

    /*//////////////////////////////////////////////////////////////////////////
                        Read, Add, Remove functions for Array
    //////////////////////////////////////////////////////////////////////////*/

    function readArray(address owner, uint256 index) public view returns (uint256) {
        // this will throw OurofBoundIndex error on its own
        return ownedTokensArray[owner][index];
    }

    function addTokenToArray(address to, uint256 tokenId) public {
        uint256 length = balancesForArray[to]++;
        ownedTokensArray[to].push(tokenId);
        ownedTokensIndexForArray[tokenId] = length;
    }

    function removeTokenFromArray(address from, uint256 tokenId) public {
        uint256 lastTokenIndex = --balancesForArray[from];
        uint256 tokenIndex = ownedTokensIndexForArray[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = ownedTokensArray[from][lastTokenIndex];
            ownedTokensArray[from][tokenIndex] = lastTokenId;
            ownedTokensIndexForArray[lastTokenId] = tokenIndex;
        }
        delete ownedTokensIndexForArray[tokenId];

        // pop calls delete on removed element
        ownedTokensArray[from].pop();
    }
}

contract ArrayvsMapForERC721Test is Test {
    ArrayvsMapForERC721 private c = new ArrayvsMapForERC721();
    address private testUser = address(0x1234);

    function setUp() public {
        for (uint256 i; i < 10_000; i++) {
            c.addTokenToMap(testUser, i);
            c.addTokenToArray(testUser, i);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Test for ReadMap
    //////////////////////////////////////////////////////////////////////////*/

    function test_ReadMap(uint256 index_) public view {
        vm.assume(index_ < c.balancesForMap(testUser));
        c.readMap(testUser, index_);
    }

    function test_ReadArray(uint256 index_) public view {
        vm.assume(index_ < c.balancesForArray(testUser));
        c.readArray(testUser, index_);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Test for Add token
    //////////////////////////////////////////////////////////////////////////*/

    function test_AddTokenToMap(uint256 tokenId_) public {
        uint256 prevBalance = c.balancesForMap(testUser);
        c.addTokenToMap(testUser, tokenId_);

        assertEq(c.balancesForMap(testUser), prevBalance + 1);
        assertEq(c.ownedTokensIndexForMap(tokenId_), prevBalance);
        assertEq(c.ownedTokensMap(testUser, prevBalance), tokenId_);
    }

    function test_AddTokenToArray(uint256 tokenId_) public {
        uint256 prevBalance = c.balancesForArray(testUser);
        c.addTokenToArray(testUser, tokenId_);

        assertEq(c.balancesForArray(testUser), prevBalance + 1);
        assertEq(c.ownedTokensIndexForArray(tokenId_), prevBalance);
        assertEq(c.ownedTokensArray(testUser, prevBalance), tokenId_);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Test for Remove token
    //////////////////////////////////////////////////////////////////////////*/

    function test_RemoveTokenFromMap(uint256 tokenId_) public {
        vm.assume(tokenId_ < 10_000);

        uint256 lastTokenIndex = c.balancesForMap(testUser) - 1;
        uint256 lastTokenId = c.ownedTokensMap(testUser, lastTokenIndex);
        uint256 tokenIndex = c.ownedTokensIndexForMap(tokenId_);
        c.removeTokenFromMap(testUser, tokenId_);

        assertEq(c.balancesForMap(testUser), lastTokenIndex);

        if (tokenIndex != lastTokenIndex) {
            assertEq(c.ownedTokensIndexForMap(lastTokenId), tokenIndex);
            assertEq(c.ownedTokensMap(testUser, tokenIndex), lastTokenId);
        }
    }

    function test_RemoveTokenFromArray(uint256 tokenId_) public {
        vm.assume(tokenId_ < 10_000);

        uint256 lastTokenIndex = c.balancesForArray(testUser) - 1;
        uint256 lastTokenId = c.ownedTokensArray(testUser, lastTokenIndex);
        uint256 tokenIndex = c.ownedTokensIndexForArray(tokenId_);
        c.removeTokenFromArray(testUser, tokenId_);

        assertEq(c.balancesForArray(testUser), lastTokenIndex);

        if (tokenIndex != lastTokenIndex) {
            assertEq(c.ownedTokensIndexForArray(lastTokenId), tokenIndex);
            assertEq(c.ownedTokensArray(testUser, tokenIndex), lastTokenId);
        }
    }
}
