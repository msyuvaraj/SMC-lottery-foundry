// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19 ;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription , AddConsumer , FundSubscription} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() public returns(Raffle , HelperConfig){
        HelperConfig helperConfig = new HelperConfig(); //0x104fBc016F4bb334D775a19E8A6510109AC63E00
        (
            uint256 entranceFee,
            uint256 interval,
            address vrfCoordinator,
            bytes32 gasLane,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            address link
        ) = helperConfig.activeNetworkConfig();

        if(subscriptionId == 0){
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(vrfCoordinator);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                subscriptionId,
                vrfCoordinator,
                link
            );

        }

       vm.startBroadcast();
       Raffle raffle = new Raffle( //0xA8452Ec99ce0C64f20701dB7dD3abDb607c00496 0x037eDa3aDB1198021A9b2e88C22B464fD38db3f3
             entranceFee,
             interval,
             vrfCoordinator,
             gasLane,
             subscriptionId,
             callbackGasLimit,
             link
       );
       vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(vrfCoordinator , address(raffle) , subscriptionId);
    

        return (raffle , helperConfig);
    }
}
