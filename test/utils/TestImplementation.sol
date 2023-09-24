// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import {IMangrove} from "mgv_src/IMangrove.sol";
import {MgvLib} from "mgv_src/MgvLib.sol";
import {Direct} from "mgv_src/strategies/offer_maker/abstract/Direct.sol";
import {SimpleRouter} from "mgv_src/strategies/routers/SimpleRouter.sol";
import {IERC20} from "mgv_src/IERC20.sol";

import {AbstractPriceSensor} from "../../src/AbstractPriceSensor.sol";

contract TestImplementation is AbstractPriceSensor, Direct {
    /// The outbound token of the sensor
    IERC20 private immutable _outbound_tkn;
    /// The inbound token of the sensor
    IERC20 private immutable _inbound_tkn;

    /// The gas requirement of the sensor (mostly used for the __callbackOnStopLoss__ function)
    uint256 private immutable _gasreq;

    constructor(
        address mgv,
        address deployer,
        address outbound_token_,
        address inbound_token_,
        uint256 gasreq_
    )
        Direct(IMangrove(payable(mgv)), new SimpleRouter(), 100_000, deployer)
        AbstractPriceSensor(mgv)
    {
        router().bind(address(this));
        _outbound_tkn = IERC20(outbound_token_);
        _inbound_tkn = IERC20(inbound_token_);
        _gasreq = gasreq_;
    }

    function newSensor(
        uint256 wants,
        uint256 gives,
        uint256 gasprice,
        uint256 pivotId
    ) public payable returns (uint256 offerId) {
        (offerId, ) = _newOffer(
            OfferArgs({
                outbound_tkn: _outbound_tkn,
                inbound_tkn: _inbound_tkn,
                wants: wants,
                gives: gives,
                gasreq: _gasreq,
                gasprice: gasprice,
                pivotId: pivotId,
                fund: msg.value,
                noRevert: false // useful for testing
            })
        );
    }

    function __posthookSuccess__(
        MgvLib.SingleOrder calldata order,
        bytes32 makerData
    ) internal override returns (bytes32) {
        __callbackOnOfferTaken__(order);
        return super.__posthookSuccess__(order, makerData);
    }

    function __callbackOnStopLoss__(
        MgvLib.SingleOrder calldata order
    ) internal virtual override {
        super.__callbackOnStopLoss__(order);
    }
}
