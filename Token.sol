// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.20;

// Contracts/Libraries/Modifiers
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Base64 } from "solady/src/utils/Base64.sol";
import { LibString } from "solady/src/utils/LibString.sol";


contract Token is ERC20 {

	address internal protocol;
	bool internal locked = false;
	bool internal launched = false;
	address[] internal blacklist;

	address internal creator;
	string internal description;
	bytes internal image;
	string[] internal links;

	constructor(address _creator, string memory name, string memory symbol, string memory _desc, bytes memory _image, string[] memory _links, uint256 _supply, address _protocol) ERC20(name, symbol) {
		protocol = _protocol;
		creator = _creator;
		description = _desc;
		image = _image;
		links = _links;
		_mint(msg.sender, _supply);
	}

	function setBlacklist(address[] calldata _blacklist) external {
		require(msg.sender == protocol && launched == false);
		blacklist = _blacklist;
	}

	function lock() external {
		require(msg.sender == protocol && launched == false);
		locked = true;
	}

	function launch() external {
		require(msg.sender == protocol && launched == false);
		locked = false;
		launched = true;
		blacklist = new address[](0);
	}

	function updateMetadata(
		string calldata _desc,
		bytes calldata _image,
		string[] calldata _links
	) external {
		require(msg.sender == creator);

		if (bytes(_desc).length > 0) {
			description = _desc;
		}
		if (_image.length > 0) {
			image = _image;
		}

		links = _links;
	}

	function tokenURI(
		uint256 _unused
	)
		public
		view
		returns (string memory)
	{
		string memory linksString = '';
		for (uint256 i = 0; i < links.length; i++) {
			linksString = string.concat(linksString, '"', links[i], '"');
			if (i < links.length - 1) {
				linksString = string.concat(linksString, ",");
			}
		}

		return string.concat("data:application/json;base64,",
			Base64.encode(
				bytes(
					string.concat(
						"{",
						'"creator":"', LibString.toHexString(creator), '",',
						'"name":"', name(), '",',
						'"symbol":"', symbol(), '",',
						'"supply":"', LibString.toString(totalSupply() / (10 ** 18)), '",',
						'"description":"', description, '",',
						'"links":[',linksString,'],',
						'"image_data":"data:image/webp;base64,', Base64.encode(image), '",',
						'"background_color":"000000"',
						"}"
					)
				)
			)
		);
	}

	function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
		if (locked) {
			for (uint256 i = 0; i < blacklist.length; i++) {
				if (from == blacklist[i] || to == blacklist[i]) {
					revert("blacklisted");
				}
			}
			require(from == protocol || to == protocol, "transfer not allowed before launch");
		}
	}

}