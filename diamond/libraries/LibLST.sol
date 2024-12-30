// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.18;

library LibLST {
	bytes32 constant STORAGE_POSITION = keccak256("diamond.lst.storage");

	struct Storage {
		uint256 staked;
	}

	function store() internal pure returns (Storage storage s) {
		bytes32 position = STORAGE_POSITION;
		assembly { s.slot := position }
	}

	function addLiquidity(uint256 ethAmount) internal {
		store().staked += ethAmount;
	}

	function removeLiquidity(uint256 ethAmount) internal {
		store().staked -= ethAmount;
	}

}