// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BFGMysteryBox is ERC721URIStorage, Ownable {
    using SafeERC20 for IERC20;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    IERC20 public immutable USD =
        IERC20(0x5425890298aed601595a70AB815c96711a31Bc65);

    string public tokenURI;

    mapping(address => string) public code;
    mapping(string => address) public codeAddress;
    mapping(address => uint256) public points;

    address[] public arrayAddresses;

    uint256 public neededAvax;
    uint256 public neededUSD;

    uint256 public maxSupply;
    uint256 public reservedSupply;

    receive() external payable {}

    constructor() ERC721("BFG Mistery Box NFT", "BFG-MB") {
        createPromoCode("0", owner());
        neededAvax = 13000000000000000000;
        neededUSD = 150000000;
        maxSupply = 15000;
        reservedSupply = 7500;
        tokenURI = "ipfs://QmTKiWjG5e17D6i82BWgu31kqnaYJzohTDP7hxenFfWScD";
    }

    function compareStrings(string memory a, string memory b)
        internal
        pure
        returns (bool)
    {
        return (keccak256(abi.encodePacked((a))) ==
            keccak256(abi.encodePacked((b))));
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }

    function _getAddresses() public view returns (address[] memory) {
        return arrayAddresses;
    }

    //only Owner
    function adaptAVAXPrice(uint256 price) public onlyOwner {
        require(price > 0, "Price must be greater than 0");

        neededAvax = price;
    }

    //only Owner
    function adaptUSDPrice(uint256 price) public onlyOwner {
        require(price > 0, "Price must be greater than 0");

        neededUSD = price;
    }

    //only Owner
    function setReservedSupply(uint256 newAmount) public onlyOwner {
        reservedSupply = newAmount;
    }

    //only Owner
    function createPromoCode(string memory _code, address _user)
        public
        onlyOwner
    {
        //check if code is taken
        require(
            codeAddress[_code] == address(0),
            "Code is already used for an address"
        );
        //check if address already has a code
        require(
            compareStrings(code[_user], ""),
            "You already have a code for this address"
        );

        codeAddress[_code] = _user;
        code[_user] = _code;

        arrayAddresses.push(_user);
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
    function mintReserved(
        address player,
        string memory _code,
        uint256 quantity_
    ) public onlyOwner {
        uint256 newSupply = _tokenIds.current() + quantity_;

        require(
            reservedSupply >= quantity_,
            "Quantity exceeds mintable reserves"
        );
        require(reservedSupply > 0, "No more mintable reserves");
        require(newSupply <= maxSupply, "Max supply reached");
        require(
            quantity_ > 0,
            "Selected quantity of mint boxes must be greater than 0."
        );
        require(codeAddress[_code] != address(0), "Not a valid code.");

        reservedSupply -= quantity_;

        _mintNFT(player, _code, quantity_);
    }

    function mintBox(
        string memory _code,
        uint256 amount,
        uint256 quantity_
    ) public payable {
        //is totalSupply reached
        uint256 newSupply = _tokenIds.current() + quantity_;

        require(newSupply <= maxSupply, "Max supply reached");
        require(
            newSupply <= (maxSupply - reservedSupply),
            "Remaining tokens are reserved"
        );

        //check if more than one mint
        require(
            quantity_ > 0,
            "Selected quantity of mint boxes must be greater than 0."
        );

        //check if the code exists
        require(codeAddress[_code] != address(0), "Not a valid code.");

        //check if any payment is made
        require(msg.value > 0 || amount > 0, "Invalid payment attempt");

        //USDT
        if (msg.value == 0 && amount > 0) {
            uint256 calUSD = quantity_ * neededUSD;
            //check if user has that much USDT
            require(
                USD.balanceOf(msg.sender) >= calUSD,
                "Insufficient balance of USDT"
            );
            //check if value is that much USDT
            require(amount == calUSD, "Invalid payment attempt");
            //check if user payed
            require(
                USD.transferFrom(msg.sender, address(this), calUSD),
                "transferFrom failed"
            );

            _mintNFT(msg.sender, _code, quantity_);
        }

        //AVAX
        if (msg.value > 0 && amount == 0) {
            uint256 calAVAX = quantity_ * neededAvax;
            require(
                msg.sender.balance >= calAVAX,
                "Insufficient balance of AVAX"
            );
            require(msg.value == calAVAX, "Invalid payment attempt");

            _mintNFT(msg.sender, _code, quantity_);
        }
    }

    function _mintNFT(
        address player,
        string memory _code,
        uint256 quantity_
    ) internal {
        for (uint256 i = 0; i < quantity_; i++) {
            _tokenIds.increment();

            _safeMint(player, _tokenIds.current());
            _setTokenURI(_tokenIds.current(), tokenURI);
        }

        points[codeAddress[_code]] += quantity_;
    }
}
