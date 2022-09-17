// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.11;

import {IOwnable} from "./openzeppelin/IOwnable.sol";
import "./openzeppelin/SafeERC20.sol";
import "./SingleItemFactory.sol";

contract SingleItemListing {
    address public immutable factory;
    address public immutable seller;
    address public immutable tokenWanted;
    uint256 public immutable amountWanted;
    address public immutable arbitrator;
    uint256 public immutable protocolFee; // in bps
    uint256 public immutable arbitratorFee; // in bps
    uint256 public immutable blockCreated;
    bool public hasEnded = false;
    bool public purchased = false;
    address public buyer;
    address public admin;
    bool public sellerConfirm = false;
    bool public buyerConfirm = false;
    bool public arbitratorConfirm = false;
    bool public hasThisBeenReviewed = false;
    bool public hasThisSCOREBeenClaimed = false;
    string imageURL;
    string itemName;
    string itemDesc;
    

    event ListingPurchased(address buyer, address seller, address tokenWanted, uint256 amountWanted);
    event SellerConfirmation(address seller, bool sellerConfirm);
    event ArbitratorConfirmation(address arbitrator, bool arbitratorConfirm);
    event ListingArrived(address buyer, address seller, address tokenWanted, uint256 amountReceived);
    event ListingCanceled(address seller, address tokenWanted, uint256 amountWanted);

    constructor(
        address _seller,
        address _tokenWanted,
        address _arbitrator,
        uint256 _amountWanted,
        uint256 _protocolFee,
        uint256 _arbitratorFee,
        string memory _imageURL, 
        string memory _itemName, 
        string memory _itemDesc,
        uint _blockCreated
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
        itemName = _itemName;
        itemDesc = _itemDesc;
        blockCreated = _blockCreated;
    }

    function getAdmin() public view returns (address) {
        return IOwnable(factory).owner();
    }

    function getFactory() public view returns (address) {
        return factory;
    }

    function buy() public {
        require(purchased == false);
        require(msg.sender != buyer && msg.sender != arbitrator);
        uint256 protocolFeeExact = mulDiv(amountWanted, protocolFee, 10000);
        uint256 arbitratorFeeExact = mulDiv(amountWanted, arbitratorFee, 10000);
        uint256 feeSum = protocolFeeExact + arbitratorFeeExact;
        uint256 amountWantedMinusFeeSum = amountWanted - feeSum;
        buyer = msg.sender;
        IERC20(tokenWanted).transferFrom(msg.sender, address(this), amountWantedMinusFeeSum);
        IERC20(tokenWanted).transferFrom(msg.sender, getAdmin(), protocolFeeExact);
        IERC20(tokenWanted).transferFrom(msg.sender, arbitrator, arbitratorFeeExact);
        //storage info
        purchased = true;
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

    function reviewSeller() public {
        require(msg.sender == factory);
        hasThisBeenReviewed = true;
    }

    function sellerClaim() public returns (bool) {
        //the primary executed if, checks that the buyer and seller have confirmed
        //and releases the assets
        if (sellerConfirm == true && buyerConfirm == true && purchased == true) {
            SafeERC20.safeTransfer(IERC20(tokenWanted), seller, IERC20(tokenWanted).balanceOf(address(this)));
            hasEnded = true;
            return hasEnded;
        }
        //seller confirms + arbitrator confirms in case of buyer forgetting to sign
        //or a rare case of a buyer attempting to scam the seller
        if (sellerConfirm == true && arbitratorConfirm == true && purchased == true) {
            SafeERC20.safeTransfer(IERC20(tokenWanted), seller, IERC20(tokenWanted).balanceOf(address(this)));
            hasEnded = true;
            return hasEnded;
        }
        //rare but possible
        if (buyerConfirm == true && arbitratorConfirm == true && purchased == true) {
            SafeERC20.safeTransfer(IERC20(tokenWanted), seller, IERC20(tokenWanted).balanceOf(address(this)));
            hasEnded = true;
            return hasEnded;
        }

        return hasEnded;
    }

    function returnAssetsToBuyer() public {
        /**An arbitrator only function to return assets to the buyer
        you don't actually want the buyer to be able to call this function
        Because if the buyer was able to call this function, then 
        at any time once the item is shipped the assets could be
        returned to the buyer, allowing manipulation.
        */

        require(msg.sender == arbitrator);
        require(arbitratorConfirm == false && buyerConfirm == false);
        require(purchased == true);
        SafeERC20.safeTransfer(IERC20(tokenWanted), buyer, IERC20(tokenWanted).balanceOf(address(this)));
        hasEnded = true;
    }

    function getHasThisSCOREBeenClaimed() public view returns (bool) {
        return hasThisSCOREBeenClaimed;
    }

    function setHasThisScoreBeenClaimed() public {
        require(msg.sender == factory);
        hasThisSCOREBeenClaimed = true;
    }

    //function userPurchaseStorage(address user, SingleItemListing individualListing)
    function setUserPurchaseStorage() internal {
        SingleItemFactory(factory).userPurchaseStorage(buyer, address(this));
    }

    function cancel() public {
        require(msg.sender == seller);
        require(hasEnded == false);
        require(purchased == false);
        //logic after checking requires to avoid reentrancy
        hasEnded = true;
        emit ListingCanceled(seller, tokenWanted, IERC20(tokenWanted).balanceOf(address(this)));
    }

    function hasTokens() public view returns (bool) {
        return IERC20(tokenWanted).balanceOf(address(this)) > 0;
    }

    function getHasEnded() public view returns (bool) {
        return hasEnded;
    }

    function getHasThisBeenReviewed() public view returns (bool) {
        return hasThisBeenReviewed;
    }
    
    function getBuyer() public view returns (address) {
        return buyer;
    }

    function getSeller() public view returns (address) {
        return seller;
    }

    struct localVars {
        address seller_;
        address arbitrator_;
        address tokenWanted_;
        uint256 amountWanted_;
        string imageURL_; 
        string itemName_; 
        string itemDesc_;
        uint blockCreated_;
    }

    function getFrontEndData() public view returns (localVars memory) {
        localVars memory vars; 
        //assign memory variables
        vars.seller_ = seller;
        vars.arbitrator_ = arbitrator;
        vars.tokenWanted_ = tokenWanted;
        vars.amountWanted_ = amountWanted;
        vars.itemName_ = itemName;
        vars.imageURL_ = imageURL;
        vars.itemDesc_ = itemDesc;
        vars.blockCreated_ = blockCreated;
        return vars;
    }

    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 z
    ) public pure returns (uint256) {
        return (x * y) / z;
    }
}
