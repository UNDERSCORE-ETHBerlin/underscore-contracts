// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.11;

import {IOwnable} from "../openzeppelin/IOwnable.sol";
import "../openzeppelin/SafeERC20.sol";

contract ItemListing {
    address public immutable factory;
    address public immutable seller;
    address public immutable tokenWanted;
    uint256 public immutable amountWanted;
    address public immutable arbitrator;
    uint256 public immutable protocolFee; // in bps
    uint256 public immutable arbitratorFee; // in bps
    bool public hasEnded = false;
    bool public purchased = false;
    address public buyer;
    address public admin;
    bool public sellerConfirm = false;
    bool public buyerConfirm = false;
    bool public arbitratorConfirm = false;
    string memory imageURL;
    string memory name;
    string memory desc;

    event ListingPurchased(address buyer, address seller, address tokenWanted, uint256 amountWanted);
    event SellerConfirmation(address seller, bool sellerConfirm);
    event ArbitratorConfirmation(address arbitrator, bool arbitratorConfirm);
    event ListingArrived(address buyer, address seller, address tokenWanted, uint256 amountWanted);
    event ListingCanceled(address seller, address tokenWanted, uint256 amountWanted);



    constructor(
        address _seller,
        address _tokenWanted,
        address _arbitrator,
        uint256 _amountWanted,
        uint256 _protocolFee,
        uint256 _arbitratorFee,
        string memory _imageURL, 
        string memory _name, 
        string memory _desc
    ) {
        factory = msg.sender;
        seller = _seller;
        tokenWanted = _tokenWanted;
        amountWanted = _amountWanted;
        arbitrator = _arbitrator;
        protocolFee = _protocolFee;
        arbitratorFee = _arbitratorFee;
        admin = IOwnable(factory).owner();
        imageURL = _imageURL;
        name 
    }

    function getAdmin() public view returns (address) {
        return IOwnable(factory).owner();
    }

    function buy() public {
        require(purchased == false);
        require(msg.sender != buyer && msg.sender != arbitrator);
        uint256 protocolFeeExact = mulDiv(amountWanted, protocolFee, 10000);
        uint256 arbitratorFeeExact = mulDiv(amountWanted, arbitratorFee, 10000);
        uint256 feeSum = protocolFeeExact + arbitratorFeeExact;
        uint256 amountWantedMinusFeeSum = amountWanted - feeSum;
        IERC20(tokenWanted).transferFrom(msg.sender, address(this), amountWantedMinusFeeSum);
        IERC20(tokenWanted).transferFrom(msg.sender, getAdmin(), protocolFeeExact);
        IERC20(tokenWanted).transferFrom(msg.sender, getAdmin(), arbitratorFeeExact);
        //storage info
        purchased = true;
        buyer = msg.sender;
        emit ListingPurchased(buyer, seller, tokenWanted, amountWanted);
    }

    function confirmArrival() public {
        require(msg.sender == buyer || msg.sender == seller || msg.sender == arbitrator);
        if (msg.sender == buyer) {
            buyerConfirm = true;
            emit ListingArrived(buyer, seller, tokenWanted, amountWanted);
        }
        if (msg.sender == seller) {
            sellerConfirm = true;
            emit SellerConfirmation(seller, sellerConfirm);
        }
        if (msg.sender == arbitrator) {
            arbitratorConfirm = true;
            emit ArbitratorConfirmation(arbitrator, arbitratorConfirm);
        }
    }

    function sellerClaim() public returns (bool) {
        if (sellerConfirm == true && buyerConfirm == true && purchased == true) {
            SafeERC20.safeTransfer(IERC20(tokenWanted), seller, amountWanted);
            hasEnded = true;
            return hasEnded;
        }
        if (sellerConfirm == true && arbitratorConfirm == true && purchased == true) {
            SafeERC20.safeTransfer(IERC20(tokenWanted), seller, amountWanted);
            hasEnded = true;
            return hasEnded;
        }
        if (buyerConfirm == true && arbitratorConfirm == true && purchased == true) {
            SafeERC20.safeTransfer(IERC20(tokenWanted), seller, amountWanted);
            hasEnded = true;
            return hasEnded;
        }
        return hasEnded;
    }

    function returnAssetsToBuyer() public {
        require(msg.sender == arbitrator || msg.sender == buyer);
        require(arbitratorConfirm == false);
        require(buyerConfirm == false);
        require(purchased == true);
        SafeERC20.safeTransfer(IERC20(tokenWanted), buyer, amountWanted);
    }

    function cancel() public {
        require(msg.sender == seller);
        require(purchased == false);
        hasEnded = true;
        emit ListingCanceled(seller, tokenWanted, amountWanted);
    }

    function hasTokens() public view returns (bool) {
        return IERC20(tokenWanted).balanceOf(address(this)) > 0;
    }

    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 z
    ) public pure returns (uint256) {
        return (x * y) / z;
    }
}
