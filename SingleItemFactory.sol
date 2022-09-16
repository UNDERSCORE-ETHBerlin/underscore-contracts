// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.11;

contract SingleItemFactory {
    address admin;
    constructor() {
        admin = msg.sender;
    }
}