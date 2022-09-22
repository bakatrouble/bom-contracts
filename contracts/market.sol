// SPDX-License-Identifier: MIT OR Apache-2.0
//mostly done

pragma solidity ^0.8.14;
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/ITreasury.sol";

contract Marketplace is Initializable {
    //variables
    uint256 currentSaleId;
    uint256 fee;
    ITreasury treasury;
    IERC721Upgradeable nft;
    IERC20Upgradeable BoM;
    struct Sale {
        address payable seller;
        uint256 tokenId;
        uint256 price;
        bool bought;
        bool cancelled;
    }
    mapping(uint256 => Sale) saleIdToSale;

    //events
    event SaleCreated(
        uint256 indexed saleId,
        address indexed seller,
        uint256 price,
        uint256 indexed tokenId
    );

    event SaleCancelled(uint256 indexed saleId);

    event SaleUpdated(
        uint256 indexed saleId,
        uint256 oldPrice,
        uint256 newPrice
    );

    event TokenBought(
        uint256 indexed saleId,
        address indexed buyer,
        uint256 indexed tokenId,
        uint256 price
    );

    event FeesChanged(address indexed admin, uint256 oldFee, uint256 newFee);

    //modifiers
    modifier isExistingSale(uint256 saleId) {
        require(saleIdToSale[saleId].price != 0, "!exists");
        _;
    }

    modifier onlySaleOwner(uint256 saleId) {
        require(saleIdToSale[saleId].seller == msg.sender, "!seller");
        _;
    }

    modifier onlyValidPrice(uint256 price) {
        require(price > 0, "!price");
        _;
    }

    modifier onlyAdmin() {
        require(treasury.isAdmin(msg.sender), "!admin");
        _;
    }

    // constructor(
    //     uint256 _fee,
    //     ITreasury _treasury,
    //     IERC721Upgradeable _nft,
    //     IERC20Upgradeable token
    // ) {
    //     fee = _fee;
    //     treasury = _treasury;
    //     nft = _nft;
    //     BoM = token;
    // }

    function initialize(
        uint256 _fee,
        ITreasury _treasury,
        IERC721Upgradeable _nft,
        IERC20Upgradeable token
    ) public initializer {
        fee = _fee;
        treasury = _treasury;
        nft = _nft;
        BoM = token;
    }

    //internal functions
    function _distributeFunds(uint256 amount, address seller) internal {
        uint256 _fee = (amount * fee) / 10000;
        uint256 goesToSeller = amount - _fee;
        BoM.transferFrom(msg.sender, address(this), _fee);
        BoM.transferFrom(msg.sender, seller, goesToSeller);
    }

    //external functions
    function createSale(uint256 tokenId, uint256 price)
        public
        onlyValidPrice(price)
    {
        currentSaleId++;
        Sale storage sale = saleIdToSale[currentSaleId];
        sale.seller = payable(msg.sender);
        sale.price = price;
        sale.tokenId = tokenId;
        nft.transferFrom(msg.sender, address(this), tokenId);
        emit SaleCreated(currentSaleId, msg.sender, price, tokenId);
    }

    function cancelSale(uint256 saleId) public onlySaleOwner(saleId) {
        Sale storage sale = saleIdToSale[saleId];
        require(!sale.bought, "bought");
        require(!sale.cancelled, "cancelled");
        nft.transferFrom(address(this), msg.sender, sale.tokenId);
        sale.cancelled = true;
        emit SaleCancelled(saleId);
    }

    function updateSale(uint256 saleId, uint256 price)
        public
        onlySaleOwner(saleId)
        onlyValidPrice(price)
        isExistingSale(saleId)
    {
        Sale storage sale = saleIdToSale[saleId];
        require(!sale.bought, "bought");
        require(!sale.cancelled, "cancelled");
        uint256 oldPrice = sale.price;
        sale.price = price;
        emit SaleUpdated(saleId, oldPrice, price);
    }

    function buyToken(uint256 saleId) public isExistingSale(saleId) {
        Sale storage sale = saleIdToSale[saleId];
        require(!sale.bought, "bought");
        require(!sale.cancelled, "cancelled");
        nft.transferFrom(address(this), msg.sender, sale.tokenId);
        _distributeFunds(sale.price, sale.seller);
        sale.bought = true;
        emit TokenBought(saleId, msg.sender, sale.tokenId, sale.price);
    }

    //admin functions
    function changeFees(uint256 _fee) public onlyAdmin {
        require(_fee > 0 && _fee < 2000, "wrong arg");
        emit FeesChanged(msg.sender, fee, _fee);
        fee = _fee;
    }
}
