// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

interface IPriceSensor {
    struct SensorData {
        address outboundToken;
        address inboundToken;
        uint256 mangroveOfferId;
        uint256 price;
        uint256 id;
    }

    function newSensor(
        address outboundToken,
        address inboundToken,
        uint256 price
    ) external returns (uint256 id);

    function removeSensor(uint256 id) external;
}
