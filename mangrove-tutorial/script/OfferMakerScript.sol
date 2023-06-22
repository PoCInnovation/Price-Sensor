// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import {OfferMakerTutorial} from "../src/OfferMakerTutorial.sol";
import {IMangrove} from "mgv_src/IMangrove.sol";
import {IERC20} from "mgv_src/IERC20.sol";
import {MgvLib} from "mgv_src/MgvLib.sol";
import {AbstractRouter} from "mgv_src/strategies/routers/AbstractRouter.sol";

contract Base is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployerAddress = vm.envAddress("ADMIN_ADDRESS");

    address MGV = vm.envAddress("MANGROVE");
    address USDT = vm.envAddress("USDT");
    address WMATIC = vm.envAddress("WMATIC");
}

contract DeployOfferMaker is Base {
    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        OfferMakerTutorial offerMaker = new OfferMakerTutorial(IMangrove(payable(MGV)), deployerAddress);

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(USDT);
        tokens[1] = IERC20(WMATIC);

        offerMaker.activate(tokens);

        console.log("offerMakerTutorial deployed at: ", address(offerMaker));

        vm.stopBroadcast();
    }
}

contract MintTokens is Base {
    address OFFER_MAKER = vm.envAddress("OFFER_MAKER");

    function mintToken(address token, uint256 amount) private {
        (bool send,) = token.call(abi.encodeWithSignature("mint(uint256)", amount));
        require(send, "mint failed");
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        uint256 mintAmount = 100000000000;
        mintToken(USDT, mintAmount);
        mintToken(WMATIC, mintAmount);

        address router = address(OfferMakerTutorial(payable(OFFER_MAKER)).router());

        IERC20(USDT).approve(router, IERC20(USDT).balanceOf(deployerAddress));
        IERC20(WMATIC).approve(router, IERC20(WMATIC).balanceOf(deployerAddress));

        IERC20(USDT).approve(OFFER_MAKER, IERC20(USDT).balanceOf(deployerAddress));
        IERC20(WMATIC).approve(OFFER_MAKER, IERC20(WMATIC).balanceOf(deployerAddress));

        IERC20(USDT).approve(MGV, IERC20(USDT).balanceOf(deployerAddress));
        IERC20(WMATIC).approve(MGV, IERC20(WMATIC).balanceOf(deployerAddress));

        vm.stopBroadcast();
    }
}

contract TokensBalance is Base {
    address OFFER_MAKER = vm.envAddress("OFFER_MAKER");

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        address router = address(OfferMakerTutorial(payable(OFFER_MAKER)).router());

        console.log("USDT balance: \t\t", IERC20(USDT).balanceOf(deployerAddress));
        console.log("WMATIC balance: \t\t", IERC20(WMATIC).balanceOf(deployerAddress));

        console.log("USDT allowance (MAKER): \t", IERC20(USDT).allowance(deployerAddress, OFFER_MAKER));
        console.log("WMATIC allowance (MAKER): \t", IERC20(WMATIC).allowance(deployerAddress, OFFER_MAKER));

        console.log("USDT allowance (MGV): \t", IERC20(USDT).allowance(deployerAddress, MGV));
        console.log("WMATIC allowance (MGV): \t", IERC20(WMATIC).allowance(deployerAddress, MGV));

        console.log("USDT allowance (router): \t", IERC20(USDT).allowance(deployerAddress, router));
        console.log("WMATIC allowance (router): \t", IERC20(WMATIC).allowance(deployerAddress, router));

        vm.stopBroadcast();
    }
}

contract PostOffer is Base {
    address OFFER_MAKER = vm.envAddress("OFFER_MAKER");

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        uint256 wants = 10000000000;
        uint256 gives = 1000000000;
        uint256 gasreq = 1000000;

        uint256 offerId = OfferMakerTutorial(payable(OFFER_MAKER)).newOffer{value: 0.01 ether}(
            IERC20(USDT), IERC20(WMATIC), wants, gives, 0, gasreq
        );

        console.log("offerId: ", offerId);

        vm.stopBroadcast();
    }
}

contract SnipeOffer is Base {
    uint256 OFFER_ID = vm.envUint("OFFER_ID");

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        uint256[4][] memory targets = new uint [4][](1);

        targets[0][0] = OFFER_ID;
        targets[0][1] = 100000000;
        targets[0][2] = 1000000000;
        targets[0][3] = 1000000 + 10;

        IMangrove(payable(MGV)).snipes(USDT, WMATIC, targets, true);

        vm.stopBroadcast();
    }
}
