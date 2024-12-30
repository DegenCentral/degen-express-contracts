// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.18;

// Facets
import { EqualizerLpHandler } from "../facets/degen/dexes/EqualizerLpHandler.sol";


library LibDex {
	enum Dex {
		Equalizer,
		Shadow
	}

	function getPair(Dex dex, address token) internal view returns (address pair) {
		if (dex == Dex.Shadow) {
			// TODO shadow
			pair = address(0);
		} else if (dex == Dex.Equalizer) {
			pair = EqualizerLpHandler(address(this)).equal_pairFor(token);
		}
	}

	function addLiquidty(Dex dex, address token, uint256 ethAmount, uint256 tokenAmount) internal {
		if (dex == Dex.Shadow) {
			// TODO shadow
			revert("shadow not supported");
		} else if (dex == Dex.Equalizer) {
			EqualizerLpHandler(address(this)).equal_addLiquidty(token, ethAmount, tokenAmount);
		}
	}

	function removeLiquidity(Dex dex, address token) internal {
		// TODO
	}

	function decreaseLiquidity(Dex dex, address token, uint256 amount) internal {
		if (dex == Dex.Shadow) {
			// TODO shadow
		} else if (dex == Dex.Equalizer) {
			EqualizerLpHandler(address(this)).equal_decreaseLiquidity(token, amount);
		}
	}

}
