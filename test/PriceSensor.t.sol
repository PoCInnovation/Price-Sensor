// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {IMangrove} from "mgv_src/IMangrove.sol";
import {MgvStructs} from "mgv_src/MgvLib.sol";
import {IERC20} from "mgv_src/IERC20.sol";
import {PriceSensor} from "../src/abstract/PriceSensor.sol";
import {ExampleImplementation} from "../src/example/ExampleImplementation.sol";

import {AbstractMangrove} from "mgv_src/AbstractMangrove.sol";
import {Mangrove} from "mgv_src/Mangrove.sol";
import {TransferLib} from "mgv_src/strategies/utils/TransferLib.sol";
import {TestToken} from "mgv_test/lib/tokens/TestToken.sol";

contract MangroveTestHelper {
    struct TokenOptions {
        string name;
        string symbol;
        uint8 decimals;
    }

    struct MangroveTestOptions {
        bool invertedMangrove;
        TokenOptions base;
        TokenOptions quote;
        uint defaultFee;
        uint gasprice;
        uint gasbase;
        uint gasmax;
        uint density;
    }
}

contract TestTokenHelper is TestToken {
    constructor(
        address admin,
        string memory name,
        string memory symbol,
        uint8 _decimals
    ) TestToken(admin, name, symbol, _decimals) {}

    function mint2(uint amount) external {
        _mint(msg.sender, amount);
    }
}

contract TestPriceSensor is Test, MangroveTestHelper {
    ExampleImplementation public priceSensor;
    address public account;
    AbstractMangrove internal mgv;

    MangroveTestOptions internal options =
        MangroveTestOptions({
            invertedMangrove: false,
            base: TokenOptions({
                name: "Base Token",
                symbol: "BASE",
                decimals: 18
            }),
            quote: TokenOptions({
                name: "Quote Token",
                symbol: "QUOTE",
                decimals: 18
            }),
            defaultFee: 0,
            gasprice: 40,
            gasbase: 50_000,
            density: 10,
            gasmax: 2_000_000
        });

    TestTokenHelper internal base;
    TestTokenHelper internal quote;

    function setUp() public virtual {
        account = vm.envAddress("ACCOUNT");

        // tokens
        base = new TestTokenHelper(
            address(this),
            options.base.name,
            options.base.symbol,
            options.base.decimals
        );
        vm.label(address(mgv), "BASE_TOKEN");
        quote = new TestTokenHelper(
            address(this),
            options.quote.name,
            options.quote.symbol,
            options.quote.decimals
        );
        vm.label(address(mgv), "QUOTE_TOKEN");

        // mangrove deploy
        mgv = new Mangrove({
            governance: address(this),
            gasprice: options.gasprice,
            gasmax: options.gasmax
        });
        vm.label(address(mgv), "MGV");

        // reader = new MgvReader($(mgv));

        // below are necessary operations because testRunner acts as a taker/maker in some core protocol tests
        // TODO this should be done somewhere else
        //provision mangrove so that testRunner can post offers
        mgv.fund{value: 10 ether}();
        // approve mangrove so that testRunner can take offers on Mangrove
        TransferLib.approveToken(base, address(mgv), type(uint).max);
        TransferLib.approveToken(quote, address(mgv), type(uint).max);

        mgv.activate(
            address(base),
            address(quote),
            options.defaultFee,
            options.density,
            options.gasbase
        );
        mgv.activate(
            address(quote),
            address(base),
            options.defaultFee,
            options.density,
            options.gasbase
        );
        // logging
        vm.label(address(base), IERC20(base).symbol());
        vm.label(address(quote), IERC20(quote).symbol());

        priceSensor = new ExampleImplementation(address(mgv), address(this));

        uint256 mintAmount = 100 * 1e18;
        address router = address(priceSensor.router());

        base.mint2(mintAmount);
        quote.mint2(mintAmount);

        base.approve(router, mintAmount);
        quote.approve(router, mintAmount);

        base.approve(address(mgv), mintAmount);
        quote.approve(address(mgv), mintAmount);

        base.approve(address(priceSensor), mintAmount);
        quote.approve(address(priceSensor), mintAmount);

        vm.prank(address(priceSensor));
        base.approve(address(mgv), mintAmount);

        console.log(quote.allowance(address(this), address(priceSensor)));
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
        address[] memory uniswapPools = new address[](0);
        // uniswapPools[0] = address(0);

        vm.pauseGasMetering();

        // for 0.68 token in we get 1 token out
        uint256 price = 0.68 ether;

        uint256 offerId = priceSensor.newSensor{value: 0.01 ether}(
            uniswapPools,
            address(base),
            address(quote),
            price
        );

        console.log("offerId: %s", offerId);
        console.log("priceSensor: %s", address(priceSensor));

        console.log(address(this));
        console.log(IERC20(base).balanceOf(address(this)));
        console.log(IERC20(quote).balanceOf(address(this)));
        console.log(
            IERC20(base).allowance(address(this), address(priceSensor))
        );
        console.log(IERC20(quote).allowance(address(this), address(mgv)));

        uint256[4][] memory targets = new uint[4][](1);
        /* offerId          */ targets[0][0] = offerId;
        /* takerWants       */ targets[0][1] = 1 * 1e10;
        /* takerGives       */ targets[0][2] = 0.68 * 1e10;
        /* gasreq_permitted */ targets[0][3] = 30_000;

        console.log(address(this).balance);
        console.log(address(priceSensor).balance);
        console.log(address(mgv).balance);

        (
            uint successes,
            uint takerGot,
            uint takerGave,
            uint bounty,
            uint fee
        ) = mgv.snipes(address(base), address(quote), targets, true);
        console.log("successes: %s", successes);
        console.log("takerGot: %s", takerGot);
        console.log("takerGave: %s", takerGave);
        console.log("bounty: %s", bounty);
        console.log("fee: %s", fee);
    }
}
