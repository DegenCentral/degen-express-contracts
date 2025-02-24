// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.20;

// Contracts/Libraries/Modifiers
import { LibCore } from "../../libraries/LibCore.sol";
import { Ownable } from "../../Ownable.sol";

// Facets
import { Core } from "./Core.sol";


contract Buyback is Ownable {

	function buybackProgress() external view returns (uint256) {
		uint256 proceeds = LibCore.store().proceeds;
		uint256 buybackProceeds = proceeds / 3;
		return buybackProceeds;
	}

	event BoughtBack(address token, uint256 amount);

	function buyback(address token, uint256 amount) external onlyOwner {
		require(LibCore.store().proceeds >= amount, "Buyback: insufficient proceeds");
		LibCore.store().proceeds -= amount;
		
		Core(address(this))._buy(address(0x000000000000000000000000000000000000dEaD), token, amount, 1, block.timestamp);

		emit BoughtBack(token, amount);
	}

	event BoughtBackSponsored(address token, uint256 amount);

	function sponsoredBuyback(address token) external payable onlyOwner {
		Core(address(this))._buy(address(0x000000000000000000000000000000000000dEaD), token, msg.value, 1, block.timestamp);
		emit BoughtBackSponsored(token, msg.value);
	}

}
