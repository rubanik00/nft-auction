// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {Auction} from "../src/Auction.sol";
import {TestToken721} from "../src/mock/erc721/TestERC721.sol";
import {TestERC721WithoutRoyalties} from "../src/mock/erc721/TestERC721WithoutRoyalties.sol";
import {WithoutFallback} from "../src/mock/WithoutFallback.sol";
import {TestToken20} from "../src/mock/erc20/TestERC20.sol";
import {TestToken1155} from "../src/mock/erc1155/TestERC1155.sol";

contract TestPointsHook is Test {
    Auction auction;
    TestToken721 token721;
    TestERC721WithoutRoyalties token721WithoutRoyalties;
    TestToken1155 token1155;
    TestToken20 token20;
    WithoutFallback withoutFallback;
    uint96 public constant TEN_PERCENT = 1000;

    function setUp() public {
        // Deploy our tokens
        token721 = new TestToken721(TEN_PERCENT);
        token721WithoutRoyalties = new TestERC721WithoutRoyalties();
        token1155 = new TestToken1155("https://test.com/", TEN_PERCENT);
    }
}
