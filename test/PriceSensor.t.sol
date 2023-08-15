// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {IMangrove} from "mgv_src/IMangrove.sol";
import {MgvStructs} from "mgv_src/MgvLib.sol";
import {IERC20} from "mgv_src/IERC20.sol";
import {PriceSensor} from "../src/abstract/PriceSensor.sol";

contract PriceSensorPublic is PriceSensor {
    constructor(IMangrove mgv) PriceSensor(mgv) {}

    function newSensor(
        address[] calldata uniswapPools,
        address outboundToken,
        address inboundToken,
        uint256 price
    ) public payable returns (uint256 id) {
        return
            _newSensor(
                uniswapPools,
                outboundToken,
                inboundToken,
                price,
                30_000,
                0
            );
    }

    function removeSensor(
        address outboundToken,
        address inboundToken,
        uint256 id
    ) public returns (uint256 provision) {
        return _removeSensor(outboundToken, inboundToken, id);
    }
}

IMangrove constant MGV = IMangrove(
    payable(address(0xd1805f6Fe12aFF69D4264aE3e49ef320895e2D8b))
);

contract TestPriceSensor is Test {
    PriceSensorPublic public priceSensor;
    address public account;

    address constant USDT = 0xe8099699aa4A79d89dBD20A63C50b7d35ED3CD9e;
    address constant WMATIC = 0x193163EeFfc795F9d573b171aB12cCDdE10392e8;

    function setUp() public {
        priceSensor = new PriceSensorPublic(MGV);
        account = vm.envAddress("ACCOUNT");
    }

    function mintToken(address token, uint256 amount) private {
        (bool send, ) = token.call(
            abi.encodeWithSignature("mint(uint256)", amount)
        );
        require(send, "minting failed");
    }

    function test_newSensor() public {
        vm.startPrank(account);

        uint256 mintAmount = 10000000;

        mintToken(USDT, mintAmount);
        mintToken(WMATIC, mintAmount);

        address[] memory uniswapPools = new address[](2);
        uniswapPools[0] = address(1);
        uniswapPools[1] = address(2);

        console.log("test: ", 0.68 ether / (1 ether / 0.0001 ether));

        uint256 offerId = priceSensor.newSensor{value: 0.001 ether}(
            uniswapPools,
            USDT,
            WMATIC,
            0.68 ether
        );

        (, MgvStructs.LocalUnpacked memory local) = IMangrove(MGV).configInfo(
            USDT,
            WMATIC
        );

        console.log("active: ", local.active);
        console.log("fee: ", local.fee);
        console.log("density: ", local.density);
        console.log("offer_gasbase: ", local.offer_gasbase);
        console.log("lock: ", local.lock);
        console.log("best: ", local.best);
        console.log("last: ", local.last);

        (
            MgvStructs.OfferUnpacked memory offer,
            MgvStructs.OfferDetailUnpacked memory offerDetail
        ) = IMangrove(MGV).offerInfo(WMATIC, USDT, offerId);

        console.log("account: ", account);
        console.log("priceSensor: ", address(priceSensor));

        console.log("offer.prev: ", offer.prev);
        console.log("offer.next: ", offer.next);
        console.log("offer.wants: ", offer.wants);
        console.log("offer.gives: ", offer.gives);

        console.log("offerDetail.maker: ", offerDetail.maker);
        console.log("offerDetail.gasreq: ", offerDetail.gasreq);
        console.log("offerDetail.offer_gasbase: ", offerDetail.offer_gasbase);
        console.log("offerDetail.gaspric: ", offerDetail.gasprice);

        vm.stopPrank();
    }
}
