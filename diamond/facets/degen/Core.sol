// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.20;

// Contracts/Libraries/Modifiers
import { LibCore } from "../../libraries/LibCore.sol";
import { LibUsd } from "../../libraries/LibUsd.sol";
import { LibDiamond } from "../../libraries/LibDiamond.sol";
import { LibTokens } from "../../libraries/LibTokens.sol";
import { LibDex } from "../../libraries/LibDex.sol";
import { LibLST } from "../../libraries/LibLST.sol";
import { Diamondable } from "../../Diamondable.sol";
import { Ownable } from "../../Ownable.sol";
import { Haltable } from "../../Haltable.sol";

// Facets
import { FakePools } from "./LaunchStrategies/FakePools.sol";
import { Launcher } from "./Launcher.sol";
import { Degen } from "./Degen.sol";

// Interfaces
import { Token } from "../../../Token.sol";


contract Core is Diamondable, Ownable, Haltable {
	event TokenCreated(
		address token,
		address creator,
		LibTokens.LaunchStrategy strategy,
		LibDex.Dex dex,
		bytes data,
		uint256 price
	);
	event TokenLaunched(
		address token,
		address creator,
		LibTokens.LaunchStrategy strategy,
		LibDex.Dex dex,
		address pair
	);

	function create(
		string calldata name,
		string calldata symbol,
		string calldata description,
		bytes calldata image,
		string[] calldata links,
		bytes calldata data,
		LibTokens.LaunchStrategy strategy,
		LibDex.Dex dex,
		uint256 initialBuy
	) public payable returns (address) {
		return Core(address(this))._create(msg.sender, name, symbol, description, image, links, data, strategy, dex, initialBuy, msg.value);
	}

	function _create(
		address creator,
		string calldata name,
		string calldata symbol,
		string calldata description,
		bytes calldata image,
		string[] calldata links,
		bytes calldata data,
		LibTokens.LaunchStrategy strategy,
		LibDex.Dex dex,
		uint256 initialBuy,
		uint256 eth
	) public onlyDiamond checkHalted returns (address) {
		require(
			bytes(name).length <= 18 &&
			bytes(symbol).length <= 18 &&
			bytes(image).length <= 1e7 &&
			bytes(description).length <= 512,
			"invalid name/symbol/image/desc"
		);

		require(links.length < 5, "4 links max");
		for (uint8 i = 0; i < links.length; i++) {
			require(bytes(links[i]).length <= 128, "link too long");
		}

		LibCore.Storage storage d = LibCore.store();

		Token token = new Token(creator, name, symbol, description, image, links, d.tokenSupply, address(this));
		address tokenAddress = address(token);

		uint256 price;
		if (strategy == LibTokens.LaunchStrategy.FakeLiquidity) {
			(price) = FakePools(address(this)).fakepool_create(tokenAddress, d.tokenSupply, data);
		} else {
			revert("invalid strategy");
		}

		address pair = LibDex.createPair(dex, tokenAddress);

		LibTokens.store().tokens[tokenAddress] = LibTokens.TokenInfo(
			creator,
			strategy,
			dex,
			pair,
			false
		);
		 
		emit TokenCreated(tokenAddress, creator, strategy, dex, data, price);

		uint256 creationEth = LibUsd.usdToEth(d.creationPrice);
		require(eth >= creationEth, "usd price changed");

		eth -= creationEth;
		LibCore.gatherProceeds(creationEth);

		if (initialBuy > 0) {
			_buy(creator, tokenAddress, initialBuy, 0, block.timestamp);
			eth -= initialBuy;
		}

		if (eth > 0) {
			(bool sent,) = creator.call{ value: eth }(""); // refund dust
			require(sent);
		}

		Token(tokenAddress).lock();

		return tokenAddress;
	}

	function tokenInfo(address token) public view returns (LibTokens.TokenInfo memory) {
		return LibTokens.store().tokens[token];
	}

	function quote(address token, uint256 amount, bool ethOut) public view returns(uint256) {
		LibTokens.LaunchStrategy strategy = LibTokens.store().tokens[token].strategy;

		if (strategy == LibTokens.LaunchStrategy.FakeLiquidity) {
			return FakePools(address(this)).fakepool_quote(token, amount, ethOut);
		} else {
			revert("invalid strategy");
		}
	}

	event Bought(address buyer, address token, uint256 ethIn, uint256 tokensOut, uint256 priceNew);

	function buy(address token, uint256 min, uint256 deadline) public payable {
		Core(address(this))._buy(msg.sender, token, msg.value, min, deadline);
	}
	function _buy(address buyer, address token, uint256 ethIn, uint256 min, uint256 deadline) public onlyDiamond checkHalted {
		LibTokens.LaunchStrategy strategy = LibTokens.store().tokens[token].strategy;
		require(deadline >= block.timestamp, "deadline passed");

		Degen(address(this)).attributeXp(buyer, Degen.XpType.Buy, ethIn);

		ethIn = LibCore.deductTradeFee(ethIn);

		LibLST.addLiquidity(ethIn);

		(uint256 tokensOut, uint256 price) = (0, 0);
		if (strategy == LibTokens.LaunchStrategy.FakeLiquidity) {
			(tokensOut, price) = FakePools(address(this)).fakepool_buy(token, ethIn);
		} else {
			revert("invalid strategy");
		}

		if (min != 0) require(tokensOut >= min, "amount out lower than min");

		Token(token).transfer(buyer, tokensOut); // Transfer tokens to buyer

		emit Bought(buyer, token, ethIn, tokensOut, price);
	}

	event Sold(address seller, address token, uint256 ethOut, uint256 tokensIn, uint256 priceNew);

	function sell(address token, uint256 amount, uint256 min, uint256 deadline) public {
		Core(address(this))._sell(msg.sender, token, amount, min, deadline);
	}
	function _sell(address seller, address token, uint256 amount, uint256 min, uint256 deadline) public onlyDiamond checkHalted {
		LibTokens.LaunchStrategy strategy = LibTokens.store().tokens[token].strategy;
		require(deadline >= block.timestamp, "deadline passed");

		(uint256 ethOut, uint256 price) = (0, 0);
		if (strategy == LibTokens.LaunchStrategy.FakeLiquidity) {
			(ethOut, price) = FakePools(address(this)).fakepool_sell(token, amount);
		} else {
			revert("invalid strategy");
		}

		Degen(address(this)).attributeXp(seller, Degen.XpType.Sell, ethOut);

		LibLST.removeLiquidity(ethOut);

		ethOut = LibCore.deductTradeFee(ethOut);

		if (min != 0) require(ethOut >= min, "amount out lower than min");

		Token(token).transferFrom(seller, address(this), amount); // Transfer tokens from seller
		(bool sent,) = seller.call{ value: ethOut }(""); require(sent); // Transfer eth to seller
		
		emit Sold(seller, token, ethOut, amount, price);
	}

	function launch(address token) public onlyDiamond checkHalted {
		LibTokens.TokenInfo storage info = LibTokens.store().tokens[token];
		require(info.creator != address(0), "invalid token");

		uint256 ethReserve;
		if (info.strategy == LibTokens.LaunchStrategy.FakeLiquidity) {
			(ethReserve,,,) = FakePools(address(this)).fakepool_stats(token);
		} else {
			revert("invalid strategy");
		}
		LibLST.removeLiquidity(ethReserve);

		Token(token).launch();
		
		(address pair, uint256 eth,) = Launcher(address(this)).launch(token, info);

		Degen(address(this)).attributeXp(info.creator, Degen.XpType.Launch, eth);

		info.pair = pair;
		info.launched = true;
		emit TokenLaunched(token, info.creator, info.strategy, info.dex, pair);
	}

	function force_launch(address token) external onlyOwner {
		Core(address(this)).launch(token);
	}

}
