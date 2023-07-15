// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import {IMangrove} from "mgv_src/IMangrove.sol";
import {MgvLib} from "mgv_src/MgvLib.sol";
import {Direct} from "mgv_src/strategies/offer_maker/abstract/Direct.sol";
import {SimpleRouter} from "mgv_src/strategies/routers/SimpleRouter.sol";

import {PriceSensor} from "../abstract/PriceSensor.sol";
import {IPriceSensor} from "../interface/IPriceSensor.sol";

contract ExampleImplementation is PriceSensor, IPriceSensor, Direct {
    event TestEvent(uint256 price);

    constructor(
        IMangrove mgv,
        address deployer
    ) Direct(mgv, new SimpleRouter(), 100_000, deployer) PriceSensor(mgv) {
        router().bind(address(this));
    }

    function newSensor(
        address outboundToken,
        address inboundToken,
        uint256 price
    ) external onlyAdmin returns (uint256 id) {
        return _newSensor(outboundToken, inboundToken, price);
    }

    function removeSensor(uint256 idx) external onlyAdmin {
        _removeSensor(idx);
    }

    function __posthookSuccess__(
        MgvLib.SingleOrder calldata order,
        bytes32 makerData
    ) internal override returns (bytes32) {
        super.__callbackOnOfferTaken__(order, makerData);
        return super.__posthookSuccess__(order, makerData);
    }

    function __callbackOnStopLoss__(
        SensorData calldata _sensor
    ) internal virtual override {
        // Do something with the sensor data
        emit TestEvent(_sensor.price);
        // Call the default parent function (for logging)
        super.__callbackOnStopLoss__(_sensor);
    }
}
