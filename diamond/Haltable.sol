// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibDiamond } from "./libraries/LibDiamond.sol";

contract Haltable {
	modifier checkHalted() {
		if (
      LibDiamond.diamondStorage().halted && 
      (tx.origin != LibDiamond.contractOwner() || msg.sender != address(this))
    ) revert();
		_;
	}
}
