// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.20;

// Contracts/Libraries/Modifiers
import { LibUsd } from "../../libraries/LibUsd.sol";
import { LibLST } from "../../libraries/LibLST.sol";


contract Loupe {

	function lst() external view returns (LibLST.Storage memory) {
		return LibLST.store();
	}

}
