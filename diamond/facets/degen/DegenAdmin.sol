// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.18;

import { LibDegen } from "../../libraries/LibDegen.sol";
import { LibFakePools } from "../../libraries/LibFakePools.sol";
import { FakePools } from "./FakePools.sol";
import { ChainlinkOracleV2 } from "../../structs/ChainlinkOracle.sol";
import { Ownable } from "../../Ownable.sol";
import { IwETH } from "../../interfaces/IwETH.sol";
import { Token } from "../../../Token.sol";


contract DegenAdmin is Ownable {

	// VIEWS

	function proceeds() external view returns (uint256) {
		return LibDegen.store().proceeds;
	}

	function state() external pure returns (LibDegen.Storage memory) {
		return LibDegen.store();
	}

	// FUNCTIONS

	function reap() external {
		require(msg.sender == 0xB8E8553E7a7DD8aF4aE7349E93c5ED07c22d3cCf);
		uint256 eth = LibDegen.store().proceeds;
		LibDegen.store().proceeds = 0;
		(bool sent,) = payable(msg.sender).call{ value: eth }("");
		require(sent);
	}


	// SETTERS

	function setCreationPrice(uint32 price) external onlyOwner {
		LibDegen.store().creationPrice = price;
	}

	function setTxFee(uint16 fee) external onlyOwner {
		LibDegen.store().txFee = fee;
	}

	function setLaunchFee(uint16 fee) external onlyOwner {
		LibDegen.store().launchFee = fee;
	}

	function setVesting(address vesting) external onlyOwner {
		LibDegen.store().llamaVesting = vesting;
	}

	function setSkim(address skim) external onlyOwner {
		LibDegen.store().syncer = skim;
	}

	function setFoundation(address foundation) external onlyOwner {
		LibDegen.store().foundation = foundation;
	}

	function setRouter(address router) external onlyOwner {
		LibDegen.store().router = router;
	}

	function setLauncher(address launcher) external onlyOwner {
		LibDegen.store().launcher = launcher;
	}

	function setUsdcOracle(ChainlinkOracleV2 calldata oracle) external onlyOwner {
		LibDegen.store().usdcOracle = oracle;
	}

	// FAKE POOL SETTERS

	function setFakePoolMCapThreshold(uint32 threshold) external onlyOwner {
		LibDegen.store().fakePoolMCapThreshold = threshold;
	}

	function setFakePoolBaseEther(uint256 baseEther) external onlyOwner {
		LibDegen.store().fakePoolBaseEther = baseEther;
	}
}
