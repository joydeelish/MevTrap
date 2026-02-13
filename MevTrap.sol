// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "drosera-contracts/interfaces/ITrap.sol";

interface IUniswapV2Pair {
    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

contract SwapBurstHeuristicTrap is ITrap {

    // ✅ YOUR REAL PAIR
    address public constant PAIR =
        0xa4952b9d99106edC66ebfD44cB42495469c7b231;

    // Trigger if price change > 3%
    uint256 public constant PRICE_IMPACT_BPS = 300;

    // Ignore dust liquidity
    uint256 public constant MIN_RESERVE = 1000;

    struct CollectOutput {
        uint256 blockNumber;
        uint112 r0;
        uint112 r1;
    }

    function collect() external view override returns (bytes memory) {
        uint256 size;
        assembly { size := extcodesize(PAIR) }

        if (size == 0) return bytes("");

        (bool ok, bytes memory ret) = PAIR.staticcall(
            abi.encodeWithSelector(IUniswapV2Pair.getReserves.selector)
        );

        if (!ok || ret.length < 96) return bytes("");

        (uint112 r0, uint112 r1, ) =
            abi.decode(ret, (uint112, uint112, uint32));

        return abi.encode(
            CollectOutput({
                blockNumber: block.number,
                r0: r0,
                r1: r1
            })
        );
    }

    function shouldRespond(bytes[] calldata data)
        external
        pure
        override
        returns (bool, bytes memory)
    {
        if (data.length < 2) return (false, bytes(""));
        if (data[0].length == 0 || data[1].length == 0)
            return (false, bytes(""));

        CollectOutput memory a =
            abi.decode(data[0], (CollectOutput));
        CollectOutput memory b =
            abi.decode(data[1], (CollectOutput));

        CollectOutput memory cur =
            (a.blockNumber >= b.blockNumber) ? a : b;
        CollectOutput memory prev =
            (a.blockNumber >= b.blockNumber) ? b : a;

        if (cur.blockNumber == prev.blockNumber)
            return (false, bytes(""));

        if (cur.blockNumber - prev.blockNumber > 2)
            return (false, bytes(""));

        if (
            cur.r0 < MIN_RESERVE ||
            cur.r1 < MIN_RESERVE ||
            prev.r0 < MIN_RESERVE ||
            prev.r1 < MIN_RESERVE
        ) return (false, bytes(""));

        uint256 prevPrice =
            (uint256(prev.r1) * 1e18) / uint256(prev.r0);
        uint256 curPrice =
            (uint256(cur.r1) * 1e18) / uint256(cur.r0);

        if (prevPrice == 0) return (false, bytes(""));

        uint256 diff =
            (curPrice > prevPrice)
                ? (curPrice - prevPrice)
                : (prevPrice - curPrice);

        uint256 changeBps =
            (diff * 10_000) / prevPrice;

        if (changeBps <= PRICE_IMPACT_BPS)
            return (false, bytes(""));

        bool r0Up = cur.r0 > prev.r0;
        bool r1Up = cur.r1 > prev.r1;

        if (r0Up == r1Up)
            return (false, bytes(""));

        return (
            true,
            abi.encode(
                PAIR,
                prevPrice,
                curPrice,
                changeBps,
                cur.blockNumber
            )
        );
    }

    function version() external pure override returns (string memory) {
        return "SwapBurstHeuristicTrap v1.0";
    }
}
