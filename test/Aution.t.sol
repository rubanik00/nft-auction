// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {Auction} from "../src/Auction.sol";
import {AuctionErrorLib} from "../src/utils/AuctionErrorLib.sol";
import {TestToken721} from "../src/mock/erc721/TestERC721.sol";
import {TestERC721WithoutRoyalties} from "../src/mock/erc721/TestERC721WithoutRoyalties.sol";
import {WithoutFallback} from "../src/mock/WithoutFallback.sol";
import {TestToken20} from "../src/mock/erc20/TestERC20.sol";
import {TestToken1155} from "../src/mock/erc1155/TestERC1155.sol";

contract TestAuction is Test {
    address proxy;
    Auction auction;
    TestToken721 token721;
    TestERC721WithoutRoyalties token721WithoutRoyalties;
    TestToken1155 token1155;
    TestToken20 token20;
    WithoutFallback withoutFallback;
    address owner;
    address alice;
    address bob;
    uint96 constant TEN_PERCENT = 1000;

    function setUp() public {
        owner = vm.addr(1);
        alice = vm.addr(2);
        bob = vm.addr(3);

        vm.startPrank(owner);
        proxy = Upgrades.deployUUPSProxy("Auction.sol", abi.encodeWithSignature("initialize()"));
        auction = Auction(proxy);

        token721 = new TestToken721(TEN_PERCENT);
        token721WithoutRoyalties = new TestERC721WithoutRoyalties();
        token1155 = new TestToken1155("https://test.com/", TEN_PERCENT);
        token20 = new TestToken20(100 ether);
        withoutFallback = new WithoutFallback(address(auction));
        vm.stopPrank();
    }

    // Whitelist
    function test_CannotAddToWhitelistIfNotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(AuctionErrorLib.NotOwner.selector, address(alice)));
        vm.prank(alice);
        auction.addPaymentToken(address(token20));
    }

    function test_CanAddToWhitelist() public {
        vm.prank(owner);
        auction.addPaymentToken(address(token20));
    }
}
