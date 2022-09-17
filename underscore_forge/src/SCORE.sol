// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

import { ERC20 }       from "./openzeppelin/ERC20.sol";
import { ISCORE } from "./ISCORE.sol";
import { SafeERC20 } from "./openzeppelin/SafeERC20.sol";
import { Ownable } from "./openzeppelin/Ownable.sol";
contract SCORE is ERC20 {

    uint256 public immutable precision;  // Precision of rates, equals max deposit amounts before rounding errors occur

    address public asset;  // Underlying ERC-20 asset used by ERC-4626 functionality.
    address public owner;         // Current owner of the contract, able to update the vesting schedule.
    address public pendingOwner;  // Pending owner of the contract, able to accept ownership.

    uint256 public freeAssets;           // Amount of assets unlocked regardless of time passed.
    uint256 public issuanceRate;         // asset/second rate dependent on aggregate vesting schedule.
    uint256 public lastUpdated;          // Timestamp of when issuance equation was last updated.
    uint256 public vestingPeriodFinish;  // Timestamp when current vesting schedule ends.

    uint256 private locked = 1;  // Used in reentrancy check.

    /*****************/
    /*** Modifiers ***/
    /*****************/

    modifier nonReentrant() {
        require(locked == 1, "RDT:LOCKED");

        locked = 2;

        _;

        locked = 1;
    }

    constructor(string memory name_, string memory symbol_, address owner_, address asset_, uint256 precision_)
        ERC20(name_, symbol_, ERC20(asset_).decimals(), owner_)
    {
        require((owner = owner_) != address(0), "RDT:C:OWNER_ZERO_ADDRESS");

        asset     = asset_;  // Don't need to check zero address as ERC20(asset_).decimals() will fail in ERC20 constructor.
        precision = precision_;
    }

    /********************************/
    /*** Administrative Functions ***/
    /********************************/

    function acceptOwnership() external virtual {
        require(msg.sender == pendingOwner, "RDT:AO:NOT_PO");
        owner        = msg.sender;
        pendingOwner = address(0);
    }

    function setPendingOwner(address pendingOwner_) external virtual {
        require(msg.sender == owner, "RDT:SPO:NOT_OWNER");

        pendingOwner = pendingOwner_;
    }

    function updateVestingSchedule(uint256 vestingPeriod_) external virtual returns (uint256 issuanceRate_, uint256 freeAssets_) {
        
        require(msg.sender == owner, "RDT:UVS:NOT_OWNER");
        require(totalSupply() != 0,    "RDT:UVS:ZERO_SUPPLY");

        // Update "y-intercept" to reflect current available asset.
        freeAssets_ = freeAssets = totalAssets();

        // Calculate slope.
        issuanceRate_ = issuanceRate = ((ERC20(asset).balanceOf(address(this)) - freeAssets_) * precision) / vestingPeriod_;

        // Update timestamp and period finish.
        vestingPeriodFinish = (lastUpdated = block.timestamp) + vestingPeriod_;

        return (issuanceRate_, freeAssets_);
    }

    /************************/
    /*** Staker Functions ***/
    /************************/

    function deposit(uint256 assets_, address receiver_) external virtual nonReentrant returns (uint256 shares_) {
        _mint(shares_ = previewDeposit(assets_), assets_, receiver_, msg.sender);
    }

    function mint(uint256 shares_, address receiver_) external virtual nonReentrant returns (uint256 assets_) {
        _mint(shares_, assets_ = previewMint(shares_), receiver_, msg.sender);
    }

    function redeem(uint256 shares_, address receiver_, address owner_) external virtual nonReentrant returns (uint256 assets_) {
        _burn(shares_, assets_ = previewRedeem(shares_), receiver_, owner_, msg.sender);
    }

    function withdraw(uint256 assets_, address receiver_, address owner_) external virtual nonReentrant returns (uint256 shares_) {
        _burn(shares_ = previewWithdraw(assets_), assets_, receiver_, owner_, msg.sender);
    }

    /**************************/
    /*** Internal Functions ***/
    /**************************/

    function _mint(uint256 shares_, uint256 assets_, address receiver_, address caller_) internal {
        require(receiver_ != address(0), "RDT:M:ZERO_RECEIVER");
        require(shares_   != uint256(0), "RDT:M:ZERO_SHARES");
        require(assets_   != uint256(0), "RDT:M:ZERO_ASSETS");

        _mint(receiver_, shares_);

        uint256 freeAssetsCache = freeAssets = totalAssets() + assets_;

        uint256 issuanceRate_ = _updateIssuanceParams();

        SafeERC20.safeTransferFrom(ERC20(asset), caller_, address(this), assets_);
    }

    function _burn(uint256 shares_, uint256 assets_, address receiver_, address owner_, address caller_) internal {
        require(receiver_ != address(0), "RDT:B:ZERO_RECEIVER");
        require(shares_   != uint256(0), "RDT:B:ZERO_SHARES");
        require(assets_   != uint256(0), "RDT:B:ZERO_ASSETS");

        if (caller_ != owner_) {
            decreaseAllowance(caller_, shares_);
        }

        _burn(owner_, shares_);

        uint256 freeAssetsCache = freeAssets = totalAssets() - assets_;

        uint256 issuanceRate_ = _updateIssuanceParams();

        SafeERC20.safeTransfer(ERC20(asset), receiver_, assets_);
    }

    function _updateIssuanceParams() internal returns (uint256 issuanceRate_) {
        return issuanceRate = (lastUpdated = block.timestamp) > vestingPeriodFinish ? 0 : issuanceRate;
    }

    /**********************/
    /*** View Functions ***/
    /**********************/

    function balanceOfAssets(address account_, address token) public view returns (uint256 balanceOfAssets_) {
        return convertToAssets(ERC20(token).balanceOf(account_));
    }

    function convertToAssets(uint256 shares_) public view virtual returns (uint256 assets_) {
        uint256 supply = totalSupply();  // Cache to stack.

        assets_ = supply == 0 ? shares_ : (shares_ * totalAssets()) / supply;
    }

    function convertToShares(uint256 assets_) public view virtual returns (uint256 shares_) {
        uint256 supply = totalSupply();  // Cache to stack.

        shares_ = supply == 0 ? assets_ : (assets_ * supply) / totalAssets();
    }

    function maxDeposit(address receiver_) external pure virtual returns (uint256 maxAssets_) {
        receiver_;  // Silence warning
        maxAssets_ = type(uint256).max;
    }

    function maxMint(address receiver_) external pure virtual returns (uint256 maxShares_) {
        receiver_;  // Silence warning
        maxShares_ = type(uint256).max;
    }

    function maxWithdraw(address owner_) external view virtual returns (uint256 maxAssets_) {
        maxAssets_ = balanceOfAssets(owner_, asset);
    }

    function previewDeposit(uint256 assets_) public view virtual returns (uint256 shares_) {
        // As per https://eips.ethereum.org/EIPS/eip-4626#security-considerations,
        // it should round DOWN if it’s calculating the amount of shares to issue to a user, given an amount of assets provided.
        shares_ = convertToShares(assets_);
    }

    function previewMint(uint256 shares_) public view virtual returns (uint256 assets_) {
        uint256 supply = totalSupply();  // Cache to stack.

        // As per https://eips.ethereum.org/EIPS/eip-4626#security-considerations,
        // it should round UP if it’s calculating the amount of assets a user must provide, to be issued a given amount of shares.
        assets_ = supply == 0 ? shares_ : _divRoundUp(shares_ * totalAssets(), supply);
    }

    function previewRedeem(uint256 shares_) public view virtual returns (uint256 assets_) {
        // As per https://eips.ethereum.org/EIPS/eip-4626#security-considerations,
        // it should round DOWN if it’s calculating the amount of assets to send to a user, given amount of shares returned.
        assets_ = convertToAssets(shares_);
    }

    function previewWithdraw(uint256 assets_) public view virtual returns (uint256 shares_) {
        uint256 supply = totalSupply();  // Cache to stack.

        // As per https://eips.ethereum.org/EIPS/eip-4626#security-considerations,
        // it should round UP if it’s calculating the amount of shares a user must return, to be sent a given amount of assets.
        shares_ = supply == 0 ? assets_ : _divRoundUp(assets_ * supply, totalAssets());
    }

    function totalAssets() public view virtual returns (uint256 totalManagedAssets_) {
        uint256 issuanceRate_ = issuanceRate;

        if (issuanceRate_ == 0) return freeAssets;

        uint256 vestingPeriodFinish_ = vestingPeriodFinish;
        uint256 lastUpdated_         = lastUpdated;

        uint256 vestingTimePassed =
            block.timestamp > vestingPeriodFinish_ ?
                vestingPeriodFinish_ - lastUpdated_ :
                block.timestamp - lastUpdated_;

        return ((issuanceRate_ * vestingTimePassed) / precision) + freeAssets;
    }

    /**************************/
    /*** Internal Functions ***/
    /**************************/

    function _divRoundUp(uint256 numerator_, uint256 divisor_) internal pure returns (uint256 result_) {
       return (numerator_ / divisor_) + (numerator_ % divisor_ > 0 ? 1 : 0);
    }

}