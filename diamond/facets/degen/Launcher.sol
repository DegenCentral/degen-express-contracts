// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.20;

// Contracts/Libraries/Modifiers
import { LibDex } from "../../libraries/LibDex.sol";
import { LibUtils } from "../../libraries/LibUtils.sol";
import { LibTokens } from "../../libraries/LibTokens.sol";
import { LpTreasury } from "./LpTreasury.sol";
import { Diamondable } from "../../Diamondable.sol";

// Facets
import { FakePools } from "./LaunchStrategies/FakePools.sol";

// Interfaces
import { Token } from "../../../Token.sol";


contract Launcher is Diamondable {

	address constant dEaD = address(0x000000000000000000000000000000000000dEaD);

	function launch(address token, LibTokens.TokenInfo calldata tokenInfo) public onlyDiamond returns (address pair, uint256 eth, uint256 tokens) {
		if (tokenInfo.strategy == LibTokens.LaunchStrategy.FakeLiquidity) {
			uint256 fakeEth;
			(eth, tokens, fakeEth) = FakePools(address(this)).fakepool_close(token);

			LibDex.addLiquidty(tokenInfo.dex, token, eth + fakeEth, tokens);
			LibDex.decreaseLiquidity(tokenInfo.dex, token, fakeEth);

			// burn tokens
			Token(token).transfer(dEaD, Token(token).balanceOf(address(this)));

			LpTreasury(address(this)).handleLp(tokenInfo.dex, token);
		} else {
			revert("invalid strategy");
		}
		pair = LibDex.getPair(tokenInfo.dex, token);
	}

}