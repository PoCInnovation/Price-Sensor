// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import {IMangrove} from "mgv_src/IMangrove.sol";
import {Direct} from "mgv_src/strategies/offer_maker/abstract/Direct.sol";
import {MgvLib, MgvStructs} from "mgv_src/MgvLib.sol";
import {SetLib, Set} from "../library/Set.sol";

/// @title PriceSensor
/// @author Martin Saldinger, Florian Lauch, Nathan Flattin
/// @dev This contract is used to create sensors that trigger a stop loss when a certain price is reached
/// @dev You need to inherit from this contract and implement the `__callbackOnStopLoss__` function
abstract contract PriceSensor {
    /// @param baitOfferId The index of the newly created sensor
    event NewSensor(uint256 indexed baitOfferId);

    /// @param baitOfferId The index of the sensor where the stop loss was reached
    event StopLossReached(uint256 indexed baitOfferId);

    /// @notice Event emitted when a stop loss is reached
    /// @param outboundToken The outbound token of the sensor
    /// @param inboundToken The inbound token of the sensor
    /// @param price The price of the sensor on which the stop loss should be triggered
    event StopLossReached(
        address indexed outboundToken,
        address indexed inboundToken,
        uint256 price
    );

    error ZeroAddressNotAllowed();
    error ZeroPriceNotAllowed();

    // / @dev array of mangrove bait offers
    // uint256[] private _baitMangroveOffers;
    using SetLib for Set;

    /// @dev mapping of watched uniwap pools for outbound and inbound token
    mapping(address outboundToken => mapping(address inboundToken => Set))
        private _uniswapPools;

    /// @dev The mangrove contract
    IMangrove private immutable _MGV;

    /// Creates a new PriceSensor
    /// @param mgv_ The mangrove contract
    constructor(IMangrove mgv_) {
        _MGV = mgv_;
    }

    /// @notice Creates a new sensor
    /// @param outboundToken the outbound token of the sensor
    /// @param inboundToken the inbound token of the sensor
    /// @param price the price of the sensor on which the stop loss should be triggered
    /// @param gasreq the gas requirement of the sensor (mostly by the __callbackOnStopLoss__ function)
    /// @param pivotId index in order book (the more precise the pivot, the less expensive it is in gas)
    /// @return offerId the mangrove offerId of the newly bait offer
    function _newSensor(
        address[] calldata uniswapPools,
        address outboundToken,
        address inboundToken,
        uint256 price,
        uint256 gasreq,
        uint256 pivotId
    ) internal returns (uint256 offerId) {
        if (outboundToken == address(0) || inboundToken == address(0)) {
            revert ZeroAddressNotAllowed();
        }
        if (price == 0) {
            revert ZeroPriceNotAllowed();
        }

        (, MgvStructs.LocalUnpacked memory local) = _MGV.configInfo(
            outboundToken,
            inboundToken
        );

        uint256 gives = (gasreq + local.offer_gasbase) * local.density;
        uint256 wants = price / (1 ether / gives);

        offerId = _MGV.newOffer{value: msg.value}(
            outboundToken,
            inboundToken,
            wants,
            gives,
            gasreq,
            0,
            pivotId
        );

        if (outboundToken > inboundToken) {
            (outboundToken, inboundToken) = (inboundToken, outboundToken);
        }

        // add the uniswap pools to the mapping
        for (uint256 i = 0; i < uniswapPools.length; ) {
            _uniswapPools[outboundToken][inboundToken].add(uniswapPools[i]);

            unchecked {
                i++;
            }
        }

        emit NewSensor(offerId);
    }

    /// @notice Removes a sensor
    /// @param outboundToken outbound token of the sensor
    /// @param inboundToken inbound token of the sensor
    /// @param id the id of the sensor to remove
    function _removeSensor(
        address outboundToken,
        address inboundToken,
        uint256 id
    ) internal returns (uint256 provision) {
        /// @dev retract Mangrove offer
        provision = _MGV.retractOffer(outboundToken, inboundToken, id, true);
    }

    /// @notice callback function used to check if an offer was taken without sniping and if the stop loss was reached
    /// @dev make sure to call this function when an offer is taken using for example `__posthookSuccess__`, check the example folder for an example implementation
    /// @param order the order that was taken
    /// @param makerData the maker data of the order
    function __callbackOnOfferTaken__(
        MgvLib.SingleOrder calldata order,
        bytes32 makerData
    ) internal returns (bytes32) {
        // if ()
        // if (order.)
        // TODO:
        // if snipe detected do nothing
        // else call __callbackOnStopLoss__
        // __callbackOnStopLoss__();
    }

    /// @notice Callback function called when a stop loss is reached and no snipe is detected
    /// @param order the bait offer id
    function __callbackOnStopLoss__(
        MgvLib.SingleOrder calldata order
    ) internal virtual {
        emit StopLossReached(order.offerId);
    }
}
