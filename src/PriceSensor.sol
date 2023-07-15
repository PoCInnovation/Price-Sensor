// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import {IMangrove} from "mgv_src/IMangrove.sol";
import {Direct} from "mgv_src/strategies/offer_maker/abstract/Direct.sol";
import {MgvLib} from "mgv_src/MgvLib.sol";
import {IPriceSensor} from "./interface/IPriceSensor.sol";

///@notice make sure to call __callbackWhenOfferTaken__ when an offer is taken using for example __posthookSuccess__
abstract contract PriceSensor is IPriceSensor {
    SensorData[] private _sensors;

    constructor(IMangrove mgv) {}

    function newSensor(
        address outboundToken,
        address inboundToken,
        uint256 price
    ) external returns (uint256 id) {
        // TODO:
    }

    function removeSensor(uint256 id) external {
        // TODO:
    }

    function __callbackWhenOfferTaken__(
        MgvLib.SingleOrder calldata order,
        bytes32 makerData
    ) internal {
        // TODO:
        // if snipe detected do nothing
        // else call __callbackOnStopLoss__
        // __callbackOnStopLoss__(_sensor);
    }

    ///@notice Callback function called when a stop loss is reached and no snipe is detected
    function __callbackOnStopLoss__(
        SensorData calldata _sensor
    ) internal virtual {}
}
