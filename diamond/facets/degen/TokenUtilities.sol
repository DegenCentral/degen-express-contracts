// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.20;

// Contracts/Libraries/Modifiers
import { LibTokens } from "../../libraries/LibTokens.sol";

// Interfaces
import { Token } from "../../../Token.sol";


contract TokenUtilities {

	address constant dEaD = address(0x000000000000000000000000000000000000dEaD);

	function token_util_burn(address token, uint256 amount) external {
		require(LibTokens.store().tokens[token].creator != address(0), "invalid token");

		Token(token).transferFrom(msg.sender, address(this), amount);
		Token(token).transfer(dEaD, amount);
	}

}