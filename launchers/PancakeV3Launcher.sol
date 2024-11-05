// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.18;

import { UniV3Launcher } from "./UniV3Launcher.sol";

contract PancakeV3Launcher is UniV3Launcher {

	constructor(address nfpManager, address factory, uint24 fee, int24 spacing) UniV3Launcher(nfpManager, factory, fee, spacing) {}

	function pancakeV3SwapCallback(
		int256 amount0Delta,
		int256 amount1Delta,
		bytes calldata data
	) external {
		uniswapV3SwapCallback(amount0Delta, amount1Delta, data);
	}
}