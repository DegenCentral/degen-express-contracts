// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.18;

// Contracts/Libraries/Modifiers
import { Diamondable } from "../../../Diamondable.sol";

// Libraries
import { FixedPointMathLib as FPML } from "solady/src/utils/FixedPointMathLib.sol";

// Interfaces
import { Token } from "../../../../Token.sol";


// https://github.com/code-423n4/2024-10-ramses-exchange/blob/main/contracts/CL/core/RamsesV3Factory.sol
interface IShadowFactory {
	function getPool(
		address tokenA,
		address tokenB,
		int24 tickSpacing
	) external view returns (address pool);

	function createPool(
		address tokenA,
		address tokenB,
		int24 tickSpacing,
		uint160 sqrtPriceX96
	) external returns (address pool);
}

// https://github.com/code-423n4/2024-10-ramses-exchange/blob/main/contracts/CL/periphery/NonfungiblePositionManager.sol
interface IShadowNonfungiblePositionManager {
	function WETH9() external view returns (address);

	struct MintParams {
		address token0;
		address token1;
		int24 tickSpacing;
		int24 tickLower;
		int24 tickUpper;
		uint256 amount0Desired;
		uint256 amount1Desired;
		uint256 amount0Min;
		uint256 amount1Min;
		address recipient;
		uint256 deadline;
	}

	function mint(
		MintParams calldata params
  ) external payable returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
}

contract ShadowLpHandler is Diamondable {
	struct Storage {
		mapping (address => uint256) positions;
	}

	function store() internal pure returns (Storage storage s) {
		bytes32 position = keccak256("diamond.shadowlp.storage");
		assembly { s.slot := position }
	}


	IShadowFactory constant factory = IShadowFactory(0xcD2d0637c94fe77C2896BbCBB174cefFb08DE6d7);
	IShadowNonfungiblePositionManager constant nfpManager = IShadowNonfungiblePositionManager(0xA57FA38b3fd45922394e9E1077748A2383F1542E);

	int24 internal spacing = 50;

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

		Token(token0).approve(address(nfpManager), amount0);
		Token(token1).approve(address(nfpManager), amount1);

		IShadowNonfungiblePositionManager.MintParams
			memory params = IShadowNonfungiblePositionManager.MintParams({
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

		store().positions[token] = tokenId;
	}

	function shadow_decreaseLiquidity(address token, uint256 amount) public onlyDiamond {
		// TODO shadow
		// https://github.com/code-423n4/2024-10-ramses-exchange/blob/1ba89267cc7c010f13c4d405476090641d18b146/contracts/CL/periphery/NonfungiblePositionManager.sol#L264
	}


	uint256 internal constant Q96 = 0x1000000000000000000000000;

	function calculateSqrtPriceX96(uint256 amount0, uint256 amount1) internal pure returns (uint160) {
		return uint160(FPML.mulDiv(FPML.sqrt(amount1), Q96, FPML.sqrt(amount0)));
	}

}
