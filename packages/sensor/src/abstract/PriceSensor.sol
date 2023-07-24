// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import {IMangrove} from "mgv_src/IMangrove.sol";
import {Direct} from "mgv_src/strategies/offer_maker/abstract/Direct.sol";
import {MgvLib} from "mgv_src/MgvLib.sol";

/// @title PriceSensor
/// @author Martin Saldinger, Florian Lauch, Nathan Flattin
/// @dev This contract is used to create sensors that trigger a stop loss when a certain price is reached
/// @dev You need to inherit from this contract and implement the `__callbackOnStopLoss__` function
abstract contract PriceSensor {
    /// Events
    /// @param idx The index of the newly created sensor
    event NewSensor(uint256 indexed idx);
    /// @param idx The index of the sensor where the stop loss was reached
    event StopLossReached(uint256 indexed idx);

    /// Errors
    // ...

    /// Structs
    struct SensorData {
        address outboundToken;
        address inboundToken;
        uint256 mangroveOfferId;
        uint256 price;
        uint256 id;
    }

    /// @dev The sensors array
    SensorData[] private _sensors;
    /// @dev The mangrove contract
    IMangrove private _mgv;

    /// Creates a new PriceSensor
    /// @param mgv The mangrove contract
    constructor(IMangrove mgv) {
        _mgv = mgv;
    }

    /// @notice Creates a new sensor
    /// @param outboundToken the outbound token of the sensor
    /// @param inboundToken the inbound token of the sensor
    /// @param price the price of the sensor on which the stop loss should be triggered
    /// @return id the id of the newly created sensor
    function _newSensor(
        address outboundToken,
        address inboundToken,
        uint256 price
    ) internal returns (uint256 id) {
        // TODO: create sensor and its associated bait offer
    }

    /// @notice Removes a sensor
    /// @param id the id of the sensor to remove
    function _removeSensor(uint256 id) internal {
        // TODO: remove sensor and its associated bait offer
    }

    /// @notice Returns the sensors array
    function _getSensors() internal view returns (SensorData[] memory) {
        return _sensors;
    }

    /// @notice Returns a sensor by its index
    function _getSensor(uint256 idx) internal view returns (SensorData memory) {
        return _sensors[idx];
    }

    /// @notice callback function used to check if an offer was taken without sniping and if the stop loss was reached
    /// @dev make sure to call this function when an offer is taken using for example `__posthookSuccess__`, check the example folder for an example implementation
    /// @param order the order that was taken
    /// @param makerData the maker data of the order
    function __callbackOnOfferTaken__(
        MgvLib.SingleOrder calldata order,
        bytes32 makerData
    ) internal {
        // TODO:
        // if snipe detected do nothing
        // else call __callbackOnStopLoss__
        // __callbackOnStopLoss__();
    }

    /// @notice Callback function called when a stop loss is reached and no snipe is detected
    /// @param _sensor the sensor that was triggered
    function __callbackOnStopLoss__(
        SensorData calldata _sensor
    ) internal virtual {
        emit StopLossReached(_sensor.id);
    }
}
