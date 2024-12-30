// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.18;

// Contracts/Libraries/Modifiers
import { LibCore } from "../../libraries/LibCore.sol";
import { LibTokens } from "../../libraries/LibTokens.sol";
import { LibDiamond } from "../../libraries/LibDiamond.sol";
import { LibUsd } from "../../libraries/LibUsd.sol";
import { LibDex } from "../../libraries/LibDex.sol";
import { Diamondable } from "../../Diamondable.sol";

import { Token } from "../../../Token.sol";


// https://ftmscan.com/address/0x2f20A659601d1c161A108E0725FEF31256a907ad#writeProxyContract
interface eLockerRoom {
	function createLock(address _lp, uint _amt, uint _exp) external returns(address _locker, uint _ID);
}

// https://ftmscan.com/address/0xf3ddc1a30f927620c12a5d614679d9790a0284c6#readContract
interface eLock {
	function token0() external view returns (address);
	function token1() external view returns (address);

	function rewardsList() external view returns (address[] memory);

	function claimFees() external;
	function claimRewards() external;
}


contract LpTreasury is Diamondable {
	eLockerRoom constant lockerRoom = eLockerRoom(0xC6b515328F970EC25228A716BF91774E5BD5Abc0);

	struct Storage {
		mapping (address => address) elocks;
	}

	function store() internal pure returns (Storage storage s) {
		bytes32 position = keccak256("diamond.lptreasury.storage");
		assembly { s.slot := position }
	}
	
	event FeesClaimed(address[] assets, uint256[] amounts);
	function claimFees(address[] calldata tokens) public {
		for (uint256 i = 0; i < tokens.length; i++) {
			claimFees(tokens[i]);
		}
	}

	function claimFees(address token) public {
		LibTokens.TokenInfo storage tokenInfo = LibTokens.store().tokens[token];
		require(tokenInfo.creator != address(0), "Token not found");
		require(msg.sender == tokenInfo.creator || msg.sender == LibDiamond.contractOwner());

		if (tokenInfo.dex == LibDex.Dex.Equalizer) {
			eLock lock = eLock(store().elocks[token]);

			(address token0, address token1) = (lock.token0(), lock.token1());
			address[] memory rewardAssets = lock.rewardsList();

			address[] memory assets = new address[](2 + rewardAssets.length);
			uint256[] memory amounts = new uint256[](2 + rewardAssets.length);
			uint256[] memory amountsBefore = new uint256[](2 + rewardAssets.length);

			assets[0] = token0;
			assets[1] = token1;
			amountsBefore[0] = Token(token0).balanceOf(address(this));
			amountsBefore[1] = Token(token1).balanceOf(address(this));

			lock.claimFees();
			
			amounts[0] = Token(token0).balanceOf(address(this)) - amountsBefore[0];
			amounts[1] = Token(token1).balanceOf(address(this)) - amountsBefore[1];

			if (rewardAssets.length > 0) {
				for (uint256 i = 0; i < rewardAssets.length; i++) {
					amountsBefore[2 + i] = Token(rewardAssets[i]).balanceOf(address(this));
				}

				lock.claimRewards();

				for (uint256 i = 0; i < rewardAssets.length; i++) {
					assets[2 + i] = rewardAssets[i];
					amounts[2 + i] = Token(rewardAssets[i]).balanceOf(address(this)) - amountsBefore[2 + i];
				}
			}

			address creator = tokenInfo.creator;
			address protocol = LibCore.store().proceedsReceiver;
			for (uint256 i = 0; i < assets.length; i++) {
				if (amounts[i] == 0) continue;
				distribute(assets[i], amounts[i], creator, protocol);
			}

			emit FeesClaimed(assets, amounts);
		} else if (tokenInfo.dex == LibDex.Dex.Shadow) {
			// TODO shadow

			// nfpm.collect(
			// 	INonfungiblePositionManager.CollectParams({
			// 		tokenId: tokenId,
			// 		recipient: owner,
			// 		amount0Max: type(uint128).max,
			// 		amount1Max: type(uint128).max
			// 	})
			// );
		} else {
			revert("invalid dex");
		}
	}

	function distribute(address token, uint256 amount, address creator, address protocol) internal {
		uint256 creatorShare = amount / 3;
		uint256 protocolShare = amount - creatorShare;

		Token(token).transfer(creator, creatorShare);
		Token(token).transfer(protocol, protocolShare);
	}

	function handleLp(LibDex.Dex dex, address token) public {
		require(msg.sender == LibDiamond.contractOwner() || msg.sender == LibDiamond.diamondStorage().diamondAddress);
		require(store().elocks[token] == address(0), "already handled");

		if (dex == LibDex.Dex.Equalizer) {
			address lp = LibDex.getPair(dex, token);
			uint256 amount = Token(lp).balanceOf(address(this));

			Token(lp).approve(address(lockerRoom), amount);
			(address vault,) = lockerRoom.createLock(lp, amount, block.timestamp + 1);

			store().elocks[token] = vault;
		} else if (dex == LibDex.Dex.Shadow) {
			// TODO shadow
		} else {
			revert("invalid dex");
		}
	}

}
