// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.0;

interface ISettingsStorage {
	function setWhitelist(address[] memory _addresses) external;
	function changeSnipeDuration(uint256 duration) external;
}