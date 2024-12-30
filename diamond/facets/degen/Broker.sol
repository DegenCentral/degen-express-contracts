// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.18;

// Contracts/Libraries/Modifiers
import { LibTokens } from "../../libraries/LibTokens.sol";
import { LibDex } from "../../libraries/LibDex.sol";
import { EIP712 } from "solady/src/utils/EIP712.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";

// Facets
import { Core } from "./Core.sol";


contract Broker is EIP712 {
	struct Nonces {
		uint256 create;
		uint256 buy;
		uint256 sell;
	}

	struct Storage {
		mapping (address => Nonces) nonces;
	}

	function store() internal pure returns (Storage storage s) {
		bytes32 position = keccak256("diamond.broker.storage");
		assembly { s.slot := position }
	}

	function nonces(address user) public view returns (Nonces memory) {
		return store().nonces[user];
	}

	function _domainNameAndVersion()
		internal
		view
		virtual
		override
		returns (string memory name, string memory version)
	{
		name = "Degen Express";
		version = "1";
	}

	function verifyOrder(bytes32 structHash, bytes memory signature, address signer) internal view {
		bytes32 digest = _hashTypedData(structHash);
		address _signer = ECDSA.recover(digest, signature);
		require(_signer == signer, "invalid signer");
	}

	struct CreationOrder {
		address creator;
    string name;
		string symbol;
		string description;
		bytes image;
		string[] links;
		bytes data;
		uint8 strategy;
		uint8 dex;
		uint256 initialBuy;
		uint256 nonce;
		uint256 deadline;
	}

	function createFor(CreationOrder calldata order, bytes memory signature) public payable {
		require(block.timestamp <= order.deadline, "expired");
		require(store().nonces[order.creator].create == order.nonce, "nonce already used");
		require(msg.value > order.initialBuy, "invalid amount");

		verifyOrder(
			keccak256(abi.encode(
				keccak256("CreationOrder(address creator,string name,string symbol,string description,bytes image,string[] links,bytes data,uint8 strategy,uint8 dex,uint256 initialBuy,uint256 nonce,uint256 deadline;)"),
				order.creator,
				order.name,
				order.symbol,
				order.description,
				order.image,
				order.links,
				order.data,
				order.strategy,
				order.dex,
				order.initialBuy,
				order.nonce,
				order.deadline
			)),
			signature,
			order.creator
		);

		store().nonces[order.creator].create++;

		Core(address(this))._create(
			order.creator,
			order.name,
			order.symbol,
			order.description,
			order.image,
			order.links,
			order.data,
			LibTokens.LaunchStrategy(order.strategy),
			LibDex.Dex(order.dex),
			order.initialBuy,
			msg.value
		);
	}

	struct BuyOrder {
    address buyer;
    address token;
		uint256 amount;
		uint256 min;
    uint256 nonce;
		uint256 deadline;
	}

	function buyFor(BuyOrder calldata order, bytes memory signature) public payable {
		require(block.timestamp <= order.deadline, "expired");
		require(store().nonces[order.buyer].buy == order.nonce, "nonce already used");
		require(order.amount == msg.value, "invalid amount");

		verifyOrder(
			keccak256(abi.encode(
				keccak256("BuyOrder(address buyer,address token,uint256 amount,uint256 min,uint256 nonce,uint256 deadline)"),
				order.buyer,
				order.token,
				order.amount,
				order.min,
				order.nonce,
				order.deadline
			)),
			signature,
			order.buyer
		);

		store().nonces[order.buyer].buy++;

		Core(address(this))._buy(order.buyer, order.token, order.amount, order.min);
	}


	struct SellOrder {
    address seller;
    address token;
		uint256 amount;
		uint256 min;
    uint256 nonce;
		uint256 deadline;
	}

	function sellFor(SellOrder calldata order, bytes memory signature) public {
		require(block.timestamp <= order.deadline, "expired");
		require(store().nonces[order.seller].sell == order.nonce, "nonce already used");

		verifyOrder(
			keccak256(abi.encode(
				keccak256("SellOrder(address seller,address token,uint256 amount,uint256 min,uint256 nonce,uint256 deadline)"),
				order.seller,
				order.token,
				order.amount,
				order.min,
				order.nonce,
				order.deadline
			)),
			signature,
			order.seller
		);

		store().nonces[order.seller].sell++;

		Core(address(this))._sell(order.seller, order.token, order.amount, order.min);
	}
	
}
