// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Payout2981Support {
    using SafeERC20 for IERC20;

    event RepayRoyalty(
        address from, address to, uint256 tokenId, uint256 royaltyAmount, address tokenAddress, uint256 salePrice
    );

    function getRoyaltyInfo(address tokenAddress, uint256 tokenId, uint256 salePrice)
        public
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        return IERC2981(tokenAddress).royaltyInfo(tokenId, salePrice);
    }

    /// @dev repay royalty for sale

    function _repayRoyalty(address sender, address saleToken, address tokenAddress, uint256 tokenId, uint256 salePrice)
        internal
    {
        (address receiver, uint256 royaltyAmount) = getRoyaltyInfo(tokenAddress, tokenId, salePrice);

        if (saleToken != address(0)) {
            IERC20(saleToken).safeTransferFrom(sender, receiver, royaltyAmount);
        } else {
            (bool sent,) = payable(receiver).call{value: royaltyAmount}("");
            require(sent, "Failed to send Ether");
        }
        emit RepayRoyalty(sender, receiver, tokenId, royaltyAmount, tokenAddress, salePrice);
    }
}
