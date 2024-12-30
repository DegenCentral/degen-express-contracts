// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.18;

import { Token } from "./Token.sol";

import { IRouter } from "./diamond/interfaces/IRouter.sol";

interface ISolidlyV3Router {
	function weth() external view returns (address);

	struct route {
		address from;
		address to;
		bool stable;
	}

	function getAmountOut(uint amountIn, address tokenIn, address tokenOut) external view returns (uint amount, bool stable);

	function swapExactETHForTokens(uint amountOutMin, route[] calldata routes, address to, uint deadline)
	 external payable returns (uint[] memory amounts);

	function swapExactTokensForETH(uint amountIn, uint amountOutMin, route[] calldata routes, address to, uint deadline)
    external returns (uint[] memory amounts);
}

contract SolidlyV3Router is IRouter {
	ISolidlyV3Router constant router =
		ISolidlyV3Router(0xcC6169aA1E879d3a4227536671F85afdb2d23fAD);

	function routify(
		address token0,
		address token1
	) internal pure returns (ISolidlyV3Router.route[] memory) {
		ISolidlyV3Router.route[] memory route = new ISolidlyV3Router.route[](1);
		route[0] = ISolidlyV3Router.route(token0, token1, false);
		return route;
	}

	function WETH() external view returns (address) {
		return router.weth();
	}

	function getAmountOut(
		uint amountIn,
		address tokenIn,
		address tokenOut
	) internal view returns (uint amount) {
		(amount, ) = router.getAmountOut(amountIn, tokenIn, tokenOut);
	}

	function swapExactETHForTokens(
		uint amountOutMin,
		ISolidlyV3Router.route[] memory path,
		address to,
		uint deadline
	) internal returns (uint[] memory) {
		return
			router.swapExactETHForTokens{value: msg.value}(
				amountOutMin,
				path,
				to,
				deadline
			);
	}

	function swapExactTokensForETH(
		uint amountIn,
		uint amountOutMin,
		ISolidlyV3Router.route[] memory path,
		address to,
		uint deadline
	) internal returns (uint[] memory) {
		Token(path[0].from).transferFrom(msg.sender, address(this), amountIn);
		Token(path[0].from).approve(address(router), amountIn);
		return
			router.swapExactTokensForETH(
				amountIn,
				amountOutMin,
				path,
				to,
				deadline
			);
	}

	function quote(
		address input,
		address output,
		uint256 amount
	) external override returns (uint256) {
		return getAmountOut(amount, input, output);
	}

	function swapEthForTokens(
		address token,
		uint256 amountOutMin,
		uint256 deadline
	) external payable override {
		swapExactETHForTokens(amountOutMin, routify(router.weth(), token), msg.sender, deadline);
	}

	function swapTokensForEth(
		address token,
		uint256 amountIn,
		uint256 amountOutMin,
		uint256 deadline
	) external override {
		swapExactTokensForETH(amountIn, amountOutMin, routify(token, router.weth()), msg.sender, deadline);
	}
}