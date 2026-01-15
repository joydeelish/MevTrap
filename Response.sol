// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MEVResponder {
    address public owner;
    address public caller; // TrapConfig address (set after drosera apply)

    event MEVDetected(
        address indexed pair,
        uint256 priceMoveBps,
        uint256 volume0,
        uint256 volume1,
        uint256 blockGap,
        address indexed triggeredBy
    );

    constructor() {
        owner = msg.sender;
    }

    modifier onlyCaller() {
        require(msg.sender == caller || msg.sender == owner, "not-caller");
        _;
    }

    function setCaller(address _caller) external {
        require(msg.sender == owner, "!owner");
        caller = _caller;
    }

    /// @notice Called by Drosera when MEV pattern is detected
    function respondToMEV(
        address pair,
        uint256 priceMoveBps,
        uint256 vol0,
        uint256 vol1,
        uint256 blockGap
    ) external onlyCaller {
        emit MEVDetected(
            pair,
            priceMoveBps,
            vol0,
            vol1,
            blockGap,
            msg.sender
        );
    }
}
