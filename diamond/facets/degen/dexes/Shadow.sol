// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.20;

// Contracts/Libraries/Modifiers
import { LibDiamond } from "../../../libraries/LibDiamond.sol";
import { LibCore } from "../../../libraries/LibCore.sol";
import { Diamondable } from "../../../Diamondable.sol";
import { LibLp } from "../../../libraries/LibLp.sol";

// Third Party
import { INonfungiblePositionManager } from "ramses-v3/contracts/CL/periphery/interfaces/INonfungiblePositionManager.sol";
import { LiquidityAmounts } from "ramses-v3/contracts/CL/periphery/libraries/LiquidityAmounts.sol";
import { IRamsesV3Factory } from "ramses-v3/contracts/CL/core/interfaces/IRamsesV3Factory.sol";
import { IRamsesV3Pool } from "ramses-v3/contracts/CL/core/interfaces/IRamsesV3Pool.sol";
import { FixedPoint96 } from "ramses-v3/contracts/CL/core/libraries/FixedPoint96.sol";
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
	struct Storage {
		mapping(address => uint256) lpGuardPositions;
	}

	function store() internal pure returns (Storage storage s) {
		bytes32 position = keccak256("diamond.shadowlp.storage");
		assembly { s.slot := position }
	}

	IRamsesV3Factory constant factory = IRamsesV3Factory(0xcD2d0637c94fe77C2896BbCBB174cefFb08DE6d7);
	INonfungiblePositionManager constant nfpManager = INonfungiblePositionManager(0x12E66C8F215DdD5d48d150c8f46aD0c6fB0F4406);
	ISwapRouter constant router = ISwapRouter(0x5543c6176FEb9B4b179078205d7C29EEa2e2d695);

	int24 constant spacing = 50;

	function shadow_pairFor(address token) public view returns (address) {
		return factory.getPool(token, nfpManager.WETH9(), spacing);
	}

	function shadow_createPair(address token) public onlyDiamond returns (address) {
		address weth = nfpManager.WETH9();

		(address token0, address token1) = weth < token
			? (weth, token)
			: (token, weth);

		uint160 sqrtPrice = TickMath.getSqrtRatioAtTick(roundToSpacing(token == token0 ? TickMath.MIN_TICK : TickMath.MAX_TICK));
		(int24 tickLower, int24 tickUpper) = (roundToSpacing(TickMath.MIN_TICK), roundToSpacing(TickMath.MAX_TICK));

		address pair = factory.createPool(
			token0,
			token1,
			spacing,
			sqrtPrice
		);

		Token(token).approve(address(nfpManager), 100 ether);

		(uint256 tokenId,,,) = nfpManager.mint(
			INonfungiblePositionManager.MintParams({
				token0: token0,
				token1: token1,
				tickSpacing: spacing,
				tickLower: tickLower,
				tickUpper: tickUpper,
				amount0Desired: token == token0 ? 100 ether : 0,
				amount1Desired: token == token1 ? 100 ether : 0,
				amount0Min: 0,
				amount1Min: 0,
				recipient: address(this),
				deadline: block.timestamp
			})
		);

		store().lpGuardPositions[token] = tokenId;

		return pair;
	}

	function shadow_addLiquidity(
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

		uint160 sqrtPrice = calculateSqrtPriceX96(amount0, amount1);
		address pool = shadow_pairFor(token);

		uint256 lpGuardPos = store().lpGuardPositions[token];
		if (lpGuardPos > 0) {
			(,,,,, uint128 liquidity,,,,) = nfpManager.positions(lpGuardPos);
			nfpManager.decreaseLiquidity(
				INonfungiblePositionManager.DecreaseLiquidityParams({
					tokenId: lpGuardPos,
					liquidity: liquidity,
					amount0Min: 0,
					amount1Min: 0,
					deadline: block.timestamp
				})
			);
			(uint256 a0, uint256 a1) = nfpManager.collect(
				INonfungiblePositionManager.CollectParams({
					tokenId: lpGuardPos,
					recipient: address(this),
					amount0Max: type(uint128).max,
					amount1Max: type(uint128).max
				})
			);
			Token(token).transfer(0x000000000000000000000000000000000000dEaD, token < weth ? a0 : a1);
			nfpManager.burn(lpGuardPos);
			store().lpGuardPositions[token] = 0;
		}
		
		(uint160 currentSqrtPrice,,,,,,) = IRamsesV3Pool(pool).slot0();
		if (sqrtPrice != currentSqrtPrice) {
			bool zeroForOne = currentSqrtPrice > sqrtPrice;
			int256 amountSpecified = 1;
			IRamsesV3Pool(pool).swap(
				address(this),
				zeroForOne,
				amountSpecified,
				sqrtPrice,
				""
			);
			(uint160 csp,,,,,,) = IRamsesV3Pool(pool).slot0();
			if (csp != sqrtPrice) revert();
		}

		IwETH(weth).deposit{ value: ethAmount }();

		Token(token0).approve(address(nfpManager), amount0);
		Token(token1).approve(address(nfpManager), amount1);

		INonfungiblePositionManager.MintParams
			memory params = INonfungiblePositionManager.MintParams({
				token0: token0,
				token1: token1,
				tickSpacing: spacing,
				tickLower: roundToSpacing(TickMath.MIN_TICK),
				tickUpper: roundToSpacing(TickMath.MAX_TICK),
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
		LibCore.store().proceeds -= amountWeth - wethOut; // take swap fee from proceeds

		LibLp.store().shadow_cl_positions[token] = tokenId;
	}

	function shadow_decreaseLiquidity(address token, uint256 ethAmount) public onlyDiamond {
		address weth = nfpManager.WETH9();

		uint256 tokenId = LibLp.store().shadow_cl_positions[token];
		require(tokenId > 0, "no position");

		(address token0,,,int24 tickLower, int24 tickUpper, uint128 liquidity,,,,) = nfpManager.positions(tokenId);
		(uint160 sqrtPrice,,,,,,) = IRamsesV3Pool(shadow_pairFor(token)).slot0();

		(uint256 liq0, uint256 liq1) = LiquidityAmounts.getAmountsForLiquidity(
			sqrtPrice,
			TickMath.getSqrtRatioAtTick(tickLower),
			TickMath.getSqrtRatioAtTick(tickUpper),
			liquidity
		);

		uint256 liqWeth = token0 == weth ? liq0 : liq1;

		uint256 liqToRemove = FPML.mulDivUp(uint256(liquidity), ethAmount, liqWeth);

		uint256 wethBefore = Token(weth).balanceOf(address(this));

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

		uint256 wethAfter = Token(weth).balanceOf(address(this)) - wethBefore;
		IwETH(weth).withdraw(wethAfter);
	}

	function roundToSpacing(int24 tick) internal pure returns (int24) {
		return (tick / spacing) * spacing;
	}

	function calculateSqrtPriceX96(uint256 amount0, uint256 amount1) internal pure returns (uint160) {
		return uint160(FPML.mulDiv(FPML.sqrt(amount1), FixedPoint96.Q96, FPML.sqrt(amount0)));
	}

	// add bridged shadow positons
	function shadow_add_token(address token, uint256 tokenId) external {
		LibDiamond.enforceIsContractOwner();

		nfpManager.transferFrom(msg.sender, address(this), tokenId);
		LibLp.store().shadow_cl_positions[token] = tokenId;
	}

}
