// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IAuction {
    struct AuctionLot {
        address tokenContract;
        uint256 tokenId;
        address auctionCreator;
        uint256 amount;
        address paymentToken;
        uint256 buyNowPrice;
        uint256 startPrice;
        uint256 startTime;
        uint256 endTime;
        uint256 delta;
        address lastBidder;
        uint256 lastBid;
    }

    event AddAuctionLot(
        uint256 indexed auctionId,
        address indexed auctionCreator,
        address indexed tokenContract,
        uint256 tokenId,
        uint256 quantity,
        address paymentToken,
        uint256 buyNowPrice,
        uint256 startPrice,
        uint256 startTime,
        uint256 endTime,
        uint256 delta
    );

    event EditAuctionLot(
        uint256 indexed auctionId,
        uint256 buyNowPrice,
        uint256 startPrice,
        uint256 startTime,
        uint256 endTime,
        uint256 delta
    );

    event ExtendAuction(uint256 indexed auctionId, uint256 endTime);

    event DeleteAuctionLot(uint256 indexed auctionId, address indexed auctionCreator);

    event ClaimAuctionLot(uint256 indexed auctionId, address indexed auctionCreator);

    event AddBid(uint256 indexed auctionId, address indexed bidder, uint256 bid);
    event AddedPendingPayment(uint256 indexed auctionId, address indexed bidder, uint256 bid);
    event PayoutPendingPayments(uint256 auctionId, address from, address to);

    event NewFee(uint256 newFee);

    function lastId() external view returns (uint256 id);

    function getAuctionInfo(uint256 auctionId) external view returns (AuctionLot memory);

    function addBid(uint256 auctionId, uint256 amount) external payable;

    function extendActionLifeTime(uint256 auctionId, uint256 additionalTime) external;

    function addAuctionLot(
        address tokenContract,
        uint256 tokenId,
        uint256 amount,
        address paymentToken,
        uint256 buyNowPrice,
        uint256 startPrice,
        uint256 startTime,
        uint256 endTime,
        uint256 minDelta
    ) external returns (uint256 id);

    function editAuctionLot(
        uint256 auctionId,
        uint256 buyNowPrice,
        uint256 startPrice,
        uint256 startTime,
        uint256 endTime,
        uint256 delta
    ) external;

    function getCreator(uint256 auctionId) external returns (address);

    function delAuctionLot(uint256 auctionId) external;
}
