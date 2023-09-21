// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

interface IPriceSensor {
    /// @param baitOfferId The index of the newly created sensor
    event NewSensor(uint256 indexed baitOfferId);

    /// @param baitOfferId The index of the sensor where the stop loss was reached
    event StopLossReached(uint256 indexed baitOfferId);

    /// @notice Event emitted when a stop loss is reached
    /// @param outboundToken The outbound token of the sensor
    /// @param inboundToken The inbound token of the sensor
    event StopLossReached(
        address indexed outboundToken,
        address indexed inboundToken
    );

    event DEBUG(uint256 p1, uint256 p2);
}
