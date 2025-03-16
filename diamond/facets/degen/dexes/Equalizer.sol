// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.20;

// Contracts/Libraries/Modifiers
import { Diamondable } from "../../../Diamondable.sol";
import { LibLp } from "../../../libraries/LibLp.sol";
import { LibDiamond } from "../../../libraries/LibDiamond.sol";

// Libraries
import { FixedPointMathLib } from "solady/src/utils/FixedPointMathLib.sol";

// Interfaces
import { Token } from "../../../../Token.sol";


interface IEqualV2Pair {
	function totalSupply() external view returns (uint);
	function getReserves() external view returns (uint _reserve0, uint _reserve1, uint _blockTimestampLast);

	function mint(address to) external returns (uint liquidity);
}

interface IEqualV2Factory {
	function createPair(address tokenA, address tokenB, bool stable) external returns (address);
}

interface IEqualV3Router {
	function weth() external view returns (address);

	function pairFor(address tokenA, address tokenB, bool stable) external view returns (address);

	function factory() external view returns (IEqualV2Factory);
	
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

interface IwETH {
	function deposit() external payable;
}

contract Equalizer is Diamondable {

	IEqualV3Router constant router = IEqualV3Router(0xcC6169aA1E879d3a4227536671F85afdb2d23fAD);

	function equal_pairFor(address token) public view returns (address) {
		return router.pairFor(token, router.weth(), false);
	}

	function equal_createPair(address token) public onlyDiamond returns (address) {
		Token(token).transfer(0x000000000000000000000000000000000000dEaD, 100 ether); // no lp guard needed
		return router.factory().createPair(token, router.weth(), false);
	}

	function equal_addLiquidity(
		address token,
		uint256 ethAmount,
		uint256 tokenAmount
	) public onlyDiamond {
		address weth = router.weth();
		address pair = equal_pairFor(token);

		Token(token).transfer(pair, tokenAmount);
		IwETH(weth).deposit{ value: ethAmount }();
		Token(weth).transfer(pair, ethAmount);

		IEqualV2Pair(pair).mint(address(this));

		LibLp.store().equal_amm_positions[token] = pair;
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
