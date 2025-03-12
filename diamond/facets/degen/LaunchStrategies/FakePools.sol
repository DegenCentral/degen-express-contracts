// SPDX-License-Identifier: UNKNOWN
pragma solidity 0.8.20;

// Contracts/Libraries/Modifiers
import { LibCore } from "../../../libraries/LibCore.sol";
import { LibFakePools } from "../../../libraries/LibFakePools.sol";
import { LibTokens } from "../../../libraries/LibTokens.sol";
import { LibUsd } from "../../../libraries/LibUsd.sol";
import { Diamondable } from "../../../Diamondable.sol";

// Facets
import { Core } from "../Core.sol";

// Interfaces
import { Token } from "../../../../Token.sol";

// Third Party
import { FixedPointMathLib } from "solady/src/utils/FixedPointMathLib.sol";


contract FakePools is Diamondable {

	function swapExactTokensForETH(LibFakePools.FakePool storage pool, uint256 tokens) internal returns (uint256) {
		uint256 out = getAmountOut(tokens, pool.tokenReserve, pool.ethReserve + pool.fakeEth);
		pool.tokenReserve += tokens;
		pool.ethReserve -= out;
		return out;
	}

	function swapExactETHForTokens(LibFakePools.FakePool storage pool, uint256 eth) internal returns (uint256) {
		uint256 out = getAmountOut(eth, pool.ethReserve + pool.fakeEth, pool.tokenReserve);
		pool.tokenReserve -= out;
		pool.ethReserve += eth;
		return out;
	}

	function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256) {
		uint256 numerator = amountIn * reserveOut;
		uint256 denominator = reserveIn + amountIn;
		return numerator / denominator;
	}

	function price(LibFakePools.FakePool storage pool, uint256 amount, bool ethOut) internal view returns (uint256) {
		if (ethOut) {
			return (amount * (pool.ethReserve + pool.fakeEth)) / pool.tokenReserve;
		} else {
			return (amount * pool.tokenReserve) / (pool.ethReserve + pool.fakeEth);
		}
	}

	function checkMarketCapThreshold(LibFakePools.FakePool storage pool) internal {
		uint256 ethPrice = price(pool, 1 ether, true);
		uint256 usdPrice = LibUsd.ethToUsd(ethPrice);
		uint256 usdMcap = FixedPointMathLib.mulWad(Token(pool.token).totalSupply(), usdPrice);

		if (usdMcap >= LibFakePools.store().usdMcapThreshold) {
			Core(address(this)).launch(pool.token);
		}
	}

	// PUBLIC

	function fakepool_stats(address token) public view returns (uint256, uint256, uint256, uint256) {
		LibFakePools.FakePool storage pool = LibFakePools.store().pools[token];
		return (pool.ethReserve, pool.tokenReserve, pool.fakeEth, price(pool, 1 ether, true));
	}

	function fakepool_quote(address token, uint256 amount, bool ethOut) public view returns (uint256) {
		LibFakePools.FakePool storage pool = LibFakePools.store().pools[token];
		if (ethOut) { // sell
			uint256 eth = getAmountOut(amount, pool.tokenReserve, (pool.ethReserve + pool.fakeEth));
			eth -= LibCore.calculateTradeFee(eth);
			return eth;
		} else { // buy
			uint256 txFee = LibCore.calculateTradeFee(amount);
			return getAmountOut(amount - txFee, (pool.ethReserve + pool.fakeEth), pool.tokenReserve);
		}
	}

	function fakepool_create(address token, uint256 supply, bytes calldata data) external onlyDiamond returns (uint256) {
		LibFakePools.FakePool storage pool = LibFakePools.store().pools[token];
		pool.token = token;
		pool.fakeEth = LibFakePools.store().fakeEth;
		pool.ethReserve = 0;
		pool.tokenReserve = supply;

		return price(pool, 1 ether, true);
	}

	function fakepool_close(address token) public onlyDiamond returns (uint256, uint256, uint256) {
		LibFakePools.Storage storage fp = LibFakePools.store();
		LibFakePools.FakePool memory pool = fp.pools[token];
		delete fp.pools[token];

		return (pool.ethReserve, pool.tokenReserve, pool.fakeEth);
	}

	function fakepool_buy(address token, uint256 ethIn) external onlyDiamond returns (uint256 tokensOut, uint256 p) {
		LibFakePools.FakePool storage pool = LibFakePools.store().pools[token];
		require(pool.token != address(0));

		tokensOut = swapExactETHForTokens(pool, ethIn);

		p = price(pool, 1 ether, true);

		checkMarketCapThreshold(pool);
	}

	function fakepool_sell(address token, uint256 amount) external onlyDiamond returns (uint256 ethOut, uint256 p) {
		LibFakePools.FakePool storage pool = LibFakePools.store().pools[token];
		require(pool.token != address(0));

		ethOut = swapExactTokensForETH(pool, amount);

		p = price(pool, 1 ether, true);

		checkMarketCapThreshold(pool);
	}

}
