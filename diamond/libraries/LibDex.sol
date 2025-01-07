// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.20;

// Contracts/Libraries/Modifiers
import { Equalizer } from "../facets/degen/dexes/Equalizer.sol";
import { Shadow } from "../facets/degen/dexes/Shadow.sol";


library LibDex {
	enum Dex {
		Equalizer,
		Shadow
	}

	function getPair(Dex dex, address token) internal view returns (address pair) {
		if (dex == Dex.Shadow) {
			pair = Shadow(address(this)).shadow_pairFor(token);
		} else if (dex == Dex.Equalizer) {
			pair = Equalizer(address(this)).equal_pairFor(token);
		}
	}

	function addLiquidty(Dex dex, address token, uint256 ethAmount, uint256 tokenAmount) internal {
		if (dex == Dex.Shadow) {
			Shadow(address(this)).shadow_addLiquidty(token, ethAmount, tokenAmount);
		} else if (dex == Dex.Equalizer) {
			Equalizer(address(this)).equal_addLiquidty(token, ethAmount, tokenAmount);
		}
	}

	function decreaseLiquidity(Dex dex, address token, uint256 ethAmount) internal {
		if (dex == Dex.Shadow) {
			Shadow(address(this)).shadow_decreaseLiquidity(token, ethAmount);
		} else if (dex == Dex.Equalizer) {
			Equalizer(address(this)).equal_decreaseLiquidity(token, ethAmount);
		}
	}

}
