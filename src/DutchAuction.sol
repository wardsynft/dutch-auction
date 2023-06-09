// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

abstract contract DutchAuction is ReentrancyGuard {

    error AuctionNotStarted();
    error MaximumPerTransactionExceeded();
    error AuctionBidTooLow();
    error AuctionMaxSupplyReached();
    error RefundsDisabled();
    error BidsAlreadyRefunded();
    error NoRefundRequired();
    error FailedToRefundBids();
    error AlreadyWithdrawn();
    error AuctionInProgress();
    error UnableToWithdraw();

    event BidPlaced(
        address indexed from,
        uint256 amount,
        uint256 price
    );

    event Refunded(
        address indexed from, 
        Bid[] bids, 
        uint256 refundedAmount
    );

    struct Bid {
        uint256 amount;
        uint256 price;
    }

    struct AuctionConfig {
        uint256 startTime;
        uint256 startPrice; // @dev wei
        uint256 endPrice; // @dev wei
        uint256 duration;
        uint256 interval;
        uint256 mintable; // @dev total number of mintable tokens during DA
        uint256 maxPerTx;
    }

    address payable recipient;  
    bool public allowRefunds;
    bool public fundsWithdrawn;
    AuctionConfig public auctionConfig;
    uint256 public totalMinted;
    uint256 finalPrice;
    mapping(address => Bid[]) public bids;
    mapping(address => bool) public bidsRefunded;
    

    constructor(
        AuctionConfig memory _auctionConfig,
        address payable _recipient
    ) {
        auctionConfig = _auctionConfig;
        recipient = _recipient;
    }

    function _setRecipient(address payable _recipient) internal {
        recipient = _recipient;
    }

    function _makeBid(address from, uint256 amount) internal virtual {
        AuctionConfig memory config = auctionConfig;

        if (block.timestamp < config.startTime) {
            revert AuctionNotStarted();
        }

        if (amount > config.maxPerTx) {
            revert MaximumPerTransactionExceeded();
        }

        if (amount + totalMinted > config.mintable) {
            revert AuctionMaxSupplyReached();
        }

        uint256 price = getCurrentPrice();
        if (msg.value < amount * price) {
            revert AuctionBidTooLow();
        }

        if (totalMinted + amount == config.mintable) {
            finalPrice = price;
        }

        totalMinted += amount;
        bids[from].push(Bid(amount, price));
        _delegateBid(from, amount, price);
        emit BidPlaced(from, amount, price);
    }

    // @dev will delegate the functionality of handling a bid to the contract
    // inheriting this.
    function _delegateBid(
        address from,
        uint256 amount,
        uint256 price
    ) internal virtual;

    function getCurrentPrice() public view returns (uint256) {
        AuctionConfig memory config = auctionConfig;
        
        if (block.timestamp < config.startTime) {
            return config.startPrice;
        }

        if (block.timestamp - config.duration >= config.startTime) {
            return config.endPrice;
        }

        uint256 numSteps = (block.timestamp - config.startTime) / config.interval;
        return config.startPrice - (numSteps * _getPriceReductionPerStep());
    }

    function toggleAllowRefunds(bool _allowRefunds) internal {
        allowRefunds = _allowRefunds;
    }

    function claimRefund() external {
        if (!allowRefunds) {
            revert RefundsDisabled();
        }

        if (bidsRefunded[msg.sender]) {
            revert BidsAlreadyRefunded();
        }

        Bid[] memory senderBids = bids[msg.sender];
        uint256 refundAmount = 0;
        for (uint i = 0; i < senderBids.length; i++) {
            Bid memory bid = senderBids[i];
            refundAmount += (bid.price - finalPrice) * bid.amount; // @dev check for negatives
        }
        bidsRefunded[msg.sender] = true;
        if (refundAmount == 0) {
            revert NoRefundRequired();
        }
        emit Refunded(msg.sender, senderBids, refundAmount);
        (bool success, ) = msg.sender.call{value: refundAmount}("");
        if (!success) {
            revert FailedToRefundBids();
        }
    }

    function withdraw() internal nonReentrant {
        if (fundsWithdrawn) {
            revert AlreadyWithdrawn();
        }

        if (finalPrice == 0) {
            revert AuctionInProgress();
        }
        uint256 withdrawAmount = totalMinted * finalPrice;
        fundsWithdrawn = true;
        (bool success, ) =  recipient.call{value: withdrawAmount}("");
        if (!success) {
            revert UnableToWithdraw();
        }
    }

    // @dev this method will calculate the reduction in cost per step.
    function _getPriceReductionPerStep() internal view returns (uint256) {
        return (auctionConfig.startPrice - auctionConfig.endPrice) / 
            (auctionConfig.duration / auctionConfig.interval);
    }

    function _getBidsFromAddress(address from) external view returns (Bid[] memory) {
        return bids[from];
    }
}