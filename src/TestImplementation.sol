// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import {IMangrove} from "mgv_src/IMangrove.sol";
import {MgvLib} from "mgv_src/MgvLib.sol";
import {PriceSensor} from "./PriceSensor.sol";
import {Direct} from "mgv_src/strategies/offer_maker/abstract/Direct.sol";
import {SimpleRouter} from "mgv_src/strategies/routers/SimpleRouter.sol";

contract TestImplementation is PriceSensor, Direct {
    event TestEvent(uint256 id, uint256 price);

    constructor(
        IMangrove mgv,
        address deployer
    ) Direct(mgv, new SimpleRouter(), 100_000, deployer) PriceSensor(mgv) {
        router().bind(address(this));
    }

    function __posthookSuccess__(
        MgvLib.SingleOrder calldata order,
        bytes32 makerData
    ) internal override returns (bytes32) {
        __callbackWhenOfferTaken__(order, makerData);
        return super.__posthookSuccess__(order, makerData);
    }

    function __callbackOnStopLoss__(
        SensorData calldata _sensor
    ) internal virtual override {
        // Do something with the sensor data
        emit TestEvent(_sensor.id, _sensor.price);
    }
}
