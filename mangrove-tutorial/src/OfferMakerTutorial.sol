// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

// Import the types we will be using below
import {Direct} from "mgv_src/strategies/offer_maker/abstract/Direct.sol";
import {ILiquidityProvider} from "mgv_src/strategies/interfaces/ILiquidityProvider.sol";
import {IMangrove} from "mgv_src/IMangrove.sol";
import {IERC20, MgvLib} from "mgv_src/MgvLib.sol";
import {SimpleRouter} from "mgv_src/strategies/routers/SimpleRouter.sol";

/// @title An example offer maker used in tutorials
contract OfferMakerTutorial is Direct, ILiquidityProvider {
    ///@notice Constructor
    ///@param mgv The core Mangrove contract
    ///@param deployer The address of the deployer
    constructor(IMangrove mgv, address deployer) Direct(mgv, new SimpleRouter(), 100_000, deployer) {
        router().bind(address(this));
    }

    ///@inheritdoc ILiquidityProvider
    function newOffer(
        IERC20 outbound_tkn,
        IERC20 inbound_tkn,
        uint256 wants,
        uint256 gives,
        uint256 pivotId,
        uint256 gasreq
    )
        public
        payable /* the function is payable to allow us to provision an offer*/
        onlyAdmin /* only the admin of this contract is allowed to post offers using this contract*/
        returns (uint256 offerId)
    {
        (offerId,) = _newOffer(
            OfferArgs({
                outbound_tkn: outbound_tkn,
                inbound_tkn: inbound_tkn,
                wants: wants,
                gives: gives,
                gasreq: gasreq,
                gasprice: 0,
                pivotId: pivotId, // a best pivot estimate for cheap offer insertion in the offer list - this should be a parameter computed off-chain for cheaper insertion
                fund: msg.value, // WEIs in that are used to provision the offer.
                noRevert: false // we want to revert on error
            })
        );
    }

    ///@inheritdoc ILiquidityProvider
    function updateOffer(
        IERC20 outbound_tkn,
        IERC20 inbound_tkn,
        uint256 wants,
        uint256 gives,
        uint256 pivotId,
        uint256 offerId,
        uint256 gasreq
    ) public payable override adminOrCaller(address(MGV)) {
        _updateOffer(
            OfferArgs({
                outbound_tkn: outbound_tkn,
                inbound_tkn: inbound_tkn,
                wants: wants,
                gives: gives,
                gasreq: gasreq,
                gasprice: 0,
                pivotId: pivotId,
                fund: msg.value,
                noRevert: false
            }),
            offerId
        );
    }

    ///@inheritdoc ILiquidityProvider
    function retractOffer(IERC20 outbound_tkn, IERC20 inbound_tkn, uint256 offerId, bool deprovision)
        public
        adminOrCaller(address(MGV))
        returns (uint256 freeWei)
    {
        return _retractOffer(outbound_tkn, inbound_tkn, offerId, deprovision);
    }

    ///@notice Event emitted when the offer is taken successfully.
    ///@param someData is a dummy parameter.
    event OfferTakenSuccessfully(uint256 someData);

    ///@notice Post-hook that is invoked when the offer is taken successfully.
    ///@inheritdoc Direct
    function __posthookSuccess__(MgvLib.SingleOrder calldata, bytes32) internal virtual override returns (bytes32) {
        emit OfferTakenSuccessfully(42);
        return 0;
    }
}
