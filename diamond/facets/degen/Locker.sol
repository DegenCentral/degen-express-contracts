// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.18;

import { LibDiamond } from "../../libraries/LibDiamond.sol";
import { LibDegen } from "../../libraries/LibDegen.sol";
import { LibFakePools } from "../../libraries/LibFakePools.sol";
import { LibUtils } from "../../libraries/LibUtils.sol";
import { Diamondable } from "../../Diamondable.sol";
import { Token } from "../../../Token.sol";

interface eLockerRoom {
	function createLock(address _lp, uint _amt, uint _exp) external returns(address _locker, uint _ID);
	function createLockFor(address _lp, uint _amt, uint _exp, address _to) external returns(address _locker, uint _ID);
}

contract Locker is Diamondable {

	function _lock(address lp, uint256 amount, address creator) external onlyDiamond returns (address) {
		eLockerRoom lockerRoom = eLockerRoom(0x2f20A659601d1c161A108E0725FEF31256a907ad);

		uint256 creatorShare = amount / 3;
		uint256 protocolShare = amount - creatorShare;

		Token(lp).approve(address(lockerRoom), amount);
		
		(address vault,) = lockerRoom.createLock(lp, protocolShare, 1733007600);
		lockerRoom.createLockFor(lp, creatorShare, 1733007600, creator);

		return vault;
	}

}
