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

contract Admin is Ownable {

	// VIEWS

	function state() external pure returns (LibCore.Storage memory) {
		return LibCore.store();
	}

	// EXTERNAL

	function reap() external {
		uint256 proceeds = LibCore.store().proceeds;
		(bool sent,) = LibCore.store().proceedsReceiver.call{ value: proceeds }("");
		require(sent);
		LibCore.store().proceeds = 0;
	}

	function addToken(address token, address creator, LibTokens.LaunchStrategy strategy, LibDex.Dex dex, address pair) external onlyOwner {
		LibTokens.store().tokens[token] = LibTokens.TokenInfo(
			creator,
			strategy,
			dex,
			pair
		);
	}

	// SETTERS

	function setProceedsReceiver(address receiver) external onlyOwner {
		LibCore.store().proceedsReceiver = receiver;
	}

	function setCreationPrice(uint256 price) external onlyOwner {
		LibCore.store().creationPrice = price;
	}

	function setTradeFee(uint16 fee) external onlyOwner {
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
