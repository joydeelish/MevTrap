// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MEVAlertResponder {

    event MEVAlert(
        address indexed pair,
        uint256 prevPriceE18,
        uint256 curPriceE18,
        uint256 changeBps,
        uint256 blockNumber
    );

    function respondToMEV(
        address pair,
        uint256 prevPriceE18,
        uint256 curPriceE18,
        uint256 changeBps,
        uint256 blockNumber
    ) external {
        emit MEVAlert(
            pair,
            prevPriceE18,
            curPriceE18,
            changeBps,
            blockNumber
        );
    }
}
