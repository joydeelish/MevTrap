// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITrap {
    function collect() external view returns (bytes memory);
    function shouldRespond(bytes[] calldata collectOutputs)
        external
        pure
        returns (bool, bytes memory);
}

interface IUniswapV2Pair {
    function getReserves()
        external
        view
        returns (uint112 r0, uint112 r1, uint32 blockTimestampLast);
}

/// @title MEV Sandwich Detection Trap
/// @notice Detects sandwich-style MEV via sudden price + volume change
contract MEVSandwichTrap is ITrap {
    address public constant PAIR =
        0x0000000000000000000000000000000000000000; // <-- set pair

    uint256 public constant PRICE_MOVE_BPS = 300; // 3%
    uint256 public constant VOLUME_THRESHOLD = 5e18; // tune per token
    uint256 public constant MAX_BLOCK_GAP = 2;

    /// collect returns:
    /// (reserve0, reserve1, blockNumber)
    function collect() external view override returns (bytes memory) {
        (uint112 r0, uint112 r1,) = IUniswapV2Pair(PAIR).getReserves();
        return abi.encode(uint256(r0), uint256(r1), block.number);
    }

    function shouldRespond(bytes[] calldata samples)
        external
        pure
        override
        returns (bool, bytes memory)
    {
        if (
            samples.length < 2 
            samples[0].length == 0 
            samples[1].length == 0
        ) {
            return (false, bytes(""));
        }

        (uint256 r0a, uint256 r1a, uint256 ba) =
            abi.decode(samples[0], (uint256, uint256, uint256));
        (uint256 r0b, uint256 r1b, uint256 bb) =
            abi.decode(samples[1], (uint256, uint256, uint256));

        // normalize ordering
        bool aLatest = ba >= bb;
        uint256 oldR0 = aLatest ? r0b : r0a;
        uint256 oldR1 = aLatest ? r1b : r1a;
        uint256 newR0 = aLatest ? r0a : r0b;
        uint256 newR1 = aLatest ? r1a : r1b;
        uint256 blockGap = aLatest ? (ba - bb) : (bb - ba);

        if (blockGap > MAX_BLOCK_GAP) return (false, bytes(""));
        if (oldR0 == 0 || oldR1 == 0) return (false, bytes(""));

        // price = r1 / r0 (scaled)
        uint256 oldPrice = (oldR1 * 1e18) / oldR0;
        uint256 newPrice = (newR1 * 1e18) / newR0;

        uint256 priceDelta =
            oldPrice > newPrice ? oldPrice - newPrice : newPrice - oldPrice;

        uint256 priceMoveBps = (priceDelta * 10_000) / oldPrice;

        if (priceMoveBps < PRICE_MOVE_BPS) return (false, bytes(""));

        // volume proxy = reserve deltas
        uint256 vol0 =
            oldR0 > newR0 ? oldR0 - newR0 : newR0 - oldR0;
        uint256 vol1 =
            oldR1 > newR1 ? oldR1 - newR1 : newR1 - oldR1;

        if (vol0 < VOLUME_THRESHOLD && vol1 < VOLUME_THRESHOLD)
            return (false, bytes(""));

        // 🚨 MEV-style behavior detected
        return (
            true,
            abi.encode(
                PAIR,
                priceMoveBps,
                vol0,
                vol1,
                blockGap
            )
        );
    }
}
