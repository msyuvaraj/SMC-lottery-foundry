// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script , console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mock/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {

    function createSubscription(address vrfCoordinator ,uint256 deployerKey) public returns(uint64){
        console.log("creating subscription on chainId" , block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("your subId is" ,subId );
        console.log("please update your subId in the helperConfig");
        return subId;
    }
    
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, , , , ,uint256 deployerKey) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinator ,deployerKey);
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script{
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscription(uint64 subId , address vrfCoordinator , address link) public {
        if(block.chainid == 31337){
            vm.startBroadcast();
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(subId , FUND_AMOUNT);
            vm.stopBroadcast();
        }else {
            vm.startBroadcast();
            LinkToken(link).transferAndCall(vrfCoordinator ,FUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }
    }

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, ,uint64 subId ,,address link ,) = helperConfig.activeNetworkConfig();
        fundSubscription(subId , vrfCoordinator , link);
    }
    
    function run() public {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(address vrfCoordinator , address contractToAddToVrf , uint64 subId ,uint256 deployerKey) public {
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(
            subId,
            contractToAddToVrf
        );
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, ,uint64 subId ,, ,uint256 deployerKey) = helperConfig.activeNetworkConfig();
        addConsumer(vrfCoordinator, mostRecentlyDeployed, subId ,deployerKey);

    }
    
    function run() external {
         address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}