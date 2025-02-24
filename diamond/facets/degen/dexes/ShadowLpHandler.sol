// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.20;

// Contracts/Libraries/Modifiers
import { Diamondable } from "../../../Diamondable.sol";
import { LibLp } from "../../../libraries/LibLp.sol";

// Third Party
import { INonfungiblePositionManager } from "ramses-v3/contracts/CL/periphery/interfaces/INonfungiblePositionManager.sol";

// Interfaces
import { Token } from "../../../../Token.sol";


interface IShadowLiquidityClaimer {
	function shadow_liquidity_received(address token0, address token1, uint256 amount0, uint256 amount1, uint256 liquidity) external;
}

contract ShadowLpHandler is Diamondable {
	struct Storage {
		uint128 liqToClaim;
		mapping(uint256 => uint128) ogLiq;
		mapping(address => mapping(address => uint8)) claimed;
	}

	function store() internal pure returns (Storage storage s) {
		bytes32 position = keccak256("diamond.shadowlphandler.storage");
		assembly { s.slot := position }
	}

	INonfungiblePositionManager constant nfpManager = INonfungiblePositionManager(0x12E66C8F215DdD5d48d150c8f46aD0c6fB0F4406);

	function shadowlp_claim(address token) external {
		uint8 maxClaim;
		if (msg.sender == address(0)) {
			// TODO
		} else {
			revert("not whitelisted");
		}

		Storage storage s = store();
		uint8 claimed = s.claimed[msg.sender][token];
		require(claimed < maxClaim, "max claimed");
		uint256 tokenId = LibLp.store().shadow_cl_positions[token];
		require(tokenId > 0, "no position");

		(address token0, address token1,,,, uint128 liquidity,,,,) = nfpManager.positions(tokenId);

		if (store().ogLiq[tokenId] == 0) {
			store().ogLiq[tokenId] = liquidity;
		} else {
			liquidity = store().ogLiq[tokenId];
		}

		uint8 leftToClaim = maxClaim - s.claimed[msg.sender][token];
		uint128 liqToRemove = (liquidity / 100) * leftToClaim;
		s.claimed[msg.sender][token] += leftToClaim;

		uint256 amount0Before = Token(token0).balanceOf(address(this));
		uint256 amount1Before = Token(token1).balanceOf(address(this));

		nfpManager.decreaseLiquidity(INonfungiblePositionManager.DecreaseLiquidityParams({
			tokenId: tokenId,
			liquidity: uint128(liqToRemove),
			amount0Min: 0,
			amount1Min: 0,
			deadline: block.timestamp
		}));

		nfpManager.collect(
			INonfungiblePositionManager.CollectParams({
				tokenId: tokenId,
				recipient: address(this),
				amount0Max: type(uint128).max,
				amount1Max: type(uint128).max
			})
		);

		uint256 amount0 = Token(token0).balanceOf(address(this)) - amount0Before;
		uint256 amount1 = Token(token1).balanceOf(address(this)) - amount1Before;

		Token(token0).transfer(msg.sender, amount0);
		Token(token1).transfer(msg.sender, amount1);

		IShadowLiquidityClaimer(msg.sender).shadow_liquidity_received(token0, token1, amount0, amount1, liqToRemove);

		if (msg.sender == address(0)) {
			// TODO
		} else {
			revert("not whitelisted");
		}
	}

	function shadowlp_claimExternalFees() public onlyDiamond {
		// TODO
	}

}
