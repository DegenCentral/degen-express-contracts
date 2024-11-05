// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.18;

import { IUniV3Launcher } from "../diamond/interfaces/IUniV3Launcher.sol";
import { INonfungiblePositionManager } from "../diamond/interfaces/INonfungiblePositionManager.sol";
import { IwETH } from "../diamond/interfaces/IwETH.sol";
import { Token } from "../Token.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";

interface IUniswapV3Pool {
	function initialize(uint160 sqrtPriceX96) external;

	function swap(
		address recipient,
		bool zeroForOne,
		int256 amountSpecified,
		uint160 sqrtPriceLimitX96,
		bytes calldata data
	) external returns (int256 amount0, int256 amount1);
}

interface IUniswapV3Factory {
	function getPool(address tokenA, address tokenB, uint24 fee) external view returns (IUniswapV3Pool pool);
	function createPool(address tokenA, address tokenB, uint24 fee) external returns (IUniswapV3Pool pool);
}

contract UniV3Launcher is IUniV3Launcher {

	IUniswapV3Factory internal _factory;
	address internal _nfpManager;
	uint24 internal _fee;
	int24 internal _spacing;

	address internal owner;
	IUniswapV3Pool internal pool;

	constructor(address nfpManager, address factory, uint24 fee, int24 spacing) {
		_factory = IUniswapV3Factory(factory);
		_nfpManager = nfpManager;
		_fee = fee;
		_spacing = spacing;
		owner = msg.sender;
	}

	function WETH() public view override returns (address) {
		return INonfungiblePositionManager(_nfpManager).WETH9();
	}

	function launch(
		address weth,
		uint256 amountWeth,
		address token,
		uint256 amountToken
	) external payable returns (address, uint256) {
		(address token0, address token1) = weth < token
			? (weth, token)
			: (token, weth);
		(uint256 amount0, uint256 amount1) = weth < token
			? (amountWeth, amountToken)
			: (amountToken, amountWeth);

		uint160 sqrtPrice = calculateSqrtPriceX96(amount0, amount1);

		pool = _factory.getPool(token0, token1, _fee);
		if (address(pool) == address(0)) {
			pool = _factory.createPool(token0, token1, _fee);
			pool.initialize(sqrtPrice);
		}

		// Approve token transfers to the position manager
		Token(token0).approve(_nfpManager, amount0);
		Token(token1).approve(_nfpManager, amount1);

		// Mint the position (add liquidity)
		INonfungiblePositionManager.MintParams
			memory params = INonfungiblePositionManager.MintParams({
				token0: token0,
				token1: token1,
				fee: _fee,
				tickLower: (-887272 / _spacing) * _spacing,
				tickUpper: (887272 / _spacing) * _spacing,
				amount0Desired: amount0,
				amount1Desired: amount1,
				amount0Min: 0,
				amount1Min: 0,
				recipient: msg.sender,
				deadline: block.timestamp + 15 minutes
			});

		(uint256 tokenId, , , ) = INonfungiblePositionManager(_nfpManager).mint(
			params
		);

		pool.swap(
			owner,
			token0 == weth,
			int256(msg.value),
			token0 == weth ? 4295128740 : 1461446703485210103287273052203988822378723970341,
			""
		);

		return (address(pool), tokenId);
	}

	function uniswapV3SwapCallback(
		int256 amount0Delta,
		int256 amount1Delta,
		bytes calldata data
	) public {
		require(msg.sender == address(pool), "LAUNCHER: FORBIDDEN");

		uint256 amount = uint256(amount0Delta > 0 ? amount0Delta : amount1Delta);

		IwETH(WETH()).deposit{value: amount}();
		Token(WETH()).transfer(address(pool), amount);
	}

	uint256 internal constant Q96 = 0x1000000000000000000000000;

	function calculateSqrtPriceX96(uint256 amount0, uint256 amount1) internal pure returns (uint160) {
		return uint160(Math.mulDiv(Math.sqrt(amount1), Q96, Math.sqrt(amount0)));
	}

	function fee() external view override returns (uint24) {
		return _fee;
	}

	function spacing() external view override returns (int24) {
		return _spacing;
	}

	function nfpManager() external view override returns (address) {
		return _nfpManager;
	}
}