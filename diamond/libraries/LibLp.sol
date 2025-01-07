// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.20;

// Facets
import { Equalizer } from "../facets/degen/dexes/Equalizer.sol";


library LibLp {
	struct Storage {
		mapping (address => address) equal_amm_positions;
		mapping (address => uint256) shadow_cl_positions;
	}

	function store() internal pure returns (Storage storage s) {
		bytes32 position = keccak256("diamond.lp.storage");
		assembly { s.slot := position }
	}

}
