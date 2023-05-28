// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { DutchAuction } from "../../src/DutchAuction.sol";

contract MockDutchAuction is DutchAuction {
    mapping(address => uint256) private balances;

    constructor()
        DutchAuction(
            AuctionConfig({
                startTime: block.timestamp,
                startPrice: 0.5 ether,
                endPrice: 0.1 ether,
                duration: 4 hours,
                interval: 30 minutes,
                mintable: 10,
                maxPerTx: 3
            }),
            payable(address(this))
        )   
    {}

    function makeBid(uint256 amount) external payable {
        _makeBid(msg.sender, amount);
    }

    function _delegateBid(
        address from,
        uint256 amount,
        uint256 price
    ) internal override {
        balances[from] += amount * price;
    }

    function balanceOf(address _address) public view returns (uint256) {
        return balances[_address];
    }
}