// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.20;

import { IChainlinkAggregatorV3 } from "./diamond/interfaces/IChainlinkAggregatorV3.sol";
import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

interface Pyth {
	struct Price {
		// Price
		int64 price;
		// Confidence interval around the price
		uint64 conf;
		// Price exponent
		int32 expo;
		// Unix timestamp describing when the price was published
		uint publishTime;
	}
	
	function getPriceNoOlderThan(bytes32 feedId, uint256 maxAge) external view returns (Price memory);
}

contract FakeFeed is IChainlinkAggregatorV3 {

	function latestRoundData()
		external
		view
		override
		returns (
			uint80 roundId,
			int256 answer,
			uint256 startedAt,
			uint256 updatedAt,
			uint80 answeredInRound
		)
	{
		Pyth.Price memory price = Pyth(0x2880aB155794e7179c9eE2e38200202908C17B43).getPriceNoOlderThan(0xf490b178d0c85683b7a0f2388b40af2e6f7c90cbe0f96b31f315f08d0e5a2d6d, 60);

		return (
			uint80(price.publishTime),
			price.price,
			price.publishTime,
			price.publishTime,
			uint80(price.publishTime)
		);
	}

}