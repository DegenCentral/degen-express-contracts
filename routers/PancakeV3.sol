// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.18;

import { IRouter } from "../diamond/interfaces/IRouter.sol";
import { IUniV3Router } from "../diamond/interfaces/IUniV3Router.sol";
import { IwETH } from "../diamond/interfaces/IwETH.sol";

import { Token } from "../Token.sol";

contract PancakeV2Router is IRouter {
	IUniV3Router private _router;

	constructor(address router) {
		_router = IUniV3Router(router);
	}

	function WETH() external view override returns (address) {
		return _router.WETH9();
	}

	function swapEthForTokens(address token) external payable override {
		address wETH = _router.WETH9();

		IwETH(wETH).deposit{ value: msg.value }();
		Token(wETH).approve(address(_router), msg.value);

		_router.exactInputSingle(IUniV3Router.ExactInputSingleParams({
			tokenIn: wETH,
			tokenOut: token,
			fee: 3000,
			recipient: msg.sender,
			deadline: block.timestamp + 60,
			amountIn: msg.value,
			amountOutMinimum: 1,
			sqrtPriceLimitX96: 0
		}));
	}

	function swapTokensForEth(address token, uint256 amount) external override {
		Token(token).approve(address(_router), amount);

		_router.exactInputSingle(IUniV3Router.ExactInputSingleParams({
			tokenIn: token,
			tokenOut: _router.WETH9(),
			fee: 3000,
			recipient: msg.sender,
			deadline: block.timestamp + 60,
			amountIn: amount,
			amountOutMinimum: 1,
			sqrtPriceLimitX96: 0
		}));
	}
}