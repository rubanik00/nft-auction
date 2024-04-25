// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestToken721 is ERC721Enumerable, ERC2981, ERC721URIStorage {
    using SafeERC20 for IERC20;
    using Strings for uint16;

    string internal _baseTokenURI;

    event RoyaltyChanged(address receiver, uint96 royaltyFeesInBips);
    event TokenRoyaltyChanged(uint256 tokenId, address receiver, uint96 royaltyFeesInBips);
    event SetTokenURI(uint256 tokenId, string _tokenURI);
    event Burn(uint256 tokenId);
    event SetMaxQuantity(uint16 newMaxQuantity);
    event ETHUnlocked(uint256 ethAmount);
    event SetBaseURI(string baseURI_);

    /// @dev Sets main dependencies and constants
    /// @param royaltyFeesInBips fee percent. 1% = 100 bips

    constructor(uint96 royaltyFeesInBips) ERC721("TestERC721WithRoyalty", "TEST_721_ROYALTY") {
        setRoyaltyInfo(_msgSender(), royaltyFeesInBips);
    }

    /// @dev Set the base URI
    /// @param baseURI_ Base path to metadata

    function setBaseURI(string memory baseURI_) public {
        _baseTokenURI = baseURI_;
        emit SetBaseURI(baseURI_);
    }

    /// @dev Get current base uri

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /// @dev Return the token URI. Included baseUri concatenated with tokenUri
    /// @param tokenId Id of ERC721 token

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    /// @dev Set the token URI
    /// @param tokenId Id of ERC721 token
    /// @param _tokenURI token URI without base URI

    function setTokenURI(uint256 tokenId, string memory _tokenURI) external {
        super._setTokenURI(tokenId, _tokenURI);
        emit SetTokenURI(tokenId, _tokenURI);
    }

    /// @dev Mint a new ERC721 token with incremented id and custom url
    /// @param uri token metadata

    function mint(string memory uri, uint256 tokenId) external payable {
        _mint(msg.sender, tokenId, uri);
    }

    /// @dev Interanl mint a new ERC721 token with incremented id and custom url
    /// @param to token reciever after minting
    /// @param uri token metadata

    function _mint(address to, uint256 tokenId, string memory uri) internal {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    /// @dev burn a existing ERC721 token
    /// @param tokenId Id of ERC721 token

    function burn(uint256 tokenId) external {
        _burn(tokenId);
        emit Burn(tokenId);
    }


    /// @dev Sets the royalty information that all ids in this contract will default to.
    /// @param _receiver royalty reciever. Cannot be the zero address.
    /// @param _royaltyFeesInBips fee percent. 1% = 100 bips

    function setRoyaltyInfo(address _receiver, uint96 _royaltyFeesInBips) public {
        require(_royaltyFeesInBips <= 1000, "Royalty must be <= 10%");
        _setDefaultRoyalty(_receiver, _royaltyFeesInBips);
        emit RoyaltyChanged(_receiver, _royaltyFeesInBips);
    }

    /// @dev Sets the royalty for one of the token.
    /// @param _tokenId token id.
    /// @param _receiver royalty reciever. Cannot be the zero address.
    /// @param _royaltyFeesInBips fee percent. 1% = 100 bips

    function setTokenRoyalty(uint256 _tokenId, address _receiver, uint96 _royaltyFeesInBips) public {
        require(_royaltyFeesInBips <= 1000, "Royalty must be <= 10%");
        _setTokenRoyalty(_tokenId, _receiver, _royaltyFeesInBips);

        emit TokenRoyaltyChanged(_tokenId, _receiver, _royaltyFeesInBips);
    }

    /// @dev Withdraw all ETH from contract to the contract owner

    function unlockETH() external {
        uint256 amt = address(this).balance;
        require(amt > 0, "Balance is zero.");
        payable(msg.sender).transfer(amt);
        emit ETHUnlocked(amt);
    }

    function _increaseBalance(address account, uint128 amount) internal virtual override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, amount);
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        virtual
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC2981, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
