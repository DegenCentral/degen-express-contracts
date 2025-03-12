// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.20;

// Contracts/Libraries/Modifiers
import { LibCore } from "../../libraries/LibCore.sol";
import { LibFakePools } from "../../libraries/LibFakePools.sol";
import { LibTokens } from "../../libraries/LibTokens.sol";
import { LibDex } from "../../libraries/LibDex.sol";
import { LibUsd } from "../../libraries/LibUsd.sol";
import { Ownable } from "../../Ownable.sol";

import { Token } from "../../../Token.sol";


interface IwETH {
	function deposit() external payable;
	function withdraw(uint256 value) external;
}

contract Admin is Ownable {

	function reap() external onlyOwner {
		uint256 proceeds = LibCore.store().proceeds;
		LibCore.store().proceeds = 0;
		(bool sent,) = LibCore.store().proceedsReceiver.call{ value: proceeds }("");
		require(sent);
	}

	// EXTERNAL

	function donate() external payable {
		LibCore.store().proceeds += msg.value;
	}

	// SETTERS

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
