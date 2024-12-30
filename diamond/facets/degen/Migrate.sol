// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.18;

import {LibFakePools} from "../../libraries/LibFakePools.sol";
import {LibTokens} from "../../libraries/LibTokens.sol";
import {LibDex} from "../../libraries/LibDex.sol";
import {LibUsd} from "../../libraries/LibUsd.sol";
import {LibCore} from "../../libraries/LibCore.sol";
import {Core} from "./Core.sol";
import {Ownable} from "../../Ownable.sol";
import {Token} from "../../../Token.sol";

contract Migrate is Ownable {

	function completeMigration(
		address creator,
		string calldata name,
		string calldata symbol,
		string calldata description,
		bytes calldata image,
		string[] calldata links,
		uint256 ethReserve,
		uint256 tokenReserve,
		uint256 fakeEth,
		address[] calldata holders,
		uint256[] calldata balances
	) external payable onlyOwner {
		// Create new token with fake pool
		address token = Core(address(this))._create(
			creator,
			name,
			symbol,
			description,
			image,
			links,
			hex'',
			LibTokens.LaunchStrategy.FakeLiquidity,
			LibDex.Dex.Equalizer,
			0,
			LibUsd.usdToEth(LibCore.store().creationPrice)
		);

		for (uint256 i = 0; i < holders.length; i++) {
			Token(token).transfer(holders[i], balances[i]);
		}

		// Set pool reserves
		LibFakePools.FakePool storage pool = LibFakePools.store().pools[token];
		pool.fakeEth = fakeEth;
		pool.ethReserve = ethReserve;
		pool.tokenReserve = tokenReserve;
	}
}
