// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {IMangrove} from "mgv_src/IMangrove.sol";
import {MgvStructs} from "mgv_src/MgvLib.sol";
import {IERC20} from "mgv_src/IERC20.sol";
import {PriceSensor} from "../src/abstract/PriceSensor.sol";
import {ExampleImplementation} from "../src/example/ExampleImplementation.sol";

address constant MGV = 0xd1805f6Fe12aFF69D4264aE3e49ef320895e2D8b;
address constant USDT = 0xe8099699aa4A79d89dBD20A63C50b7d35ED3CD9e;
address constant WMATIC = 0x193163EeFfc795F9d573b171aB12cCDdE10392e8;

address constant TOKENS_ADMIN = 0x47897EE61498D02B18794601Ed3A71896A1Ff894;

interface ITestToken {
    function setMintLimit(uint256 amount) external;

    function mintTo(address to, uint256 amount) external;

    function approve(address to, uint256 amount) external;
}

contract TestPriceSensor is Test {
    ExampleImplementation public priceSensor;
    address public account;
    IMangrove public mgv;

    function setUp() public {
        priceSensor = new ExampleImplementation(MGV, address(this));
        account = vm.envAddress("ACCOUNT");
        mgv = IMangrove(payable(MGV));

        setLimit();
    }

    function setLimit() public {
        vm.prank(TOKENS_ADMIN);
        ITestToken(USDT).setMintLimit(100 ether);
    }

    function setupTokens() public {
        address self = address(this);
        uint256 mintAmount = 1 * 1e18;

        // see https://mumbai.polygonscan.com/address/0xe8099699aa4A79d89dBD20A63C50b7d35ED3CD9e
        // contract creator is also an admin
        vm.startPrank(TOKENS_ADMIN);
        ITestToken(USDT).mintTo(self, mintAmount);
        ITestToken(WMATIC).mintTo(self, mintAmount);
        vm.stopPrank();

        address router = address(priceSensor.router());

        ITestToken(USDT).approve(router, mintAmount);
        ITestToken(WMATIC).approve(router, mintAmount);

        ITestToken(USDT).approve(MGV, mintAmount);
        ITestToken(WMATIC).approve(MGV, mintAmount);

        ITestToken(USDT).approve(address(priceSensor), mintAmount);
        ITestToken(WMATIC).approve(address(priceSensor), mintAmount);
    }

    // function test_newSensor() public {
    //     address[] memory uniswapPools = new address[](1);
    //     uniswapPools[0] = address(0);

    //     uint256 offerId = priceSensor.newSensor{value: 0.001 * 1e18}(
    //         uniswapPools,
    //         USDT,
    //         WMATIC,
    //         0.68 * 1e18
    //     );

    //     assert(offerId != 0);
    // }

    // function test_removePriceSensor() public {
    //     address[] memory uniswapPools = new address[](1);
    //     uniswapPools[0] = address(0);

    //     uint256 offerId = priceSensor.newSensor{value: 0.001 * 1e18}(
    //         uniswapPools,
    //         USDT,
    //         WMATIC,
    //         0.68 * 1e18
    //     );

    //     uint256 provision = priceSensor.removeSensor(USDT, WMATIC, offerId);

    //     assert(provision > 0);
    // }

    function test_snipeSensor() public {
        address[] memory uniswapPools = new address[](1);
        uniswapPools[0] = address(0);

        // for 0.68 token in we get 1 token out
        uint256 price = 0.68 ether;

        uint256 offerId = priceSensor.newSensor{value: 0.001 * 1e18}(
            uniswapPools,
            USDT,
            WMATIC,
            price
        );

        setupTokens();

        console.log("offerId: %s", offerId);
        console.log("priceSensor: %s", address(priceSensor));

        console.log(address(this));
        console.log(IERC20(USDT).balanceOf(address(this)));
        console.log(IERC20(WMATIC).balanceOf(address(this)));
        console.log(
            IERC20(USDT).allowance(address(this), address(priceSensor))
        );
        console.log(IERC20(WMATIC).allowance(address(this), MGV));

        uint256[4][] memory targets = new uint[4][](1);
        /* offerId          */ targets[0][0] = offerId;
        /* takerWants       */ targets[0][1] = 1 * 1e10;
        /* takerGives       */ targets[0][2] = 0.68 * 1e10;
        /* gasreq_permitted */ targets[0][3] = 30_000;

        console.log(address(this).balance);
        console.log(address(priceSensor).balance);
        console.log(address(MGV).balance);

        (
            uint successes,
            uint takerGot,
            uint takerGave,
            uint bounty,
            uint fee
        ) = mgv.snipes(USDT, WMATIC, targets, true);
        console.log("successes: %s", successes);
        console.log("takerGot: %s", takerGot);
        console.log("takerGave: %s", takerGave);
        console.log("bounty: %s", bounty);
        console.log("fee: %s", fee);
    }
}
