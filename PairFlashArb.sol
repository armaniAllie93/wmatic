// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.7.6 <=0.8.18;
pragma abicoder v2;
//pragma experimental ABIEncoderV2;

import '@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3FlashCallback.sol';
//import '@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol';
import '@uniswap/v3-core/contracts/libraries/LowGasSafeMath.sol';
import '@uniswap/v3-periphery/contracts/base/PeripheryPayments.sol';
//import'uniswap/v3-periphery/contracts/base/PeripheryImmutableState.sol'
import '@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol';
import '@uniswap/v3-periphery/contracts/libraries/CallbackValidation.sol';
//import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolActions.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
//import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolState.sol';
//import '@uniswap/v3-core/contracts/libraries/FixedPoint96.sol';
//import '@uniswap/v3-core/contracts/libraries/SqrtPriceMath.sol';
//import '@uniswap/v3-core/contracts/libraries/SafeCast.sol';


contract PairFlashArb {
    ISwapRouter constant router =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    uint160 internal constant MAX_SQRT_RATIO =
        1461446703485210103287273052203988822378723970342;

    

    //address private constant WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;


    //IERC20 private constant wmatic = IERC20(WMATIC);

    function flashswap(
        address pool0,
        address pool1,
        address token0,
        address token1,
        address token2,
        uint24 flashfee,
        uint24 pool2fee,
        uint256 AmountIn0,
        uint256 AmountIn1
    ) external {
        bytes memory data = abi.encode(msg.sender, pool0, pool1, token0, token1, token2, flashfee, pool2fee, AmountIn0, AmountIn1);

        IUniswapV3PoolActions pool = IUniswapV3PoolActions(pool0);

        pool.flash(
            address(this),
            AmountIn0,
            AmountIn1,
            data
        );
    }

    //swaps WMATIC to seocnd token then back to WMATIC
    function _swap(
        address poolIn,
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint amountIn
    ) private returns (uint amountOut) {
        (uint160 sqrtPriceX962,,,,,,) = IUniswapV3Pool(poolIn).slot0();
        IERC20(tokenIn).approve(address(router), amountIn + 10000);
        //swap wmatic in another pool
        ISwapRouter.ExactInputSingleParams memory params = 
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: (amountIn * (uint256(sqrtPriceX962) * uint256(sqrtPriceX962) / (uint256(1) << (96 * 2 - 36)))) * (100 - 1) / 100, //too little received
                sqrtPriceLimitX96: uint160((uint256(sqrtPriceX962) * 99) / 100)
            });

        amountOut = router.exactInputSingle(params);
    }
    // 
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
        (address caller, address pool0, address pool1, address token0, address token1, address token2, uint24 flashfee, uint24 pool2fee, uint256 AmountIn0, uint256 AmountIn1) = abi.decode(
            data,
            (address, address, address, address, address, address, uint24, uint24, uint256, uint256)
        );


        CallbackValidation.verifyCallback(0x86f1d8390222A3691C28938eC7404A1661E618e0, token0, token1, flashfee);

        //Approve Tokens

        TransferHelper.safeApprove(token0, address(router), AmountIn0 + 100000);
        TransferHelper.safeApprove(token1, address(router), AmountIn1 + 1000000);
        TransferHelper.safeApprove(token2, address(router), 1000000000);
        

        require(msg.sender == address(pool0), "not authorized");


        //second pool declared

        //obtaining second pool fee

        //To avoid reentrancy, 
        //a common approach with Uniswap V3 flash integrations is to 
        //use one pool with a fee tier to call flash, 
        //followed by another pool with the same tokens but a different fee tier to call swap
        //----WMATIC to DUST
        uint token2AmountOut = _swap(pool1, token0, token2, pool2fee, AmountIn0);

        //----DUST back to WMATIC
        uint token0AmountOut = _swap(pool1, token2, token0, pool2fee, token2AmountOut);
        

        //profitability check
        if (token0AmountOut >= AmountIn0) {
            uint profit = LowGasSafeMath.sub(token0AmountOut, AmountIn0);
            IERC20(token0).transfer(address(pool0), AmountIn0);
            IERC20(token0).transfer(caller, profit);
        } else {
            uint loss = LowGasSafeMath.sub(AmountIn0, token0AmountOut);
            IERC20(token0).transferFrom(caller, address(this), loss);
            IERC20(token0).transfer(address(pool0), AmountIn0);
        }
    }
}

