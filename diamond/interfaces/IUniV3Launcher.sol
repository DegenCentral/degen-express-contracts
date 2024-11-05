// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.18;

interface IUniV3Launcher {
	function fee() external view returns (uint24);
	function spacing() external view returns (int24);
	function WETH() external view returns (address);
	function nfpManager() external view returns (address);
	function launch(address token0, uint256 amount0, address token1, uint256 amount1) external payable returns (address pool, uint256 nfp);
}