// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.18;

import { ISolidlyLauncher } from "../diamond/interfaces/ISolidlyLauncher.sol";
import { IwETH } from "../diamond/interfaces/IwETH.sol";
import { Token } from "../Token.sol";

interface ISolidlyV3Router {
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

	struct Route {
		address from;
		address to;
		bool stable;
	}

	function swapExactETHForTokens(uint amountOutMin, Route[] calldata routes, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);
}

contract EqualizerLauncher is ISolidlyLauncher {

	ISolidlyV3Router public router;

	constructor(address _router) {
		router = ISolidlyV3Router(_router);
	}

	function launch(
		address token,
		uint256 amount,
		uint256 microBuy
	) external payable returns (address, uint256) {
		uint256 amountETH = msg.value - microBuy;

		Token(token).approve(address(router), amount);

		(,,uint256 lp) = router.addLiquidityETH{value: amountETH}(
			token,
			false,
			amount,
			0,
			0,
			msg.sender,
			block.timestamp + 15 minutes
		);

		address pair = router.pairFor(token, router.weth(), false);

		ISolidlyV3Router.Route[] memory route = new ISolidlyV3Router.Route[](1);
		route[0] = ISolidlyV3Router.Route(router.weth(), token, false);
		router.swapExactETHForTokens{value: microBuy}(
			0,
			route,
			msg.sender,
			block.timestamp + 15 minutes
		);

		return (pair, lp);
	}
}