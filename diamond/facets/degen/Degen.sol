// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.20;

// Contracts/Libraries/Modifiers
import { LibUsd } from "../../libraries/LibUsd.sol";
import { Diamondable } from "../../Diamondable.sol";

// Interfaces
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Third Party
import { FixedPointMathLib } from "solady/src/utils/FixedPointMathLib.sol";
import { Base64 } from "solady/src/utils/Base64.sol";


contract Degen is Diamondable {
	struct Storage {
		mapping(address => bytes) pfps;
		mapping(address => uint256) xp;
	}

	function store() internal pure returns (Storage storage s) {
		bytes32 position = keccak256("diamond.degen.storage");
		assembly { s.slot := position }
	}

	event PfpSet(address degen);
	
	function pfp(address degen) public view returns (string memory) {
		return string.concat("data:image/webp;base64,", Base64.encode(store().pfps[degen]));
	}

	function setPfp(bytes memory image) public {
		require(
			bytes(image).length <= 1e7, // 1mb
			"invalid image"
		);

		store().pfps[msg.sender] = image;

		emit PfpSet(msg.sender);
	}

	event XP(address degen, uint256 xp, uint256 totalXp);

	enum XpType {
		Buy,
		Sell,
		Launch
	}

	function attributeXp(address degen, XpType xpType, uint256 amount) public onlyDiamond {
		amount = FixedPointMathLib.mulWad(amount, LibUsd.getPrice() / 3000);

		uint256 xp;
		if (xpType == XpType.Buy) {
			xp = amount * 800;
		} else if (xpType == XpType.Sell) {
			xp = amount * 600;
		} else if (xpType == XpType.Launch) {
			xp = amount * 400;
		}
		store().xp[degen] += xp;

		emit XP(degen, xp, store().xp[degen]);
	}

}
