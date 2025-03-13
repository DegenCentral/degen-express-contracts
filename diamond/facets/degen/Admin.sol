// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.20;

// Contracts/Libraries/Modifiers
import { LibDiamond } from "../../libraries/LibDiamond.sol";
import { LibCore } from "../../libraries/LibCore.sol";
import { LibFakePools } from "../../libraries/LibFakePools.sol";
import { LibTokens } from "../../libraries/LibTokens.sol";
import { LibDex } from "../../libraries/LibDex.sol";
import { LibUsd } from "../../libraries/LibUsd.sol";
import { Ownable } from "../../Ownable.sol";

import { Token } from "../../../Token.sol";


contract Admin is Ownable {

	function reap() external onlyOwner {
		uint256 proceeds = LibCore.store().proceeds;

		require(proceeds > 10 ether);
		proceeds = proceeds - 10 ether; // keep a min for various fees
		LibCore.store().proceeds = 10 ether;

		(bool sent,) = LibCore.store().proceedsReceiver.call{ value: proceeds }("");
		require(sent);
	}

	// EXTERNAL

	function donate() external payable {
		LibCore.store().proceeds += msg.value;
	}

	// SETTERS

	function setHalted(bool halted) external onlyOwner {
		LibDiamond.diamondStorage().halted = halted;
	}

	function setProceedsReceiver(address receiver) external onlyOwner {
		LibCore.store().proceedsReceiver = receiver;
	}

	function setCreationPrice(uint256 price) external onlyOwner {
		LibCore.store().creationPrice = price;
	}

	function setTradeFee(uint16 fee) external onlyOwner {
		require(fee <= 500);
		LibCore.store().tradeFee = fee;
	}

	function setUsdOracle(address priceFeed, uint256 heartBeat) external onlyOwner {
		LibUsd.store().usdOracle = LibUsd.ChainlinkOracle(priceFeed, heartBeat);
	}

	// FAKE POOL SETTERS

	function setFakePoolFakeEth(uint256 fakeEth) external onlyOwner {
		LibFakePools.store().fakeEth = fakeEth;
	}

	function setFakePoolMCapThreshold(uint256 threshold) external onlyOwner {
		LibFakePools.store().usdMcapThreshold = threshold;
	}

}
