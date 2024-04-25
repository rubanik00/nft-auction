// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./IAuction.sol";
import "./utils/Payout2981Support.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title Auction Contract

contract Auction is
    IAuction,
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    Payout2981Support,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    bytes32 public constant OWNER_AUCTION_ROLE = keccak256("OWNER_AUCTION_ROLE");

    uint256 public constant MAX_FEE = 1500; // 15%

    mapping(address => mapping(uint256 => uint256)) public pendingPayments; // list of users with failed transfers | pendingPayments[userAddress][auctionId] = amount
    mapping(uint256 => AuctionLot) internal _auctionLots;
    mapping(address => uint256) public collectedFees;
    mapping(address => bool) public whitelistedPaymentTokens;
    mapping(uint256 => bool) internal _extendedLots;

    uint256 public lastId;
    uint256 public fee; // Fee percent with denominator 10000
    uint256 public minDelta; // min diff between old and new bids

    /// @dev Check if caller is contract owner
    modifier onlyOwner() {
        require(hasRole(OWNER_AUCTION_ROLE, msg.sender), "Caller is not an owner");
        _;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __ReentrancyGuard_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OWNER_AUCTION_ROLE, msg.sender);
        _setRoleAdmin(OWNER_AUCTION_ROLE, OWNER_AUCTION_ROLE);
    }

    /// @notice Return creator of auction by id
    /// @param auctionId id of auction
    /// @return address of auction creator
    function getCreator(uint256 auctionId) public view returns (address) {
        return _auctionLots[auctionId].auctionCreator;
    }

    /// @notice Return info about last bid
    /// @dev Return two params of last bid. Value and address
    /// @param auctionId id of auction
    /// @return lasBidder lastBid. Address of last bidder and value of last bid
    function getBidInfo(uint256 auctionId) external view returns (address, uint256) {
        return (_auctionLots[auctionId].lastBidder, _auctionLots[auctionId].lastBid);
    }

    /// @notice Returns full information about auction
    /// @dev Returns auction lot object by id with all params
    /// @param auctionId id of auction
    /// @return auctionLot auction object with all contains params
    function getAuctionInfo(uint256 auctionId) public view returns (AuctionLot memory) {
        return _auctionLots[auctionId];
    }

    /// @notice Creates new auction
    /// @dev Creates new auction entity in mapping
    /// @param tokenContract token contract address, that use in this lot
    /// @param tokenId id of tokens, that use in this lot
    /// @param amount amount of tokens, that will sell in auction, amount 0 for ERC721, amount >0 for ERC1155
    /// @param buyNowPrice buy now price, on which buyer could finish auction
    /// @param startPrice minimal price for first bid
    /// @param startTime timestamp when auction start
    /// @param endTime timestamp when auction end
    /// @param delta minimum difference between the past and the current bid
    function addAuctionLot(
        address tokenContract,
        uint256 tokenId,
        uint256 amount,
        address paymentToken,
        uint256 buyNowPrice,
        uint256 startPrice,
        uint256 startTime,
        uint256 endTime,
        uint256 delta
    ) external returns (uint256 id) {
        require(whitelistedPaymentTokens[paymentToken] || paymentToken == address(0), "Not whitelisted payment token");
        require(delta >= minDelta, "To low delta value");
        require(amount != 0, "Amount should be positive");
        require(startTime != 0, "Start time must be > zero");
        require(endTime > startTime, "Wrong auction ending date");

        if (IERC165(tokenContract).supportsInterface(type(IERC721).interfaceId)) {
            require(IERC721(tokenContract).isApprovedForAll(msg.sender, address(this)), "Not approved token");
        } else {
            require(IERC165(tokenContract).supportsInterface(type(IERC1155).interfaceId), "Not supported token");
            require(IERC1155(tokenContract).isApprovedForAll(msg.sender, address(this)), "Token is not approved");
        }

        id = lastId;

        _auctionLots[id] = AuctionLot(
            tokenContract,
            tokenId,
            msg.sender,
            amount,
            paymentToken,
            buyNowPrice,
            startPrice,
            block.timestamp + startTime,
            block.timestamp + endTime,
            delta,
            address(0),
            0
        );
        unchecked {
            // counter would not overflow
            lastId++;
        }
        emit AddAuctionLot(
            id,
            msg.sender,
            tokenContract,
            tokenId,
            amount,
            paymentToken,
            buyNowPrice,
            startPrice,
            block.timestamp + startTime,
            block.timestamp + endTime,
            delta
        );

        return id;
    }

    /// @notice Place bid in auction
    /// @dev Rewrite last bid amount and last bidder address in auction entity
    /// @param auctionId id of auction
    /// @param amount amount for bid

    function addBid(uint256 auctionId, uint256 amount) external payable nonReentrant {
        AuctionLot memory auction = getAuctionInfo(auctionId);

        require(auction.auctionCreator != address(0), "Auction does not exist");
        require(auction.auctionCreator != msg.sender, "Owner cannot add bid");
        require(auction.lastBidder != msg.sender, "Last bidder cannot add bid again");
        require(
            block.timestamp < auction.endTime || auction.lastBid != auction.buyNowPrice, "Auction is already finished"
        );
        require(amount <= auction.buyNowPrice, "Cannot be more than fixed price");

        if (auction.paymentToken == address(0)) {
            require(msg.value == amount, "Wrong msg.value");
        } else {
            uint256 balanceBefore = IERC20(auction.paymentToken).balanceOf(address(this));
            IERC20(auction.paymentToken).safeTransferFrom(msg.sender, address(this), amount);
            uint256 balanceAfter = IERC20(auction.paymentToken).balanceOf(address(this));
            amount = balanceAfter - balanceBefore; // Check for FoT tokens
        }

        if (auction.lastBidder != address(0)) {
            require(amount >= auction.lastBid + auction.delta, "Should be bigger than previous");

            _payout(auctionId, auction.paymentToken, auction.lastBidder, auction.lastBid);
        } else {
            require(amount >= auction.startPrice, "Should be bigger than startPrice");
        }

        _auctionLots[auctionId].lastBidder = msg.sender;
        _auctionLots[auctionId].lastBid = amount;

        emit AddBid(auctionId, msg.sender, amount);
    }

    /// @dev Increase endTime in auction entity
    /// @param auctionId id of auction
    /// @param newEndTime new timestamp for ending, could be no longer than 30 days than previous endTime
    function extendActionLifeTime(uint256 auctionId, uint256 newEndTime) public {
        AuctionLot memory auction = getAuctionInfo(auctionId);
        require(msg.sender == auction.auctionCreator, "Not creator of auction");
        require(!_extendedLots[auctionId], "Already extended");
        require(block.timestamp < auction.endTime && auction.lastBid != auction.buyNowPrice, "Auction finished");
        require(newEndTime - _auctionLots[auctionId].endTime <= 30 days, "Could extend only for 30 days");

        _auctionLots[auctionId].endTime = newEndTime;
        _extendedLots[auctionId] = true;

        emit ExtendAuction(auctionId, newEndTime);
    }

    /// @notice Edit auction
    /// @dev Possible to edit only: amount, startPrice, startTime, endTime, delta
    /// @dev If some of params are will not change, should give them their previous value
    /// @param auctionId id of auction
    /// @param buyNowPrice new or previous startPrice value
    /// @param startPrice new or previous startPrice value
    /// @param startTime new or previous startTime value
    /// @param endTime new or previous endTime value
    /// @param delta new or previous delta value
    function editAuctionLot(
        uint256 auctionId,
        uint256 buyNowPrice,
        uint256 startPrice,
        uint256 startTime,
        uint256 endTime,
        uint256 delta
    ) external {
        AuctionLot memory auction = getAuctionInfo(auctionId);
        require(msg.sender == auction.auctionCreator, "Not creator of auction");
        require(block.timestamp < auction.endTime && auction.lastBid != auction.buyNowPrice, "Auction finished");

        if (auction.startPrice != startPrice) {
            require(auction.lastBid == 0, "First bid already placed");
            _auctionLots[auctionId].startPrice = startPrice;
        }

        if (auction.startTime != startTime) {
            require(block.timestamp < auction.startTime, "Auction started");
            _auctionLots[auctionId].startTime = startTime;
        }

        if (auction.endTime != endTime) {
            extendActionLifeTime(auctionId, endTime);
        }

        if (auction.buyNowPrice != buyNowPrice) {
            _auctionLots[auctionId].buyNowPrice = buyNowPrice;
        }

        if (auction.delta != delta) {
            require(delta >= minDelta, "To low delta value");
            _auctionLots[auctionId].delta = delta;
        }

        emit EditAuctionLot(
            auctionId,
            _auctionLots[auctionId].buyNowPrice,
            _auctionLots[auctionId].startPrice,
            _auctionLots[auctionId].startTime,
            _auctionLots[auctionId].endTime,
            _auctionLots[auctionId].delta
        );
    }

    /// @notice Delete auction from contract
    /// @dev Removes entity by id from mapping
    /// @param auctionId id of auction, that should delete
    function delAuctionLot(uint256 auctionId) external {
        AuctionLot memory auction = getAuctionInfo(auctionId);
        require(msg.sender == auction.auctionCreator, "Not creator of auction");
        require(auction.lastBidder == address(0), "Auction started");

        delete _auctionLots[auctionId];
        emit DeleteAuctionLot(auctionId, msg.sender);
    }

    function _payout(uint256 auctionId, address paymentToken, address to, uint256 amount) internal {
        if (paymentToken == address(0)) {
            (bool success,) = to.call{value: amount}("");
            if (!success) {
                pendingPayments[to][auctionId] += amount;

                emit AddedPendingPayment(auctionId, to, amount);
            }
        } else {
            IERC20(paymentToken).safeTransfer(to, amount);
        }
    }

    function claimLot(uint256 auctionId) external payable {
        AuctionLot memory auction = getAuctionInfo(auctionId);
        require(block.timestamp >= auction.endTime || auction.lastBid == auction.buyNowPrice, "Auction not finished");
        require(auction.lastBidder == msg.sender, "You are not last bidder.");

        delete _auctionLots[auctionId];

        uint256 feeAmount = (auction.lastBid * fee) / 10000;
        collectedFees[auction.paymentToken] += feeAmount;
        uint256 finalPriceWithFee = auction.lastBid - feeAmount;
        uint256 royaltyAmount = 0;

        _payout(auctionId, auction.paymentToken, auction.auctionCreator, finalPriceWithFee);

        if (IERC165(auction.tokenContract).supportsInterface(type(IERC721).interfaceId)) {
            if (IERC721(auction.tokenContract).supportsInterface(type(IERC2981).interfaceId)) {
                if (auction.paymentToken == address(0)) {
                    (, royaltyAmount) = getRoyaltyInfo(auction.tokenContract, auction.tokenId, auction.lastBid);
                    require(
                        msg.value == royaltyAmount,
                        string(
                            abi.encodePacked(
                                "Value must be equal to ", Strings.toString(royaltyAmount), " (royalty fee)"
                            )
                        )
                    );
                }
                _repayRoyalty(
                    auction.lastBidder, auction.paymentToken, auction.tokenContract, auction.tokenId, auction.lastBid
                );
            }
            IERC721(auction.tokenContract).safeTransferFrom(auction.auctionCreator, auction.lastBidder, auction.tokenId);
        } else {
            if (IERC1155(auction.tokenContract).supportsInterface(type(IERC2981).interfaceId)) {
                if (auction.paymentToken == address(0)) {
                    (, royaltyAmount) = getRoyaltyInfo(auction.tokenContract, auction.tokenId, auction.lastBid);
                    require(
                        msg.value == royaltyAmount,
                        string(
                            abi.encodePacked(
                                "Value must be equal to ", Strings.toString(royaltyAmount), " (royalty fee)"
                            )
                        )
                    );
                }
                _repayRoyalty(
                    auction.lastBidder, auction.paymentToken, auction.tokenContract, auction.tokenId, auction.lastBid
                );
            }
            IERC1155(auction.tokenContract).safeTransferFrom(
                auction.auctionCreator, auction.lastBidder, auction.tokenId, auction.amount, ""
            );
        }

        emit ClaimAuctionLot(auctionId, auction.auctionCreator);
    }

    // Admin
    function setFee(uint256 newValue) external onlyOwner {
        require(newValue <= MAX_FEE, "Fee can't be grater that MAX_FEE");
        fee = newValue; // add timelock?

        emit NewFee(newValue);
    }

    function payoutPendingPayments(uint256 auctionId, address from, address to) external onlyOwner {
        AuctionLot memory auction = getAuctionInfo(auctionId);
        uint256 bal = pendingPayments[from][auctionId];
        delete pendingPayments[from][auctionId];

        if (auction.paymentToken == address(0)) {
            (bool success,) = to.call{value: bal}("");
            require(success, "Failed to send Ether");
        } else {
            IERC20(auction.paymentToken).safeTransfer(to, bal);
        }
        emit PayoutPendingPayments(auctionId, from, to);
    }

    function collectFee(address token, address destination) external onlyOwner {
        uint256 collectAmount = collectedFees[token];
        collectedFees[token] = 0;

        if (token == address(0)) {
            (bool success,) = destination.call{value: collectAmount}("");
            require(success, "Failed to send Ether");
        } else {
            IERC20(token).safeTransfer(destination, collectAmount);
        }
    }

    function addPaymentToken(address token) external onlyOwner {
        require(token != address(0), "Zero address for ether");
        whitelistedPaymentTokens[token] = true;
    }

    function removePaymentToken(address token) external onlyOwner {
        whitelistedPaymentTokens[token] = false;
    }

    function setMinDelta(uint256 newMinDelta) external onlyOwner {
        minDelta = newMinDelta;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory)
        public
        virtual
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    function onERC721Received(address, address, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }

    uint256[100] private __gap; // gap space for upgradable contract
}
