// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.20;

import { LibUtils } from "./LibUtils.sol";

library LibCore {
	bytes32 constant STORAGE_POSITION = keccak256("diamond.core.storage");

	struct Storage {
		uint256 proceeds;

		uint256 creationPrice;

		uint16 tradeFee;

		uint256 tokenSupply;

		address proceedsReceiver;
	}

	function store() internal pure returns (Storage storage s) {
		bytes32 position = STORAGE_POSITION;
		assembly { s.slot := position }
	}

	function gatherProceeds(uint256 amount) internal {
		store().proceeds += amount;
	}

	function calculateTradeFee(uint256 eth) internal view returns (uint256) {
		return LibUtils.calculatePercentage(store().tradeFee, eth);
	}

	function deductTradeFee(uint256 eth) internal returns (uint256) {
		uint256 fee = calculateTradeFee(eth);
		gatherProceeds(fee);
		return eth - fee;
	}
}
