// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.20;

import { LibDex } from "./LibDex.sol";

library LibTokens {
	bytes32 constant STORAGE_POSITION = keccak256("diamond.tokens.storage");

	enum LaunchStrategy {
		FakeLiquidity
	}

	struct TokenInfo {
		address creator;
		LaunchStrategy strategy;
		LibDex.Dex dex;
		address pair;
		bool launched;
	}

	struct Storage {
		mapping(address => TokenInfo) tokens;
	}

	function store() internal pure returns (Storage storage s) {
		bytes32 position = STORAGE_POSITION;
		assembly { s.slot := position }
	}

}
