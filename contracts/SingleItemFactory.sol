// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.11;

import {Ownable} from "../openzeppelin/Ownable.sol";
import {SingleItemListing} from "./SingleItemListing.sol";

contract SingleItemFactory is Ownable {
    uint256 public protocolFee = 750; // in bps
    uint256 public arbitratorFee = 100; // in bps
    address public admin;
    SingleItemListing[] public listings;
    mapping(address => SingleItemListing[]) userListings;

    constructor() {
        admin = msg.sender;
    }

    function transferAdmin(address newAdmin) public {
        require(msg.sender == admin); 
        admin = newAdmin;
    }

    event ListingCreated(address listingAddress, address tokenWanted, uint256 amountWanted);

    function setProtocolFee(uint256 _newProtocolFee) public onlyOwner {
        protocolFee = _newProtocolFee;
    }
    
    function setArbitratorFee(uint256 _newArbitratorFee) public onlyOwner {
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
            desc
        );
        listings.push(listing);
        userListings[msg.sender].push(listing);
        emit ListingCreated(address(listing), _tokenWanted, _amountWanted);
        return listing;
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

    function getactiveListingsByRange(uint256 start, uint256 end) public view returns (SingleItemListing[] memory) {
        SingleItemListing[] memory activeListings = new SingleItemListing[](end - start);

        uint256 count;
        for (uint256 i = start; i < end; i++) {
            if (listings[i].hasTokens() && !listings[i].hasEnded()) {
                activeListings[count++] = listings[i];
            }
        }

        return activeListings;
    }

    function getLength() public view returns (uint) {
        return listings.length;
    }
}
