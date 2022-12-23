// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "erc721a/contracts/ERC721A.sol";

contract BFGMysteryBox is ERC721A, Ownable {
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    Counters.Counter private _codeGenerator;

    IERC20 public immutable USD =
        IERC20(0x5425890298aed601595a70AB815c96711a31Bc65);

    mapping(address => string) public affiliate_code;
    mapping(string => address) public affiliate_codeAddress;
    mapping(address => uint256) public affiliate_points;

    mapping(string => address) public giveaway_address;
    mapping(address => string) public giveaway_code;
    mapping(string => uint256) public giveaway_points;
    mapping(address => bool) public hasMinted;

    address[] public affiliate_addresses;
    address[] public giveaway_addresses;

    uint256 public neededAvax;
    uint256 public neededUSD;

    uint256 public MAX_SUPPLY;
    uint256 public MAX_PRIVATE;

    bool startPublic;

    receive() external payable {}

    constructor() ERC721A("BFG Mistery Box NFT", "BFG-MB") {
        neededAvax = 13000000000000000000;
        neededUSD = 150000000;
        MAX_SUPPLY = 15000;
        MAX_PRIVATE = 5000;
        startPublic = false;
    }

    function compareStrings(string memory a, string memory b)
        internal
        pure
        returns (bool)
    {
        return (keccak256(abi.encodePacked((a))) ==
            keccak256(abi.encodePacked((b))));
    }

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://QmNPMP1wYVNbYJnwSiDMbppwFFeTc8w4LhzyqXDgyjf7oz/";
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length != 0
                ? string(abi.encodePacked(baseURI, _toString(tokenId), ".json"))
                : "";
    }

    function _getAffiliateAddresses() public view returns (address[] memory) {
        return affiliate_addresses;
    }

    function _getGiveawayAddresses() public view returns (address[] memory) {
        return giveaway_addresses;
    }

    //only Owner
    function changePublicMint() public onlyOwner {
        startPublic = !startPublic;
    }

    //only Owner
    function changeAVAXPrice(uint256 price) public onlyOwner {
        require(price > 0, "Price must be greater than 0");

        neededAvax = price;
    }

    //only Owner
    function changeUSDPrice(uint256 price) public onlyOwner {
        require(price > 0, "Price must be greater than 0");

        neededUSD = price;
    }

    //only Owner
    function changetMaxPrivate(uint256 _value) public onlyOwner {
        require(_value > 0, "Amount must be greater than 0");

        MAX_PRIVATE = _value;
    }

    //only Owner
    function withdrawTokens() public onlyOwner {
        uint256 amountAVAX = address(this).balance;
        uint256 amountUSDT = USD.balanceOf(address(this));

        require(amountAVAX > 0 || amountUSDT > 0, "No tokens to transfer");

        if (amountAVAX > 0) {
            (bool success, ) = payable(owner()).call{value: amountAVAX}("");

            require(success, "AVAX Transaction: Failed to transfer funds");
        }
        if (amountUSDT > 0) {
            USD.safeTransfer(owner(), amountUSDT);
        }
    }

    //only Owner
    function createAffiliateCode(string memory _code, address _user)
        public
        onlyOwner
    {
        //check if code is taken
        require(
            affiliate_codeAddress[_code] == address(0),
            "Code is already used for an address"
        );
        //check if address already has a code
        require(
            compareStrings(affiliate_code[_user], ""),
            "You already have a code for this address"
        );

        affiliate_codeAddress[_code] = _user;
        affiliate_code[_user] = _code;

        affiliate_addresses.push(_user);
    }

    function createGiveawayCode(string memory _code) public {
        require(
            hasMinted[msg.sender] == true,
            "Mint a mystery box to get a giveaway code."
        );
        //check if code is taken
        require(
            giveaway_address[_code] == address(0),
            "Code is already used for an address"
        );
        //check if address already has a code
        require(
            compareStrings(giveaway_code[msg.sender], ""),
            "You already have a code for this address"
        );
        giveaway_address[_code] = msg.sender;
        giveaway_code[msg.sender] = _code;
    }

    function mintPrivateBox(
        uint256 amount,
        uint256 _quantity,
        string memory _code
    ) public payable {
        uint256 newSupply = totalSupply() + _quantity;

        require(!startPublic, "Public sale has started");
        require(newSupply <= MAX_SUPPLY, "Max supply reached");
        require(
            newSupply <= MAX_PRIVATE,
            "Max supply for private round reached"
        );

        //check the quantity sent
        require(
            _quantity > 0,
            "Selected quantity of mint boxes must be greater than 0."
        );

        //check if any payment is sent
        require(msg.value > 0 || amount > 0, "Invalid payment attempt");

        //check if valid code
        require(
            (giveaway_address[_code] != address(0)) ||
                (affiliate_codeAddress[_code] != address(0)),
            "Not a valid code"
        );

        //USDT
        if (msg.value == 0 && amount > 0) {
            uint256 calUSD = _quantity * neededUSD;
            //check if user has needed USDT
            require(
                USD.balanceOf(msg.sender) >= calUSD,
                "Insufficient balance of USDT"
            );
            //check if amount equals neededh USDT
            require(amount == calUSD, "Invalid payment attempt");
            //check if user payed
            require(
                USD.transferFrom(msg.sender, address(this), calUSD),
                "transferFrom failed"
            );

            _mintNFT(msg.sender, _quantity, _code);
        }

        //AVAX
        if (msg.value > 0 && amount == 0) {
            uint256 calAVAX = _quantity * neededAvax;
            //check if user has needed AVAX
            require(
                msg.sender.balance >= calAVAX,
                "Insufficient balance of AVAX"
            );
            //check if amount equals needed AVAX
            require(msg.value == calAVAX, "Invalid payment attempt");

            _mintNFT(msg.sender, _quantity, _code);
        }
    }

    function mintPublicBox(
        uint256 amount,
        uint256 _quantity,
        string memory _code
    ) public payable {
        require(startPublic, "Public sale is not available at the moment");
        uint256 newSupply = totalSupply() + _quantity;

        require(newSupply <= MAX_SUPPLY, "Max supply reached");

        //check the quantity sent
        require(
            _quantity > 0,
            "Selected quantity of mint boxes must be greater than 0."
        );

        //check if any payment is sent
        require(msg.value > 0 || amount > 0, "Invalid payment attempt");

        //USDT
        if (msg.value == 0 && amount > 0) {
            uint256 calUSD = _quantity * neededUSD;
            //check if user has needed USDT
            require(
                USD.balanceOf(msg.sender) >= calUSD,
                "Insufficient balance of USDT"
            );
            //check if amount equals neededh USDT
            require(amount == calUSD, "Invalid payment attempt");
            //check if user payed
            require(
                USD.transferFrom(msg.sender, address(this), calUSD),
                "transferFrom failed"
            );

            _mintNFT(msg.sender, _quantity, _code);
        }

        //AVAX
        if (msg.value > 0 && amount == 0) {
            uint256 calAVAX = _quantity * neededAvax;
            //check if user has needed AVAX
            require(
                msg.sender.balance >= calAVAX,
                "Insufficient balance of AVAX"
            );
            //check if amount equals needed AVAX
            require(msg.value == calAVAX, "Invalid payment attempt");

            _mintNFT(msg.sender, _quantity, _code);
        }
    }

    function addressExists(address num) public view returns (bool) {
        for (uint256 i = 0; i < giveaway_addresses.length; i++) {
            if (giveaway_addresses[i] == num) {
                return true;
            }
        }
        return false;
    }

    function giveawayEnroll() public {
        require(hasMinted[msg.sender], "You need to buy 1 box");
        require(
            giveaway_points[giveaway_code[msg.sender]] > 0,
            "Use your promo code at least once"
        );
        require(!addressExists(msg.sender), "You have already enrolled");

        giveaway_addresses.push(msg.sender);
    }

    function _mintNFT(
        address player,
        uint256 quantity_,
        string memory _code
    ) internal {
        bool senderNoCode = compareStrings(giveaway_code[player], "");
        //no giveaway points if user already has minted
        if (giveaway_address[_code] != address(0)) {
            if (senderNoCode) {
                giveaway_points[_code] += 1;
            }
        }
        //affiliate points
        if (affiliate_codeAddress[_code] != address(0)) {
            affiliate_points[affiliate_codeAddress[_code]] += quantity_;
        }
        //minted code
        if (!hasMinted[player]) {
            hasMinted[player] = true;
        }
        _safeMint(player, quantity_);
    }
}
