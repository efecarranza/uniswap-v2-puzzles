// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Pair.sol";

contract ExactSwapWithRouter {
    error InsufficientOutput();
    error InsufficientLiquidity();

    /**
     *  PERFORM AN EXACT SWAP WITH ROUTER EXERCISE
     *
     *  The contract has an initial balance of 1 WETH.
     *  The challenge is to swap an exact amount of WETH for 1337 USDC token using UniswapV2 router.
     *
     */
    address public immutable router;

    constructor(address _router) {
        router = _router;
    }

    function performExactSwapWithRouter(
        address weth,
        address usdc,
        uint256 deadline
    ) public {
        address pool = 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc;
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = usdc;

        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pool)
            .getReserves();

        uint256 amountIn = getAmountIn(1337e6, reserve1, reserve0);
        IERC20(weth).approve(router, amountIn);
        IUniswapV2Router(router).swapExactTokensForTokens(
            amountIn,
            1337e6,
            path,
            address(this),
            deadline
        );
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256) {
        require(amountOut > 0, InsufficientOutput());
        require(reserveIn > 0 && reserveOut > 0, InsufficientLiquidity());
        require(reserveOut > amountOut, InsufficientLiquidity());

        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        return (numerator / denominator) + 1;
    }
}

interface IUniswapV2Router {
    /**
     *     amountIn: the amount of input tokens to swap.
     *     amountOutMin: the minimum amount of output tokens that must be received for the transaction not to revert.
     *     path: an array of token addresses. In our case, WETH and USDC.
     *     to: recipient address to receive the liquidity tokens.
     *     deadline: timestamp after which the transaction will revert.
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}
