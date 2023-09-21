// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import {IMangrove} from "mgv_src/IMangrove.sol";
import {MgvLib} from "mgv_src/MgvLib.sol";
import {Direct} from "mgv_src/strategies/offer_maker/abstract/Direct.sol";
import {SimpleRouter} from "mgv_src/strategies/routers/SimpleRouter.sol";

import {PriceSensor} from "../abstract/PriceSensor.sol";

contract ExampleImplementation is PriceSensor, Direct {
    event TestEvent(uint256 indexed offerId);

    constructor(
        address mgv,
        address deployer
    )
        Direct(IMangrove(payable(mgv)), new SimpleRouter(), 100_000, deployer)
        PriceSensor(mgv)
    {
        router().bind(address(this));
    }

    function newSensor(
        address[] calldata uniswapPools,
        address outboundToken,
        address inboundToken,
        uint256 price
    ) public payable returns (uint256 offerId) {
        offerId = _newSensor(
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
        provision = _removeSensor(outboundToken, inboundToken, id);
    }

    function __posthookSuccess__(
        MgvLib.SingleOrder calldata order,
        bytes32 makerData
    ) internal override returns (bytes32) {
        super.__callbackOnOfferTaken__(order);
        return super.__posthookSuccess__(order, makerData);
    }

    function __callbackOnStopLoss__(
        MgvLib.SingleOrder calldata order
    ) internal virtual override {
        // Do something with the sensor data
        emit TestEvent(order.offerId);
        // Call the default parent function (for logging)
        super.__callbackOnStopLoss__(order);
    }
}
