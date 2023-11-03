// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test,console} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test{
    //events
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle,helperConfig) = deployer.run();

        (
        entranceFee,
        interval,
        vrfCoordinator,
        gasLane,
        subscriptionId,
        callbackGasLimit,
        link
        ) = helperConfig.activeNetworkConfig();

     vm.deal(PLAYER , STARTING_USER_BALANCE);
    }
    

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /////////////////
    ///enter raffle//
    /////////////////
    function testRaffleRevertsWhenYouDontPayEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value : 1 ether}();
        address playerRecorded = raffle.getPlayers(0);
        assert(playerRecorded == address(PLAYER));
    }

    function testEmitsEventOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true ,false ,false ,false , address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value : entranceFee}();
    }

    function testCantEnterWhenRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value : entranceFee}();
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number+1);
        raffle.performUpkeep("");

        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value : entranceFee}();
    }

    ///////////////// 
    //CheckUpkeep/// 
    ////////////////

    function testCheckUpKeepReturnsFalseIfEnoughTimeHasntPassed() public{
        vm.warp(block.timestamp + 1);
        vm.roll(block.number);

        (bool upKeepNeeded ,) = raffle.checkUpKeep("");
        assert(upKeepNeeded == false);
    }

    function testCheckUpKeepReturnsFalseIfRffleNotOpen() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value : entranceFee}();
        vm.warp(block.timestamp + interval+ 1);
        vm.roll(block.number +1);

        raffle.performUpkeep("");

        (bool upKeepNeeded ,) = raffle.checkUpKeep("");
        assert(upKeepNeeded == false);
    }

    function testCheckUpKeepReturnsFalseIfRaffleHasZeroBalance() public{
        vm.warp(block.timestamp + interval+ 1);
        vm.roll(block.number +1);

        (bool upKeepNeeded ,) = raffle.checkUpKeep("");
        assert(upKeepNeeded == false);
    }

    function testCheckUpkeepReturnsTrueWhenParametersGood() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");

        // Assert
        assert(upkeepNeeded);
    }

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");
    }

    function testPerformUpKeepRevertsIfCheckUpkeepIsFalse() public {
        uint256 balance = 0;
        uint256 numPlayers =0;
        uint256 raffleState = 0;
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpKeepNotNeeded.selector ,balance ,numPlayers,raffleState)
            );
        raffle.performUpkeep("");
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value : entranceFee}();
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitRequestId() public raffleEnteredAndTimePassed{
        vm.recordLogs();
        raffle.performUpkeep(""); //emit RequestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        console.log(uint256(requestId));

        assert(uint256(requestId) > 0);

    }

     function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep()
        public
        raffleEnteredAndTimePassed
        
    {
        // Arrange
        // Act / Assert
        vm.expectRevert("nonexistent request");
        // vm.mockCall could be used here...
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            0,
            address(raffle)
        );

        vm.expectRevert("nonexistent request");

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            1,
            address(raffle)
        );
    }
}

