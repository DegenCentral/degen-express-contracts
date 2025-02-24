// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.20;

// Contracts/Libraries/Modifiers
import { LibDiamond } from "../../../libraries/LibDiamond.sol";
import { Diamondable } from "../../../Diamondable.sol";
import { LibLp } from "../../../libraries/LibLp.sol";

// Third Party
import { INonfungiblePositionManager } from "ramses-v3/contracts/CL/periphery/interfaces/INonfungiblePositionManager.sol";
import { LiquidityAmounts } from "ramses-v3/contracts/CL/periphery/libraries/LiquidityAmounts.sol";
import { IRamsesV3Factory } from "ramses-v3/contracts/CL/core/interfaces/IRamsesV3Factory.sol";
import { IRamsesV3Pool } from "ramses-v3/contracts/CL/core/interfaces/IRamsesV3Pool.sol";
import { TickMath } from "ramses-v3/contracts/CL/core/libraries/TickMath.sol";
import { FixedPointMathLib as FPML } from "solady/src/utils/FixedPointMathLib.sol";

// Interfaces
import { Token } from "../../../../Token.sol";


interface IwETH {
	function deposit() external payable;
	function withdraw(uint256 value) external;
}

interface ISwapRouter {
	struct ExactInputSingleParams {
		address tokenIn;
		address tokenOut;
		int24 tickSpacing;
		address recipient;
		uint256 deadline;
		uint256 amountIn;
		uint256 amountOutMinimum;
		uint160 sqrtPriceLimitX96;
	}

	function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

contract Shadow is Diamondable {

	IRamsesV3Factory constant factory = IRamsesV3Factory(0xcD2d0637c94fe77C2896BbCBB174cefFb08DE6d7);
	INonfungiblePositionManager constant nfpManager = INonfungiblePositionManager(0x12E66C8F215DdD5d48d150c8f46aD0c6fB0F4406);
	ISwapRouter constant router = ISwapRouter(0x5543c6176FEb9B4b179078205d7C29EEa2e2d695);

	int24 constant spacing = 50;

	function shadow_pairFor(address token) public view returns (address) {
		return factory.getPool(token, nfpManager.WETH9(), spacing);
	}

	function shadow_addLiquidty(
		address token,
		uint256 ethAmount,
		uint256 tokenAmount
	) public onlyDiamond {
		address weth = nfpManager.WETH9();

		(address token0, address token1) = weth < token
			? (weth, token)
			: (token, weth);
		(uint256 amount0, uint256 amount1) = weth < token
			? (ethAmount, tokenAmount)
			: (tokenAmount, ethAmount);

		address pool = shadow_pairFor(token);
		if (pool == address(0)) {
			pool = factory.createPool(
				token0,
				token1,
				spacing,
				calculateSqrtPriceX96(amount0, amount1)
			);
		}

		IwETH(weth).deposit{ value: ethAmount }();

		Token(token0).approve(address(nfpManager), amount0);
		Token(token1).approve(address(nfpManager), amount1);

		INonfungiblePositionManager.MintParams
			memory params = INonfungiblePositionManager.MintParams({
				token0: token0,
				token1: token1,
				tickSpacing: spacing,
				tickLower: (-887272 / spacing) * spacing,
				tickUpper: (887272 / spacing) * spacing,
				amount0Desired: amount0,
				amount1Desired: amount1,
				amount0Min: 0,
				amount1Min: 0,
				recipient: address(this),
				deadline: block.timestamp
			});

		(uint256 tokenId,,,) = nfpManager.mint(params);

		// initial mini swap to trigger indexing
		uint256 amountWeth = 2 ether;
		IwETH(weth).deposit{ value: amountWeth }();
		Token(weth).approve(address(router), amountWeth);
		uint256 tokenOut = router.exactInputSingle(ISwapRouter.ExactInputSingleParams({
			tokenIn: weth,
			tokenOut: token,
			tickSpacing: spacing,
			recipient: address(this),
			deadline: block.timestamp,
			amountIn: amountWeth,
			amountOutMinimum: 1,
			sqrtPriceLimitX96: 0
		}));
		Token(token).approve(address(router), tokenOut);
		uint256 wethOut = router.exactInputSingle(ISwapRouter.ExactInputSingleParams({
			tokenIn: token,
			tokenOut: weth,
			tickSpacing: spacing,
			recipient: address(this),
			deadline: block.timestamp,
			amountIn: tokenOut,
			amountOutMinimum: 1,
			sqrtPriceLimitX96: 0
		}));
		IwETH(weth).withdraw(wethOut);

		LibLp.store().shadow_cl_positions[token] = tokenId;
	}

	function shadow_decreaseLiquidity(address token, uint256 ethAmount) public onlyDiamond {
		uint256 tokenId = LibLp.store().shadow_cl_positions[token];
		require(tokenId > 0, "no position");

		address weth = nfpManager.WETH9();

		(address token0,,,int24 tickLower, int24 tickUpper, uint128 liquidity,,,,) = nfpManager.positions(tokenId);
		(uint160 sqrtPriceX96,,,,,,) = IRamsesV3Pool(shadow_pairFor(token)).slot0();

		(uint256 liq0, uint256 liq1) = LiquidityAmounts.getAmountsForLiquidity(
			sqrtPriceX96,
			TickMath.getSqrtRatioAtTick(tickLower),
			TickMath.getSqrtRatioAtTick(tickUpper),
			liquidity
		);

		uint256 liqWeth = token0 == weth ? liq0 : liq1;

		uint256 liqToRemove = FPML.mulDivUp(uint256(liquidity), ethAmount, liqWeth);

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

		IwETH(weth).withdraw(Token(weth).balanceOf(address(this)));
	}


	uint256 internal constant Q96 = 0x1000000000000000000000000;

	function calculateSqrtPriceX96(uint256 amount0, uint256 amount1) internal pure returns (uint160) {
		return uint160(FPML.mulDiv(FPML.sqrt(amount1), Q96, FPML.sqrt(amount0)));
	}

	// add bridged shadow positons
	function shadow_add_token(address token, uint256 tokenId) external {
		LibDiamond.enforceIsContractOwner();

		nfpManager.transferFrom(msg.sender, address(this), tokenId);
		LibLp.store().shadow_cl_positions[token] = tokenId;
	}

}
