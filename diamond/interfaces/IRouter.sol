// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.18;

interface IRouter {
	function WETH() external view returns (address);

  function swapEthForTokens(address token) external payable;
	function swapTokensForEth(address token, uint256 amount) external;

}