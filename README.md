# _underscore
underscore is an uncensorable protocol for trading real world items. 

Buyers and sellers agree upon an arbitrator before using the protocol and are able to 
raise issues to the arbitrator in case of either party acting in bad faith.

This structure allows for any number of dedicated crypto marketplaces to arise without
the threat of censorship by external actors. Crypto-currency can now be used as an actual
currency spendable on real world items, rather than being limited to a store of value.

##SingleItemListingFactory.sol

This is the core storage and listing generation contract. Listings may be spun up from 
this factory with a mandatory third party arbitrator. This arbitrator could be a
DAO such as Kleros or a trusted indvidual within the community.

##SingleItemListing.sol

This listing is effectively a soul-bound contract for the seller, and is permanently
stored in the factory contract labeled by seller. Upon purchase the buyer's address
is stored alongside the seller. 
