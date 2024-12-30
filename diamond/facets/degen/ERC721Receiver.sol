// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.18;


contract ERC721Receiver {

	function onERC721Received(
		address operator,
		address from,
		uint256 id,
		bytes calldata data
	) external returns (bytes4) {
		// TODO
		// check from and data and route accordingly

		return ERC721Receiver.onERC721Received.selector;
	}
	
}