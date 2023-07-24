// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

interface IPriceSensor {
    /// @notice Creates a new sensor
    /// @dev make sure to use a modifier like onlyAdmin to restrict access
    /// @param outboundToken the outbound token of the sensor
    /// @param inboundToken the inbound token of the sensor
    /// @param price the price of the sensor on which the stop loss should be triggered
    function newSensor(
        address outboundToken,
        address inboundToken,
        uint256 price
    ) external returns (uint256 idx);

    /// @notice Removes a sensor and its associated bait offer
    /// @param idx the id of the sensor to remove
    function removeSensor(uint256 idx) external;
}
