// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.18;

// Contracts/Libraries/Modifiers
import { Diamondable } from "../../../Diamondable.sol";

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

contract EqualizerLpHandler is Diamondable {
	struct Storage {
		mapping (address => address) positions;
	}

	function store() internal pure returns (Storage storage s) {
		bytes32 position = keccak256("diamond.equallp.storage");
		assembly { s.slot := position }
	}


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

		store().positions[token] = equal_pairFor(token);
	}

	function equal_decreaseLiquidity(address token, uint256 amount) public onlyDiamond {
		address pair = store().positions[token];
		
		(uint reserve0, uint reserve1,) = IEqualV2Pair(pair).getReserves();
		(uint reserveETH,) = token < router.weth() ? (reserve1, reserve0) : (reserve0, reserve1);

		uint256 lpTokensToBurn = FixedPointMathLib.mulDivUp(amount, IEqualV2Pair(pair).totalSupply(), reserveETH);

		Token(pair).approve(address(router), lpTokensToBurn);

		router.removeLiquidityETH(
			token,
			false,
			lpTokensToBurn,
			0,
			amount,
			address(this),
			block.timestamp
		);
	}

}
