// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Pair.sol";

/**
 *
 *  ARBITRAGE A POOL
 *
 * Given two pools where the token pair represents the same underlying; WETH/USDC and WETH/USDT (the formal has the correct price, while the latter doesnt).
 * The challenge is to flash borrow some USDC (>1000) from `flashLenderPool` to arbitrage the pool(s), then make profit by ensuring MyMevBot contract's USDC balance
 * is more than 0.
 *
 */
contract MyMevBot {
    error Invalid();

    address public USDC_WETH_pool = 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc;
    address public ETH_USDT_pool = 0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852;
    address public constant USDC_USDT_pool =
        0x3041CbD36888bECc7bbCBc0045E3B1f144466f5f;

    IUniswapV3Pool public immutable flashLenderPool;
    IERC20 public immutable weth;
    IERC20 public immutable usdc;
    IERC20 public immutable usdt;
    IUniswapV2Router public immutable router;
    bool public flashLoaned;

    constructor(
        address _flashLenderPool,
        address _weth,
        address _usdc,
        address _usdt,
        address _router
    ) {
        flashLenderPool = IUniswapV3Pool(_flashLenderPool);
        weth = IERC20(_weth);
        usdc = IERC20(_usdc);
        usdt = IERC20(_usdt);
        router = IUniswapV2Router(_router);
    }

    function performArbitrage() public {
        flashLenderPool.flash(
            address(this),
            1000e6,
            0,
            abi.encode(ETH_USDT_pool)
        );
    }

    function uniswapV3FlashCallback(
        uint256 _fee0,
        uint256,
        bytes calldata data
    ) external {
        callMeCallMe();

        address wethUsdtPool = abi.decode(data, (address));

        require(msg.sender == address(flashLenderPool), Invalid());

        uint256 balance = IERC20(usdc).balanceOf(address(this));
        address[] memory path = new address[](2);
        path[0] = address(usdc);
        path[1] = address(weth);
        usdc.approve(address(router), balance);

        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(USDC_WETH_pool)
            .getReserves();
        IUniswapV2Router(router).swapExactTokensForTokens(
            balance,
            getAmountOut(balance, reserve0, reserve1),
            path,
            address(this),
            block.timestamp
        );

        balance = weth.balanceOf(address(this));
        path[0] = address(weth);
        path[1] = address(usdt);
        weth.approve(address(router), balance);

        (reserve0, reserve1, ) = IUniswapV2Pair(wethUsdtPool).getReserves();
        IUniswapV2Router(router).swapExactTokensForTokens(
            balance,
            getAmountOut(balance, reserve0, reserve1),
            path,
            address(this),
            block.timestamp
        );

        balance = usdt.balanceOf(address(this));
        path[0] = address(usdt);
        path[1] = address(usdc);
        usdt.approve(address(router), balance);

        (reserve0, reserve1, ) = IUniswapV2Pair(USDC_USDT_pool).getReserves();
        IUniswapV2Router(router).swapExactTokensForTokens(
            balance,
            getAmountOut(balance, reserve1, reserve0),
            path,
            address(this),
            block.timestamp
        );

        usdc.transfer(address(flashLenderPool), 1000e6 + _fee0);
    }

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) internal pure returns (uint) {
        uint amountInWithFee = amountIn * 997; // 0.3% fee
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = (reserveIn * 1000) + amountInWithFee;
        return numerator / denominator;
    }

    function callMeCallMe() private {
        uint256 usdcBal = usdc.balanceOf(address(this));
        require(msg.sender == address(flashLenderPool), "not callback");
        require(
            flashLoaned = usdcBal >= 1000e6,
            "FlashLoan less than 1,000 USDC."
        );
    }
}

interface IUniswapV3Pool {
    /**
     * recipient: the address which will receive the token0 and/or token1 amounts.
     * amount0: the amount of USDC to borrow.
     * amount1: the amount of WETH to borrow.
     * data: any data to be passed through to the callback.
     */
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;
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
