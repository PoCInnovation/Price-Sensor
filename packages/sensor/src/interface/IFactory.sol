// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

interface IFactory {
    /// Event emitted when a new price sensor is created
    /// @param sensor The address of the new sensor
    event NewPriceSensor(address indexed sensor);

    /// @notice Creates a new price sensor
    /// @dev the caller of this function is the admin of the new sensor
    /// @return sensor The address of the new sensor
    function newPriceSensor() external returns (address);
}
