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
import { Haltable } from "../../Haltable.sol";

// Third Party
import { EnumerableSetLib as ESL } from "solady/src/utils/EnumerableSetLib.sol";
import { INonfungiblePositionManager } from "ramses-v3/contracts/CL/periphery/interfaces/INonfungiblePositionManager.sol";

// Interfaces
import { Token } from "../../../Token.sol";

// https://sonicscan.org/address/0x157d9c9900c2d7ae88deb6acbf3a016f3c1e938c#readContract
interface EqualPair {
	function tokens() external view returns (address token0, address token1);
	function claimFees() external returns (uint claimed0, uint claimed1);
}

contract LpTreasury is Diamondable, Haltable {

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

	INonfungiblePositionManager constant nfpManager = INonfungiblePositionManager(0x12E66C8F215DdD5d48d150c8f46aD0c6fB0F4406);
	
	function reapFees(address token, LibDex.Dex dex) internal {
		if (dex == LibDex.Dex.Equalizer) {
			EqualPair pair = EqualPair(LibLp.store().equal_amm_positions[token]);
			(address token0, address token1) = pair.tokens();

			address[] memory assets = new address[](2);
			uint256[] memory amounts = new uint256[](2);

			assets[0] = token0;
			assets[1] = token1;

			(uint256 amount0, uint256 amount1) = pair.claimFees();
			
			amounts[0] = amount0;
			amounts[1] = amount1;

			ClaimShares storage shares = store().claimShares[token];
			for (uint256 i = 0; i < assets.length; i++) {
				splitShares(shares, assets[i], amounts[i]);
			}
		} else if (dex == LibDex.Dex.Shadow) {
			uint256 tokenId = LibLp.store().shadow_cl_positions[token];

			(address token0, address token1,,,,,,,,) = nfpManager.positions(tokenId);

			address[] memory assets = new address[](2);
			uint256[] memory amounts = new uint256[](2);

			assets[0] = token0;
			assets[1] = token1;

			(uint256 amount0, uint256 amount1) = nfpManager.collect(
				INonfungiblePositionManager.CollectParams({
					tokenId: tokenId,
					recipient: address(this),
					amount0Max: type(uint128).max,
					amount1Max: type(uint128).max
				})
			);

			amounts[0] = amount0;
			amounts[1] = amount1;

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

	function claimFees(address token) public checkHalted {
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
			receiver = LibDiamond.contractOwner();
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

}
