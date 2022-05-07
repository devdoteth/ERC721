// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

/// @title NFT
/// @author dev.eth

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFT is ERC721Enumerable, Ownable, ReentrancyGuard, PaymentSplitter {
    using Counters for Counters.Counter;

    using Strings for uint256;

    bytes32 public merkleRoot;

    Counters.Counter private _nftIdCounter;

    uint256 public constant MAX_SUPPLY = 2500;

    uint256 public max_mint_allowed = 3;

    uint256 public pricePresale = 0.0003 ether;

    uint256 public priceSale = 0.0004 ether;

    string public baseURI;

    string public notRevealedURI;

    string public baseExtension = ".json";

    bool public revealed = false;

    bool public paused = false;

    //The different stages of selling the collection
    enum Steps {
        Before,
        Presale,
        Sale,
        SoldOut,
        Reveal
    }

    Steps public sellingStep;

    address private _owner;

    mapping(address => uint256) nftsPerWallet;

    //Addresses of all the members of the team
    address[] private _team = [
        0x292398ce6f4806420347854Ad42BeBd80Fb81d78,
        0x5bbF6b214b48B9eeb4aD3d0f6D4b26991Ed11634,
        0x7c16919Bb94FC9FAE1cd0F5A6BF813D24251f3EF
    ];

    //Shares of all the members of the team
    uint256[] private _teamShares = [40, 30, 30];

    constructor(
        string memory _theBaseURI,
        string memory _notRevealedURI,
        bytes32 _merkleRoot
    ) ERC721("NFT", "NFT") PaymentSplitter(_team, _teamShares) {
        _nftIdCounter.increment();
        transferOwnership(msg.sender);
        sellingStep = Steps.Before;
        baseURI = _theBaseURI;
        notRevealedURI = _notRevealedURI;
        merkleRoot = _merkleRoot;
    }

    /**
     * @notice Edit the Merkle Root
     *
     * @param _newMerkleRoot The new Merkle Root
     **/
    function changeMerkleRoot(bytes32 _newMerkleRoot) external onlyOwner {
        merkleRoot = _newMerkleRoot;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function changeMaxMintAllowed(uint256 _maxMintAllowed) external onlyOwner {
        max_mint_allowed = _maxMintAllowed;
    }

    function changePricePresale(uint256 _pricePresale) external onlyOwner {
        pricePresale = _pricePresale;
    }

    function changePriceSale(uint256 _priceSale) external onlyOwner {
        priceSale = _priceSale;
    }

    function setBaseUri(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }

    function setNotRevealURI(string memory _notRevealedURI) external onlyOwner {
        notRevealedURI = _notRevealedURI;
    }

    function reveal() external onlyOwner {
        revealed = true;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function setBaseExtension(string memory _baseExtension) external onlyOwner {
        baseExtension = _baseExtension;
    }

    function setUpPresale() external onlyOwner {
        sellingStep = Steps.Presale;
    }

    function setUpSale() external onlyOwner {
        require(
            sellingStep == Steps.Presale,
            "First the presale, then the sale."
        );
        sellingStep = Steps.Sale;
    }

    /**
     * @notice Allows to mint one NFT if whitelisted
     *
     * @param _account The account of the user minting the NFT
     * @param _proof The Merkle Proof
     **/
    function presaleMint(address _account, bytes32[] calldata _proof)
        external
        payable
        nonReentrant
    {
        require(sellingStep == Steps.Presale, "Presale has not started yet.");

        require(
            nftsPerWallet[_account] < 1,
            "You can only get 1 NFT on the Presale"
        );

        require(isWhiteListed(_account, _proof), "Not on the whitelist");

        uint256 price = pricePresale;

        require(msg.value >= price, "Not enought funds.");

        nftsPerWallet[_account]++;

        _safeMint(_account, _nftIdCounter.current());

        _nftIdCounter.increment();
    }

    function saleMint(uint256 _ammount) external payable nonReentrant {
        uint256 numberNftSold = totalSupply();

        uint256 price = priceSale;

        require(sellingStep != Steps.SoldOut, "Sorry, no NFTs left.");

        require(sellingStep == Steps.Sale, "Sorry, sale has not started yet.");

        require(msg.value >= price * _ammount, "Not enought funds.");

        require(
            _ammount <= max_mint_allowed,
            "You can't mint more than 3 tokens"
        );

        require(
            numberNftSold + _ammount <= MAX_SUPPLY,
            "Sale is almost done and we don't have enought NFTs left."
        );

        nftsPerWallet[msg.sender] += _ammount;

        if (numberNftSold + _ammount == MAX_SUPPLY) {
            sellingStep = Steps.SoldOut;
        }

        for (uint256 i = 1; i <= _ammount; i++) {
            _safeMint(msg.sender, numberNftSold + i);
        }
    }

    function gift(address _account) external onlyOwner {
        uint256 supply = totalSupply();
        require(supply + 1 <= MAX_SUPPLY, "Sold out");
        _safeMint(_account, supply + 1);
    }

    function isWhiteListed(address account, bytes32[] calldata proof)
        internal
        view
        returns (bool)
    {
        return _verify(_leaf(account), proof);
    }

    /**
     * @notice Return the account hashed
     *
     * @param account The account to hash
     *
     * @return The account hashed
     **/
    function _leaf(address account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(account));
    }

    /**
     * @notice Returns true if a leaf can be proved to be a part of a Merkle tree defined by root
     *
     * @param leaf The leaf
     * @param proof The Merkle Proof
     *
     * @return True if a leaf can be provded to be a part of a Merkle tree defined by root
     **/
    function _verify(bytes32 leaf, bytes32[] memory proof)
        internal
        view
        returns (bool)
    {
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }

    function tokenURI(uint256 _nftId)
        public
        view
        override(ERC721)
        returns (string memory)
    {
        require(_exists(_nftId), "This NFT doesn't exist.");
        if (revealed == false) {
            return notRevealedURI;
        }

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        _nftId.toString(),
                        baseExtension
                    )
                )
                : "";
    }
}
