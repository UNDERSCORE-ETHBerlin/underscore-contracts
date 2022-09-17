// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.11;

import {SingleItemListing} from "./SingleItemListing.sol";

contract SingleItemFactory {
    uint256 public protocolFee = 750; // in bps
    uint256 public arbitratorFee = 100; // in bps
    address public admin;
    uint256 public distributionSpeed; //per block

    SingleItemListing[] public listings;
    mapping(address => SingleItemListing[]) public userListings;
    mapping(address => SingleItemListing[]) public userPurchases;
    mapping(address => uint) adjustedVolumeAccrued;

    struct userRatings {
        uint256 userAverage;
        uint256 numOfReviews;
    }
    mapping(address => userRatings) public userRatingMapping;

    constructor() {
        admin = msg.sender;
    }

    function transferAdmin(address newAdmin) public {
        require(msg.sender == admin); 
        admin = newAdmin;
    }

    function owner() public view returns (address) {
        return admin;
    }

    event ListingCreated(address listingAddress, address tokenWanted, uint256 amountWanted);

    function setProtocolFee(uint256 _newProtocolFee) public  {
        require(msg.sender == admin);
        protocolFee = _newProtocolFee;
    }
    
    function setArbitratorFee(uint256 _newArbitratorFee) public {
        require(msg.sender == admin);
        protocolFee = _newArbitratorFee;
    }

    function createListing(address _tokenWanted, uint256 _amountWanted, address arbitrator, string memory imageURL, string memory name, string memory desc) public returns (SingleItemListing) {
        SingleItemListing listing = new SingleItemListing(
            msg.sender, 
            _tokenWanted, 
            arbitrator, 
            _amountWanted, 
            protocolFee, 
            arbitratorFee,
            imageURL,
            name,
            desc,
            block.number
        );
        listings.push(listing);
        userListings[msg.sender].push(listing);
        emit ListingCreated(address(listing), _tokenWanted, _amountWanted);
        return listing;
    }

    //reviews
    
    function writeReview(uint256 review, SingleItemListing listing) public returns (uint256) {
        require(review == 1 || review == 2 || review == 3 || review == 4 || review == 5, "Review is not a compatible number");
        require(listing.getHasThisBeenReviewed() == false, "This listing has already been reviewed");
        require(listing.getHasEnded() == true && msg.sender == listing.getBuyer());
        //reading the current data
        address seller = listing.getSeller();
        uint256 currentAvgReview = userRatingMapping[seller].userAverage;        
        uint256 currentNumOfReviews = userRatingMapping[seller].numOfReviews;
        //calculating the new average
        uint256 newAvg = (currentAvgReview * currentNumOfReviews) + review;
        uint256 newNumOfReviews = currentNumOfReviews + 1;

        //writing the data to storage
        listing.reviewSeller(); //avoids double reviewing
        userRatingMapping[seller].userAverage = newAvg;
        userRatingMapping[seller].numOfReviews = newNumOfReviews;
        return review;
    }

    //post hackathon distributions can actually be distributed, this is to keep proper accounting until then
    function accrueDistributions(address user) public returns (uint256) {
        SingleItemListing[] memory usersListings = getSingleUserListings(msg.sender);
        uint256 volumeUnaccrued;
        for (uint256 i; i < usersListings.length; i++) {
            SingleItemListing individualListing = SingleItemListing(usersListings[i]);
            if (individualListing.hasEnded() && !individualListing.hasThisSCOREBeenClaimed()) {
                individualListing.setHasThisScoreBeenClaimed();
                volumeUnaccrued += individualListing.amountWanted();
            }
        }
        //adjusting volume for rating, punishing bad sellers
        uint256 userRatingCurrently = userRatingMapping[user].userAverage;
        uint256 adjustedVolumeUnaccrued = (userRatingCurrently - 1) * volumeUnaccrued;
        adjustedVolumeAccrued[user] += adjustedVolumeUnaccrued;
        return adjustedVolumeAccrued[user];
    }

    function userPurchaseStorage(address user, address listingAdd) public returns (SingleItemListing[] memory) {
        SingleItemListing individualListing = SingleItemListing(listingAdd);
        require (msg.sender == address(individualListing));
        require(individualListing.getFactory() == address(this));
        require(checkListingOriginatedHere(individualListing, individualListing.getSeller()));
        userPurchases[user].push(individualListing);
        return userPurchases[user];
    }
    //view functions
    function getSingleUserListings(address user) public view returns(SingleItemListing[] memory) {
        return userListings[user];
    }

    function getSingleUserPurchases(address user) public view returns(SingleItemListing[] memory) {
        return userPurchases[user];
    }

    function checkListingOriginatedHere(SingleItemListing listing, address seller) public view returns(bool) {
        SingleItemListing[] memory sellersListings = getSingleUserListings(seller);
        bool isFromHere = false;
        for (uint256 i; i < sellersListings.length; i++) {
            SingleItemListing individualListing = SingleItemListing(sellersListings[i]);
            if (address(individualListing) == address(listing) && isFromHere == false) {
                isFromHere = true;
            }
        }
        return isFromHere;
    }

    function getActiveListings() public view returns (SingleItemListing[] memory) {
        SingleItemListing[] memory activeListings = new SingleItemListing[](listings.length);
        uint256 count;
        for (uint256 i; i < listings.length; i++) {
            SingleItemListing individualListing = SingleItemListing(listings[i]);
            if (!individualListing.hasTokens() && !individualListing.hasEnded()) {
                activeListings[count++] = individualListing;
            }
        }
        return activeListings;
    }
}
