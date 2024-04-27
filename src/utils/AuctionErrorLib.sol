// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

library AuctionErrorLib {
    error NotOwner(address caller);
    error NotWhitelistedPaymentToken();
    error ToLowDelta();
    error AmountEquelZero();
    error StartTimeEqualZero();
    error WrongAuctionEndingDate();
    error NotApprovedToken();
    error NotSupportedToken();
    error AuctionDoesNotExist();
    error OwnerCannotAddBid();
    error CannotAddBidAgain();
    error AuctionIsAlreadyFinished();
    error AmountMoreThanFixedPrice();
    error WrongMsgValue();
    error ShouldBeBiggerThanPrevious();
    error ShouldBeBiggerThanStartPrice();
    error AlreadyExtended();
    error CouldExtendOnlyFor30Days();
    error FirstBidAlreadyPlaced();
    error AuctionIsAlreadyStarted();
    error NotLastBidder();
    error RoyaltyValueMustBeEqualTo(uint256 royaltyAmount);
    error GraterThanMaxFee(uint256 maxFee);
    error FaliedToSendEther();
    error NativeAddress();
}
