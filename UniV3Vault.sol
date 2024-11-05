// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.18;

import { INonfungiblePositionManager } from "./diamond/interfaces/INonfungiblePositionManager.sol";

interface IERC721Receiver {
	function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

contract UniV3Vault is IERC721Receiver {

	address public owner;
	uint256 public tokenId;
	INonfungiblePositionManager public nfpm;

	constructor(address _owner, address _nonfungiblePositionManager) {
		owner = _owner;
		nfpm = INonfungiblePositionManager(_nonfungiblePositionManager);
	}

	function collectFees() external {
		require(msg.sender == owner, "Vault: FORBIDDEN");

		nfpm.collect(
			INonfungiblePositionManager.CollectParams({
				tokenId: tokenId,
				recipient: owner,
				amount0Max: type(uint128).max,
				amount1Max: type(uint128).max
			})
		);
	}

	function onERC721Received(
		address operator,
		address from,
		uint256 id,
		bytes calldata data
	) external override returns (bytes4) {
		require(tokenId == 0, "Vault: LOCKED");

		tokenId = id;

		return IERC721Receiver.onERC721Received.selector;
	}
	
}