// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.18;

import { IChainlinkAggregatorV3 } from "../interfaces/IChainlinkAggregatorV3.sol";
import { FixedPointMathLib } from "solady/src/utils/FixedPointMathLib.sol";

library LibUsd {
	bytes32 constant STORAGE_POSITION = keccak256("diamond.usd.storage");

	struct ChainlinkOracle {
		address priceFeed;
		uint256 heartBeat;
	}

	struct Storage {
		ChainlinkOracle usdOracle;
	}

	function store() internal pure returns (Storage storage s) {
		bytes32 position = STORAGE_POSITION;
		assembly { s.slot := position }
	}

	function ethToUsd(uint256 ethAmount) internal view returns (uint256) {
		return FixedPointMathLib.mulWad(ethAmount, getPrice());
	}

	function usdToEth(uint256 usdAmount) internal view returns (uint256) {
		return FixedPointMathLib.divWad(usdAmount, getPrice());
	}

	function getPrice() internal view returns (uint256) {
		ChainlinkOracle storage oracle = store().usdOracle;

		(, int256 price, uint256 timeStamp,,) = IChainlinkAggregatorV3(oracle.priceFeed).latestRoundData();

		require(uint256(timeStamp) >= block.timestamp - oracle.heartBeat, "stale pricefeed");

		// usd oracle returns the price in 8 decimals, we want 18
		return uint256(price) * (10 ** 10);
	}

}