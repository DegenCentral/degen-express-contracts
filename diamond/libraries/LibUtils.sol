// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.18;

import { IAggregatorV3 } from "../interfaces/IAggregatorV3.sol";
import { ChainlinkOracleV2 } from "../structs/ChainlinkOracle.sol";

library LibUtils {

	function calculatePercentage(uint16 fee, uint256 amount) internal pure returns (uint256) {
		return amount * fee / 1000;
	}

	function ethToUsd(uint256 usdcEthPrice, uint256 amountEth) internal pure returns (uint256) {
		uint256 ethAmount = amountEth;
		return ((ethAmount * usdcEthPrice) / (10**(8+18)) / (10**18));
	}

	function usdToEth(uint256 usdcEthPrice, uint256 usdAmount) internal pure returns (uint256) {
		return ((10**18 * (10**8)) / usdcEthPrice) * usdAmount;
	}

	function getOraclePrice(ChainlinkOracleV2 storage oracle) internal returns (uint256) {
		(
			uint256 price,
			uint64 timeStamp
		) = IAggregatorV3(oracle.priceFeed).latestPrice();

		require(price > 0, "Negative Oracle Price");
		require(timeStamp >= block.timestamp - oracle.heartBeat, "Stale pricefeed");

		return price;
	}

}
