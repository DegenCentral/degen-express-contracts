// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.20;

import { DiamondInit } from "./DiamondInit.sol";
import { LibCore } from "../libraries/LibCore.sol";
import { LibFakePools } from "../libraries/LibFakePools.sol";


contract DegenInit is DiamondInit {
	function init() public override {
		super.init();

		LibCore.Storage storage s = LibCore.store();

		s.creationPrice = 1 ether; // usd

		s.tradeFee = 20;

		s.tokenSupply = 1_000_000_000 ether;

		
		LibFakePools.Storage storage fp = LibFakePools.store();

		fp.usdMcapThreshold = 75_000 ether; // usd
		fp.fakeEth = 5000 ether;
	}
}
