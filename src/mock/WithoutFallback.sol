// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../utils/IAuction.sol";

contract WithoutFallback {
    IAuction auctionAddress;

    constructor(address _auction) {
        auctionAddress = IAuction(_auction);
    }

    function callAddBid(uint256 auctionId, uint256 amount) public payable {
        require(msg.value == amount, "WithoutFallback:: msg.value != amount");
        auctionAddress.addBid{value: msg.value}(auctionId, amount);
    }
}
