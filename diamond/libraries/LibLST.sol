// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.20;

library LibLST {
	struct Storage {
		uint256 staked;
	}

	function store() internal pure returns (Storage storage s) {
		bytes32 position = keccak256("diamond.lst.storage");
		assembly { s.slot := position }
	}

	function addLiquidity(uint256 ethAmount) internal {
		store().staked += ethAmount;
	}

	function removeLiquidity(uint256 ethAmount) internal {
		store().staked -= ethAmount;
	}

}