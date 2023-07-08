// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import {IPriceSensor} from "./interface/IPriceSensor.sol";

abstract contract PriceSensor is IPriceSensor {
    SensorData[] private _sensors;

    constructor() {}

    function _callBackFromSensor(
        SensorData calldata _sensor
    ) internal virtual {}
}
