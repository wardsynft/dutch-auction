// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";
import { DutchAuction } from "../src/DutchAuction.sol";
import { MockDutchAuction } from "./mocks/MockDutchAuction.sol";

contract DutchAuctionTest is Test {
    DutchAuction public dutchAuction;

    function setUp() public {
        dutchAuction = new MockDutchAuction();
    }
}
