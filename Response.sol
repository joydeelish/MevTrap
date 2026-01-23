// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MEVAlertResponder {
    address public owner;
    address public caller;

    event MEVAlert(
        address indexed pair,
        uint256 swapCount,
        uint256 blockNumber
    );

    constructor() {
        owner = msg.sender;
    }

    modifier onlyCaller() {
        require(msg.sender == caller || msg.sender == owner, "not-caller");
        _;
    }

    function setCaller(address c) external {
        require(msg.sender == owner, "!owner");
        caller = c;
    }

    function respondToMEV(
        address pair,
        uint256 swaps,
        uint256 blk
    ) external onlyCaller {
        emit MEVAlert(pair, swaps, blk);
    }
}
