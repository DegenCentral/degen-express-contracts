// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.18;

interface ISolidlyLauncher {
	function launch(address token, uint256 amount, uint256 microBuy) external payable returns (address pool, uint256 lp);
}