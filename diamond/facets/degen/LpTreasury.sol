// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.20;

// Contracts/Libraries/Modifiers
import { LibCore } from "../../libraries/LibCore.sol";
import { LibTokens } from "../../libraries/LibTokens.sol";
import { LibDiamond } from "../../libraries/LibDiamond.sol";
import { LibUsd } from "../../libraries/LibUsd.sol";
import { LibDex } from "../../libraries/LibDex.sol";
import { LibLp } from "../../libraries/LibLp.sol";
import { Diamondable } from "../../Diamondable.sol";

// Third Party
import { EnumerableSetLib as ESL } from "solady/src/utils/EnumerableSetLib.sol";
import { INonfungiblePositionManager } from "ramses-v3/contracts/CL/periphery/interfaces/INonfungiblePositionManager.sol";

// Interfaces
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

	struct ClaimBalances {
		ESL.AddressSet assets;
		mapping (address => uint256) amounts;
	}

	struct ClaimShares {
		ClaimBalances creator;
		ClaimBalances protocol;
	}

	struct Storage {
		mapping (address => address) elocks;
		mapping (address => ClaimShares) claimShares;
	}

	function store() internal pure returns (Storage storage s) {
		bytes32 position = keccak256("diamond.lptreasury.storage");
		assembly { s.slot := position }
	}

	eLockerRoom constant lockerRoom = eLockerRoom(0xC6b515328F970EC25228A716BF91774E5BD5Abc0);
	INonfungiblePositionManager constant nfpManager = INonfungiblePositionManager(0xA57FA38b3fd45922394e9E1077748A2383F1542E);
	
	function reapFees(address token, LibDex.Dex dex) internal {
		if (dex == LibDex.Dex.Equalizer) {
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

			ClaimShares storage shares = store().claimShares[token];
			for (uint256 i = 0; i < assets.length; i++) {
				splitShares(shares, assets[i], amounts[i]);
			}
		} else if (dex == LibDex.Dex.Shadow) {
			uint256 tokenId = LibLp.store().shadow_cl_positions[token];

			(address token0, address token1,,,,,,,,) = nfpManager.positions(tokenId);

			address[] memory assets = new address[](2);
			uint256[] memory amounts = new uint256[](2);
			uint256[] memory amountsBefore = new uint256[](2);

			assets[0] = token0;
			assets[1] = token1;
			amountsBefore[0] = Token(token0).balanceOf(address(this));
			amountsBefore[1] = Token(token1).balanceOf(address(this));

			nfpManager.collect(
				INonfungiblePositionManager.CollectParams({
					tokenId: tokenId,
					recipient: address(this),
					amount0Max: type(uint128).max,
					amount1Max: type(uint128).max
				})
			);

			amounts[0] = Token(token0).balanceOf(address(this)) - amountsBefore[0];
			amounts[1] = Token(token1).balanceOf(address(this)) - amountsBefore[1];

			// TODO when shadow rewards go live
			// https://github.com/code-423n4/2024-10-ramses-exchange/blob/1ba89267cc7c010f13c4d405476090641d18b146/contracts/Gauge.sol#L68
			// https://github.com/code-423n4/2024-10-ramses-exchange/blob/1ba89267cc7c010f13c4d405476090641d18b146/contracts/CL/periphery/NonfungiblePositionManager.sol#L421

			// TODO
			// shadowlp_claimExternalFees

			ClaimShares storage shares = store().claimShares[token];
			for (uint256 i = 0; i < assets.length; i++) {
				splitShares(shares, assets[i], amounts[i]);
			}
		} else {
			revert("invalid dex");
		}
	}

	function splitShares(ClaimShares storage shares, address token, uint256 amount) internal {
		if (amount == 0) return;

		uint256 creatorShare = amount / 3;
		uint256 protocolShare = amount - creatorShare;

		ClaimBalances storage creator = shares.creator;
		ClaimBalances storage protocol = shares.protocol;

		ESL.add(creator.assets, token);
		ESL.add(protocol.assets, token);

		creator.amounts[token] += creatorShare;
		protocol.amounts[token] += protocolShare;
	}

	event FeesClaimed(address[] assets, uint256[] amounts);
	function multiClaimFees(address[] calldata tokens) public {
		for (uint256 i = 0; i < tokens.length; i++) {
			claimFees(tokens[i]);
		}
	}

	function claimFees(address token) public {
		LibTokens.TokenInfo storage tokenInfo = LibTokens.store().tokens[token];
		require(tokenInfo.creator != address(0), "Token not found");
		require(msg.sender == tokenInfo.creator || msg.sender == LibDiamond.contractOwner());
		require(tokenInfo.pair != address(0), "Pair not found");

		reapFees(token, tokenInfo.dex);

		ClaimShares storage claimShares = store().claimShares[token];
		ClaimBalances storage share;

		address receiver;
		if (msg.sender == tokenInfo.creator) {
			share = claimShares.creator;
			receiver = tokenInfo.creator;
		} else {
			share = claimShares.protocol;
			receiver = LibCore.store().proceedsReceiver;
		}

		address[] memory assets = ESL.values(share.assets);
		uint256[] memory amounts = new uint256[](assets.length);
		for (uint256 i = 0; i < assets.length; i++) {
			address asset = assets[i];
			uint256 amount = share.amounts[asset];
			amounts[i] = amount;
			share.amounts[asset] = 0;
			ESL.remove(share.assets, asset);
			Token(asset).transfer(receiver, amount);
		}

		emit FeesClaimed(assets, amounts);
	}

	function handleLp(LibDex.Dex dex, address token) public {
		require(msg.sender == LibDiamond.contractOwner() || msg.sender == LibDiamond.diamondStorage().diamondAddress);
		require(store().elocks[token] == address(0), "already handled");

		if (dex == LibDex.Dex.Equalizer) {
			address lp = LibLp.store().equal_amm_positions[token];
			uint256 amount = Token(lp).balanceOf(address(this));

			Token(lp).approve(address(lockerRoom), amount);
			(address vault,) = lockerRoom.createLock(lp, amount, block.timestamp + 1);

			store().elocks[token] = vault;
		} else if (dex == LibDex.Dex.Shadow) {
			// TODO when shadow rewards go live - might need to stake here
		} else {
			revert("invalid dex");
		}
	}

}
