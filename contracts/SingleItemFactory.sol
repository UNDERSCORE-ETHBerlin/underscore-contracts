// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.11;

import {Ownable} from "../openzeppelin/Ownable.sol";
import {SingleItemListing} from "./SingleItemListing.sol";

contract SingleItemFactory is Ownable {
    uint256 public protocolFee = 750; // in bps
    uint256 public arbitratorFee = 100; // in bps
    address public arbitrator;
    ItemListing[] public listings;
    mapping(address => ItemListing[]) userListings;

    constructor() {
        arbitrator = msg.sender;
    }

    event ListingCreated(address offerAddress, address tokenWanted, uint256 amountWanted);

    function setFee(uint256 _fee) public onlyOwner {
        fee = _fee;
    }

    function createListing(address _tokenWanted, uint256 _amountWanted, string memory imageURL, string memory name, string memory desc) public returns (ItemListing) {
        ItemListing listing = new SingleItemListing(msg.sender, _tokenWanted, arbitrator, _amountWanted, protocolFee, arbitratorFee);
        listings.push(listing);
        userListings(msg.sender).push(listing);
        emit ListingCreated(address(listing), _tokenWanted, _amountWanted);
        return listing;
    }

    function getActiveListingsByOwner() public view returns (ItemListing[] memory, ItemListing[] memory) {
        ItemListing[] memory myBids = new ItemListing[](listings.length);
        ItemListing[] memory otherBids = new ItemListing[](listings.length);

        uint256 myBidsCount;
        uint256 otherBidsCount;
        for (uint256 i; i < listings.length; i++) {
            ItemListing listing = ItemListing(listings[i]);
            if (listing.hasTokens() && !listing.hasEnded()) {
                if (listing.seller() == msg.sender) {
                    myBids[myBidsCount++] = listings[i];
                }
            }
        }

        return (myBids);
    }

    function getActiveListings() public view returns (ItemListing[] memory) {
        ItemListing[] memory activeListings = new ItemListing[](listings.length);
        uint256 count;
        for (uint256 i; i < listings.length; i++) {
            ItemListing offer = ItemListing(listings[i]);
            if (!offer.hasEnded()) {
                activeListings[count++] = offer;
            }
        }

        return activeListings;
    }

    function getactiveListingsByRange(uint256 start, uint256 end) public view returns (ItemListing[] memory) {
        ItemListing[] memory activeListings = new ItemListing[](end - start);

        uint256 count;
        for (uint256 i = start; i < end; i++) {
            if (listings[i].hasTokens() && !listings[i].hasEnded()) {
                activeListings[count++] = listings[i];
            }
        }

        return activeListings;
    }

    function getLen() public view returns (uint) {
        return listings.length;
    }
}
