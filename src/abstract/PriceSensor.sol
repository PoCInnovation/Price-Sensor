// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import {IMangrove} from "mgv_src/IMangrove.sol";
import {IUniswapV3Pool} from "uniswap/interfaces/IUniswapV3Pool.sol";
import {MgvLib, MgvStructs} from "mgv_src/MgvLib.sol";
import {SetLib, Set} from "../library/Set.sol";

interface IPriceSensor {
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

    /// @notice Error emitted when the address is 0
    error ZeroAddressNotAllowed();

    /// @notice Error emitted when the price is 0
    error ZeroPriceNotAllowed();
}

/// @title PriceSensor
/// @author Martin Saldinger, Florian Lauch, Nathan Flattin
/// @dev This contract is used to create sensors that trigger a stop loss when a certain price is reached
/// @dev You need to inherit from this contract and implement the `__callbackOnStopLoss__` function
abstract contract PriceSensor is IPriceSensor {
    using SetLib for Set;

    /// mapping of watched uniwap pools for outbound and inbound token
    mapping(address outboundToken => mapping(address inboundToken => Set))
        private _uniswapPools;

    /// The mangrove contract
    IMangrove private immutable _MGV;

    /// @param mgv_ The mangrove contract
    constructor(address mgv_) {
        _MGV = IMangrove(payable(mgv_));
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

        /// bypass mangrove check of minimum gives
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

        // keep the uniswap pools sorted
        if (outboundToken > inboundToken) {
            (outboundToken, inboundToken) = (inboundToken, outboundToken);
        }

        /// add the uniswap pools to the mapping
        for (uint256 i = 0; i < uniswapPools.length; ) {
            _uniswapPools[outboundToken][inboundToken].add(uniswapPools[i]);

            unchecked {
                ++i;
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
        /// retract Mangrove offer
        provision = _MGV.retractOffer(outboundToken, inboundToken, id, true);
    }

    /// @notice callback function used to check if an offer was taken without sniping and if the stop loss was reached
    /// @dev make sure to call this function when an offer is taken using for example `__posthookSuccess__`, check the example folder for an example implementation
    /// @param order the order that was taken
    function __callbackOnOfferTaken__(
        MgvLib.SingleOrder calldata order
    ) internal {
        /// reconstruct the price
        uint256 price = order.wants * (1 ether / order.gives);

        address outboundToken = order.outbound_tkn;
        address inboundToken = order.inbound_tkn;

        if (outboundToken > inboundToken) {
            (outboundToken, inboundToken) = (inboundToken, outboundToken);
        }

        Set storage uniswapPools = _uniswapPools[outboundToken][inboundToken];

        if (uniswapPools.values.length == 0) {
            return;
        }

        uint256 average = 0;

        for (uint256 i = 0; i < uniswapPools.values.length; ) {
            (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(
                uniswapPools.values[i]
            ).slot0();

            /// compute the pool price
            /// https://blog.uniswap.org/uniswap-v3-math-primer
            uint256 poolPrice = (sqrtPriceX96 / 2 ** 96) ** 2;

            unchecked {
                average += poolPrice;
                ++i;
            }
        }

        average /= uniswapPools.values.length;

        // if the average price is lower than the price of the sensor it means that the stop loss was reached
        if (average > price) {
            __callbackOnStopLoss__(order);
        }
    }

    /// @notice Callback function called when a stop loss is reached and no snipe is detected
    /// @param order the bait offer id
    function __callbackOnStopLoss__(
        MgvLib.SingleOrder calldata order
    ) internal virtual {
        emit StopLossReached(order.offerId);
    }
}
