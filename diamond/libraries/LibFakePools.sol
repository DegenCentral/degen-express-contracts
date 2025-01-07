// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.20;

library LibFakePools {
	bytes32 constant STORAGE_POSITION = keccak256("diamond.fakepools.storage");

	struct FakePool {
		address token;
		uint256 fakeEth;
		uint256 ethReserve;
		uint256 tokenReserve;
	}

	struct Storage {
		uint256 fakeEth;
		uint256 usdMcapThreshold;

		mapping(address => FakePool) pools;
	}

	function store() internal pure returns (Storage storage s) {
		bytes32 position = STORAGE_POSITION;
		assembly { s.slot := position }
	}
}
