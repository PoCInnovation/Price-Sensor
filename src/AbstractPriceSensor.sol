// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import {IMangrove} from "mgv_src/IMangrove.sol";
import {MgvLib, MgvStructs} from "mgv_src/MgvLib.sol";
import {IERC20} from "mgv_src/IERC20.sol";

import {IPriceSensor} from "./IPriceSensor.sol";

/// @title PriceSensor
/// @author Martin Saldinger, Nathan Flattin
/// @dev This contract is used to create sensors that trigger a stop loss when a certain price is reached
/// @dev You need to inherit from this contract and implement the `__callbackOnStopLoss__` function
abstract contract AbstractPriceSensor is IPriceSensor {
    /// The mangrove contract
    IMangrove private immutable _MGV;

    /// @param mgv_ The mangrove contract
    constructor(address mgv_) {
        _MGV = IMangrove(payable(mgv_));
    }

    /// @notice callback function used to check if an offer was taken without sniping and if the stop loss was reached
    /// @dev make sure to call this function when an offer is taken using for example `__posthookSuccess__`, check the example folder for an example implementation
    /// @param order the order that was taken
    function __callbackOnOfferTaken__(
        MgvLib.SingleOrder calldata order
    ) internal {
        uint256 newBestOfferId = _MGV.best(
            order.outbound_tkn,
            order.inbound_tkn
        );

        (MgvStructs.OfferUnpacked memory newBestOffer, ) = _MGV.offerInfo(
            order.outbound_tkn,
            order.inbound_tkn,
            newBestOfferId
        );

        //                newBestOffer.wants                  order.offer.wants()
        // newBestPrice = ------------------  >=  oldPrice =  -------------------
        //                newBestOffer.gives                  order.offer.gives()
        //
        // if newBestPrice is lower than oldPrice, then the stop loss was reached

        if (
            order.offer.gives() * newBestOffer.wants >=
            newBestOffer.gives * order.offer.wants()
        ) {
            __callbackOnStopLoss__(order);
        }
        // else repost the offer
        else {
            _MGV.updateOffer(
                order.outbound_tkn,
                order.inbound_tkn,
                order.offer.wants(),
                order.offer.gives(),
                order.offerDetail.gasreq(),
                order.offerDetail.gasprice(),
                order.offer.next(),
                order.offerId
            );
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
