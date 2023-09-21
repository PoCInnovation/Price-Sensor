// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import {Test2} from "mgv_lib/Test2.sol";
import {Test, console} from "forge-std/Test.sol";

import {IMangrove} from "mgv_src/IMangrove.sol";
import {MgvStructs} from "mgv_src/MgvLib.sol";
import {IERC20} from "mgv_src/IERC20.sol";
import {PriceSensor} from "../src/abstract/PriceSensor.sol";
import {ExampleImplementation} from "../src/example/ExampleImplementation.sol";

import {AbstractMangrove} from "mgv_src/AbstractMangrove.sol";
import {Mangrove} from "mgv_src/Mangrove.sol";
import {TransferLib} from "mgv_src/strategies/utils/TransferLib.sol";
import {TestToken} from "mgv_test/lib/tokens/TestToken.sol";
import {AbstractRouter} from "mgv_src/strategies/routers/AbstractRouter.sol";

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

contract TestPriceSensor is Test2, MangroveTestHelper {
    ExampleImplementation internal priceSensor;
    AbstractMangrove internal mgv;
    AbstractRouter internal router;

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
        /**
         * @notice Labels map:
         *
         * | Label    | Value                   |
         * |----------|-------------------------|
         * | TEST     |  address(this)          |
         * | MGV      |  mgv                    |
         * | SENSOR   |  priceSensor            |
         * | ROUTER   |  priceSensor.router()   |
         * | BASE     |  base                   |
         * | QUOTE    |  quote                  |
         */

        /**
         * Setup mangrove
         */
        mgv = new Mangrove({
            governance: address(this),
            gasprice: options.gasprice,
            gasmax: options.gasmax
        });
        // provision mangrove so that testRunner can post offers
        mgv.fund{value: 10 ether}();

        /**
         * Setup test tokens
         */
        base = new TestTokenHelper(
            address(this),
            options.base.name,
            options.base.symbol,
            options.base.decimals
        );
        quote = new TestTokenHelper(
            address(this),
            options.quote.name,
            options.quote.symbol,
            options.quote.decimals
        );
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

        /**
         * Setup price sensor
         */
        priceSensor = new ExampleImplementation(address(mgv), address(this));
        router = priceSensor.router();

        /**
         * Setup labels
         */
        vm.label(address(this), "TEST");
        vm.label(address(mgv), "MGV");
        vm.label(address(base), IERC20(base).symbol());
        vm.label(address(quote), IERC20(quote).symbol());
        vm.label(address(priceSensor), "SENSOR");
        vm.label(address(router), "ROUTER");

        /**
         * Mint tokens
         */
        uint256 mintAmount = 1000 * 1e18;

        base.mint2(mintAmount);
        quote.mint2(mintAmount);

        /**
         * Setup allowances
         */

        // To take an offer a user will give BASE to get QUOTE
        // so TEST needs to approve BASE to ROUTER
        // vm.prank(address(this)); (unnecessary)
        base.approve(address(router), mintAmount);
        // Then the smart contract will give QUOTE to the user
        // so SENSOR needs to approve QUOTE to ROUTER and MGV
        vm.prank(address(priceSensor));
        quote.approve(address(router), mintAmount);
        // SENSOR needs to approve BASE to MGV
        // so that MGV can take the offer
        vm.prank(address(priceSensor));
        base.approve(address(mgv), mintAmount);
    }

    /**
     *  UTILS
     */

    /* Log OB with console */
    function printOrderBook(address $out, address $in) internal view {
        uint offerId = mgv.best($out, $in);
        TestToken req_tk = TestToken($in);
        TestToken ofr_tk = TestToken($out);

        console.log(
            string.concat(
                unicode"┌────┬──Best offer: ",
                vm.toString(offerId),
                unicode"──────"
            )
        );
        while (offerId != 0) {
            (
                MgvStructs.OfferUnpacked memory ofr,
                MgvStructs.OfferDetailUnpacked memory detail
            ) = mgv.offerInfo($out, $in, offerId);
            console.log(
                string.concat(
                    unicode"│ ",
                    string.concat(offerId < 9 ? " " : "", vm.toString(offerId)), // breaks on id>99
                    unicode" ┆ ",
                    string.concat(
                        toFixed(ofr.wants, req_tk.decimals()),
                        " ",
                        req_tk.symbol()
                    ),
                    "  /  ",
                    string.concat(
                        toFixed(ofr.gives, ofr_tk.decimals()),
                        " ",
                        ofr_tk.symbol()
                    ),
                    " ",
                    vm.toString(detail.maker)
                )
            );
            offerId = ofr.next;
        }
        console.log(unicode"└────┴─────────────────────");
    }

    function test_newSensor() public {
        address[] memory uniswapPools = new address[](1);
        uniswapPools[0] = address(0);

        uint256 offerId = priceSensor.newSensor{value: 0.01 ether}(
            uniswapPools,
            address(base),
            address(quote),
            0.68 * 1e18
        );

        assertEq(offerId, 1);
    }

    function test_removePriceSensor() public {
        address[] memory uniswapPools = new address[](1);
        uniswapPools[0] = address(0);

        uint256 offerId = priceSensor.newSensor{value: 0.01 ether}(
            uniswapPools,
            address(base),
            address(quote),
            0.68 * 1e18
        );

        uint256 provision = priceSensor.removeSensor(
            address(base),
            address(quote),
            offerId
        );

        assert(provision > 0);
    }

    // fake uniswap pool
    // and populate its slot0

    function test_snipeSensor() public {
        vm.pauseGasMetering();

        address[] memory uniswapPools = new address[](0);
        // uniswapPools[0] = ;

        // for 0.5 token in we get 1 token out
        uint256 price = 0.5 ether;
        uint256 offerId = priceSensor.newSensor{value: 0.01 ether}(
            uniswapPools,
            address(base),
            address(quote),
            price
        );

        console.log("offerId: %s", offerId);

        printOrderBook(address(base), address(quote));

        uint256[4][] memory targets = new uint[4][](1);
        /* offerId          */ targets[0][0] = offerId;
        /* takerWants       */ targets[0][1] = 0.000000000000002 ether;
        /* takerGives       */ targets[0][2] = 0.000000000000002 ether;
        /* gasreq_permitted */ targets[0][3] = 30_000;

        (
            uint successes,
            uint takerGot,
            uint takerGave,
            uint bounty,
            uint fee
        ) = mgv.snipes(address(base), address(quote), targets, true);

        assertEq(successes, 1);

        console.log("successes: %s", successes);
        console.log("takerGot: %s", takerGot);
        console.log("takerGave: %s", takerGave);
        console.log("bounty: %s", bounty);
        console.log("fee: %s", fee);

        printOrderBook(address(base), address(quote));
    }

    function test_autoRemoveSensorWithoutUniswapPools() public {
        vm.pauseGasMetering();

        address[] memory uniswapPools = new address[](0);

        // for 0.5 token in we get 1 token out
        uint256 price = 0.5 ether;
        uint256 offerId = priceSensor.newSensor{value: 0.01 ether}(
            uniswapPools,
            address(base),
            address(quote),
            price
        );

        uint256[4][] memory targets = new uint[4][](1);
        /* offerId          */ targets[0][0] = offerId;
        /* takerWants       */ targets[0][1] = 0.000000000000002 ether;
        /* takerGives       */ targets[0][2] = 0.000000000000002 ether;
        /* gasreq_permitted */ targets[0][3] = 30_000;

        (uint successes, , , , ) = mgv.snipes(
            address(base),
            address(quote),
            targets,
            true
        );
        assertEq(successes, 1);

        (MgvStructs.OfferUnpacked memory ofr, ) = mgv.offerInfo(
            address(base),
            address(quote),
            0
        );

        assertEq(ofr.gives, 0);
    }
}
