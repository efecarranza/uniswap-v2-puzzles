// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {console2} from "forge-std/Test.sol";
import {IERC20} from "src/interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Pair.sol";

contract AddLiquid {
    error InvalidAmount();
    error InvalidLiquidity();

    /**
     *  ADD LIQUIDITY WITHOUT ROUTER EXERCISE
     *
     *  The contract has an initial balance of 1000 USDC and 1 WETH.
     *  Mint a position (deposit liquidity) in the pool USDC/WETH to msg.sender.
     *  The challenge is to provide the same ratio as the pool then call the mint function in the pool contract.
     *
     */
    function addLiquidity(
        address usdc,
        address weth,
        address pool,
        uint256 usdcReserve,
        uint256 wethReserve
    ) public {
        uint256 amount0;
        uint256 amount1;

        IUniswapV2Pair pair = IUniswapV2Pair(pool);

        uint256 balanceUsdc = IERC20(usdc).balanceOf(address(this));
        uint256 balanceWeth = IERC20(weth).balanceOf(address(this));

        if (usdcReserve == 0 && wethReserve == 0) {
            (amount0, amount1) = (balanceUsdc, balanceWeth);
        } else {
            uint256 amount1Optimal = getAmount(
                balanceUsdc,
                usdcReserve,
                wethReserve
            );
            if (amount1Optimal <= balanceWeth) {
                (amount0, amount1) = (balanceUsdc, amount1Optimal);
            } else {
                uint256 amount0Optimal = getAmount(
                    balanceWeth,
                    wethReserve,
                    usdcReserve
                );
                assert(amount0Optimal <= balanceUsdc);
                (amount0, amount1) = (amount0Optimal, balanceWeth);
            }
        }

        IERC20(usdc).transfer(address(pair), amount0);
        IERC20(weth).transfer(address(pair), amount1);

        pair.mint(msg.sender);
    }

    function getAmount(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256) {
        require(amountA > 0, InvalidAmount());
        require(reserveA > 0 && reserveB > 0, InvalidLiquidity());
        return (amountA * reserveB) / reserveA;
    }
}
