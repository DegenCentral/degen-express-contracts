// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.20;

library LibLST {
	struct Storage {
		uint256 staked;
		uint256 buffered;
	}

	uint256 constant private BUFFER = 20_000 ether;

	function store() internal pure returns (Storage storage s) {
		bytes32 position = keccak256("diamond.lst.storage");
		assembly { s.slot := position }
	}

	function stake(uint256 amount) internal {
		// TODO: stake
		store().staked += amount;
	}

	function addLiquidity(uint256 ethAmount) internal {
		store().buffered += ethAmount;

		if (store().buffered >= BUFFER) {
			uint256 surplus = store().buffered - BUFFER;
			stake(surplus);
			store().buffered -= surplus;
		}
	}

	function unstake(uint256 amount) internal {
		// TODO: unstake
		store().staked -= amount;
	}

	function removeLiquidity(uint256 ethAmount) internal {
		if (store().buffered >= ethAmount) {
			store().buffered -= ethAmount;
		} else {
			uint256 diff = ethAmount - store().buffered;
			uint256 fillup = BUFFER / 2;
			unstake(diff + fillup);
			store().buffered = fillup;
		}
	}

}