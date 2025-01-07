// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.20;

// Contracts/Libraries/Modifiers
import { Diamondable } from "../../../Diamondable.sol";
import { LibLp } from "../../../libraries/LibLp.sol";

// Libraries
import { FixedPointMathLib } from "solady/src/utils/FixedPointMathLib.sol";

// Interfaces
import { Token } from "../../../../Token.sol";


interface IEqualV2Pair {
	function totalSupply() external view returns (uint);
	function getReserves() external view returns (uint _reserve0, uint _reserve1, uint _blockTimestampLast);
}

interface IEqualV3Router {
	function weth() external view returns (address);

	function pairFor(address tokenA, address tokenB, bool stable) external view returns (address pair);

	function addLiquidityETH(
		address token,
		bool stable,
		uint amountTokenDesired,
		uint amountTokenMin,
		uint amountETHMin,
		address to,
		uint deadline
	) external payable returns (uint amountToken, uint amountETH, uint liquidity);

	function removeLiquidityETH(
		address token,
		bool stable,
		uint liquidity,
		uint amountTokenMin,
		uint amountETHMin,
		address to,
		uint deadline
	) external returns (uint amountToken, uint amountETH);
}

contract Equalizer is Diamondable {

	IEqualV3Router constant router = IEqualV3Router(0xcC6169aA1E879d3a4227536671F85afdb2d23fAD);

	function equal_pairFor(address token) public view returns (address) {
		return router.pairFor(token, router.weth(), false);
	}

	function equal_addLiquidty(
		address token,
		uint256 ethAmount,
		uint256 tokenAmount
	) public onlyDiamond {
		Token(token).approve(address(router), tokenAmount);

		router.addLiquidityETH{value: ethAmount}(
			token,
			false,
			tokenAmount,
			0,
			0,
			address(this),
			block.timestamp
		);

		LibLp.store().equal_amm_positions[token] = equal_pairFor(token);
	}

	function equal_decreaseLiquidity(address token, uint256 ethAmount) public onlyDiamond {
		address pair = LibLp.store().equal_amm_positions[token];
		require(pair != address(0), "no position found");
		
		(uint reserve0, uint reserve1,) = IEqualV2Pair(pair).getReserves();
		(uint reserveETH,) = token < router.weth() ? (reserve1, reserve0) : (reserve0, reserve1);

		uint256 lpTokensToBurn = FixedPointMathLib.mulDivUp(ethAmount, IEqualV2Pair(pair).totalSupply(), reserveETH);

		Token(pair).approve(address(router), lpTokensToBurn);

		router.removeLiquidityETH(
			token,
			false,
			lpTokensToBurn,
			0,
			ethAmount,
			address(this),
			block.timestamp
		);
	}

}
