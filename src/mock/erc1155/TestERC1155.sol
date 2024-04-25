// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract TestToken1155 is ERC1155, ERC2981, Ownable {
    string public name;
    string public symbol;
    string private uri_;

    event RoyaltyChanged(address receiver, uint96 royaltyFeesInBips);
    event TokenRoyaltyChanged(uint256 tokenId, address receiver, uint96 royaltyFeesInBips);

    constructor(string memory _uri, uint96 royaltyFeesInBips)
        ERC1155(_uri)
        Ownable(_msgSender())
    {
        name = "Test1155WithRoyalties";
        symbol = "T1155WR";
        uri_ = _uri;
        setRoyaltyInfo(_msgSender(), royaltyFeesInBips);
    }

    /// @dev mint a new ERC1155 token
    /// @param to token reciever after minting
    /// @param id token id
    /// @param amount amount of token

    function mint(address to, uint256 id, uint256 amount) external onlyOwner {
        _mint(to, id, amount, bytes(""));
    }

    /// @dev mintBatch a new ERC1155 token
    /// @param to tokens reciever after minting
    /// @param ids tokens id
    /// @param amounts amount of tokens

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts) external onlyOwner {
        _mintBatch(to, ids, amounts, bytes(""));
    }

    /// @notice Burns butch tokens
    /// @dev  Also, tokens may be burned by operator
    /// @param owner burnable  tokens owner
    /// @param id id of burnable token
    /// @param value amount of burnable tokens

    function burn(address owner, uint256 id, uint256 value) external onlyOwner {
        _burn(owner, id, value);
    }

    /// @notice Burns tokens by any token holder
    /// @dev  Also, tokens may be burned by operator
    /// @param owner burnable tokens owner
    /// @param ids tokens id
    /// @param amounts amount of tokens

    function burnBatch(address owner, uint256[] memory ids, uint256[] memory amounts) external onlyOwner {
        _burnBatch(owner, ids, amounts);
    }

    /// @dev Sets new path to metadata
    /// @param _uri server url path for receive nft metadata

    function setUri(string memory _uri) external onlyOwner {
        uri_ = _uri;
    }

    /// @dev Returns full path of metadata content by token id
    /// @param id token identifier
    /// @return full url path for receive metadata

    function uri(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(uri_, Strings.toString(id)));
    }

    /// @dev Sets the royalty information that all ids in this contract will default to.
    /// @param _receiver royalty reciever. Cannot be the zero address.
    /// @param _royaltyFeesInBips fee percent. 1% = 100 bips

    function setRoyaltyInfo(address _receiver, uint96 _royaltyFeesInBips) public onlyOwner {
        require(_royaltyFeesInBips <= 1000, "Royalty must be <= 10%");
        _setDefaultRoyalty(_receiver, _royaltyFeesInBips);
        emit RoyaltyChanged(_receiver, _royaltyFeesInBips);
    }

    /// @dev Sets the royalty for one of the token.
    /// @param _tokenId token id.
    /// @param _receiver royalty reciever. Cannot be the zero address.
    /// @param _royaltyFeesInBips fee percent. 1% = 100 bips

    function setTokenRoyalty(uint256 _tokenId, address _receiver, uint96 _royaltyFeesInBips) public onlyOwner {
        require(_royaltyFeesInBips <= 1000, "Royalty must be <= 10%");
        _setTokenRoyalty(_tokenId, _receiver, _royaltyFeesInBips);

        emit TokenRoyaltyChanged(_tokenId, _receiver, _royaltyFeesInBips);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
