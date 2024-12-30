// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.18;

import { IChainlinkAggregatorV3 } from "./diamond/interfaces/IChainlinkAggregatorV3.sol";
import { LibPRNG } from "solady/src/utils/LibPRNG.sol";
import "hardhat/console.sol";

interface StorkAdapter {
	struct TemporalNumericValue {
		// nanosecond level precision timestamp of latest publisher update in batch
		uint64 timestampNs; // 8 bytes
		// should be able to hold all necessary numbers (up to 6277101735386680763835789423207666416102355444464034512895)
		int192 quantizedValue; // 8 bytes
	}

	function getTemporalNumericValueUnsafeV1(bytes32 id) external view returns (TemporalNumericValue memory);
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
		StorkAdapter.TemporalNumericValue memory value = StorkAdapter(0xacC0a0cF13571d30B4b8637996F5D6D774d4fd62)
			.getTemporalNumericValueUnsafeV1(0xa92378ae3a5481a05b527359ddb32eb4a45ca01729cfc0ca61aa88f592a94bf6);
		roundId = uint80(value.timestampNs);

		return (
			roundId,
			value.quantizedValue / 10**10,
			value.timestampNs,
			value.timestampNs,
			roundId
		);
	}

}