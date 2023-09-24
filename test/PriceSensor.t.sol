// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

import {Mangrove} from "mgv_src/Mangrove.sol";
import {IMangrove} from "mgv_src/IMangrove.sol";
import {MgvStructs} from "mgv_src/MgvLib.sol";
import {IERC20} from "mgv_src/IERC20.sol";
import {TransferLib} from "mgv_src/strategies/utils/TransferLib.sol";
import {AbstractMangrove} from "mgv_src/AbstractMangrove.sol";
import {AbstractRouter} from "mgv_src/strategies/routers/AbstractRouter.sol";
import {IOfferLogic} from "mgv_src/strategies/interfaces/IOfferLogic.sol";

import {TestToken} from "mgv_test/lib/tokens/TestToken.sol";

import {Test2} from "mgv_lib/Test2.sol";

import {IPriceSensor} from "../src/IPriceSensor.sol";
import {TestImplementation} from "./utils/TestImplementation.sol";

contract MyTest is Test2 {
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

    /* counts the offers of a given pair */
    function countOffers(
        AbstractMangrove mgv,
        address $out,
        address $in
    ) public view returns (uint256 count) {
        uint offerId = mgv.best($out, $in);
        while (offerId != 0) {
            count++;
            (MgvStructs.OfferUnpacked memory ofr, ) = mgv.offerInfo(
                $out,
                $in,
                offerId
            );
            offerId = ofr.next;
        }
    }

    /* Log OB with console */
    function printOrderBook(
        AbstractMangrove mgv,
        address $out,
        address $in
    ) internal view {
        uint offerId = mgv.best($out, $in);
        TestToken req_tk = TestToken($in);
        TestToken ofr_tk = TestToken($out);

        // prettier-ignore
        console.log(string.concat(unicode"┌────┬──Best offer: ", vm.toString(offerId), unicode"──────"));
        while (offerId != 0) {
            (
                MgvStructs.OfferUnpacked memory ofr,
                MgvStructs.OfferDetailUnpacked memory detail
            ) = mgv.offerInfo($out, $in, offerId);
            console.log(
                // prettier-ignore
                string.concat(
                    unicode"│ ", string.concat(offerId < 10 ? " " : "", vm.toString(offerId)), // breaks on id>99
                    unicode" ┆ ", string.concat(toFixed(ofr.wants, req_tk.decimals()), " ", req_tk.symbol()),
                    "  /  ", string.concat(toFixed(ofr.gives, ofr_tk.decimals()), " ", ofr_tk.symbol()),
                    " ", vm.toString(detail.maker)
                )
            );
            offerId = ofr.next;
        }
        console.log(unicode"└────┴─────────────────────");
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

contract TestPriceSensor is MyTest {
    TestImplementation internal priceSensor;
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
                decimals: 10
            }),
            defaultFee: 0,
            gasprice: 40,
            gasbase: 50_000,
            density: 10,
            gasmax: 2_000_000
        });

    TestTokenHelper internal base;
    TestTokenHelper internal quote;

    function setUp() public {
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
        priceSensor = new TestImplementation(
            address(mgv),
            address(this),
            address(base),
            address(quote),
            50_000
        );
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

    function setUpOrderBook() external {
        for (uint i = 0; i < 20; ) {
            priceSensor.newSensor{value: 1 ether}(
                0.005 ether + i * 0.0001 ether,
                0.004 ether + i * 0.0001 ether,
                0,
                i
            );

            unchecked {
                ++i;
            }
        }
    }

    function test_triggerStopLoss() public {
        vm.pauseGasMetering();
        this.setUpOrderBook();
        printOrderBook(mgv, address(base), address(quote));

        uint256[4][] memory targets = new uint[4][](1);
        /* offerId          */ targets[0][0] = 20;
        /* takerWants       */ targets[0][1] = 0.0059 ether;
        /* takerGives       */ targets[0][2] = 0.0069 ether;
        /* gasreq_permitted */ targets[0][3] = 50_000;
        (uint successes, uint takerGot, uint takerGave, , ) = mgv.snipes(
            address(base),
            address(quote),
            targets,
            true
        );

        assertEq(successes, 1);
        assertEq(countOffers(mgv, address(base), address(quote)), 19);
        assertEq(takerGot, 0.0059 ether);
        assertEq(takerGave, 0.0069 ether);

        printOrderBook(mgv, address(base), address(quote));
    }

    function test_takeSimpleOffer() public {
        vm.pauseGasMetering();
        this.setUpOrderBook();
        printOrderBook(mgv, address(base), address(quote));

        uint256[4][] memory targets = new uint[4][](1);
        /* offerId          */ targets[0][0] = 18;
        /* takerWants       */ targets[0][1] = 0.0057 ether;
        /* takerGives       */ targets[0][2] = 0.0067 ether;
        /* gasreq_permitted */ targets[0][3] = 50_000;
        (uint successes, uint takerGot, uint takerGave, , ) = mgv.snipes(
            address(base),
            address(quote),
            targets,
            true
        );

        assertEq(successes, 1);
        assertEq(countOffers(mgv, address(base), address(quote)), 20);
        assertEq(takerGot, 0.0057 ether);
        assertEq(takerGave, 0.0067 ether);
        printOrderBook(mgv, address(base), address(quote));
    }
}
