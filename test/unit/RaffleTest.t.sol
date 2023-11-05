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
    uint256 deployerKey;

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
        link,
        //deployerKey
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

        (bool upKeepNeeded ,) = raffle.checkUpkeep("");
        assert(upKeepNeeded == false);
    }

    function testCheckUpKeepReturnsFalseIfRffleNotOpen() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value : entranceFee}();
        vm.warp(block.timestamp + interval+ 1);
        vm.roll(block.number +1);

        raffle.performUpkeep("");

        (bool upKeepNeeded ,) = raffle.checkUpkeep("");
        assert(upKeepNeeded == false);
    }

    function testCheckUpKeepReturnsFalseIfRaffleHasZeroBalance() public{
        vm.warp(block.timestamp + interval+ 1);
        vm.roll(block.number +1);

        (bool upKeepNeeded ,) = raffle.checkUpkeep("");
        assert(upKeepNeeded == false);
    }

    function testCheckUpkeepReturnsTrueWhenParametersGood() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

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
       Raffle.RaffleState rState = raffle.getRaffleState();
       console.log(address(raffle));
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpKeepNotNeeded.selector ,balance ,numPlayers , rState)
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

    modifier skipFork() {
        if(block.chainid != 31337){
            return;
        }
        _;
    }

     function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId)
        public
        skipFork
        raffleEnteredAndTimePassed
        
    {
        // Arrange
        // Act / Assert
        vm.expectRevert("nonexistent request");
        //vm.mockCall could be used here...
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );

        vm.expectRevert("nonexistent request");

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        skipFork
        raffleEnteredAndTimePassed {
            uint256 additionalEntrants =5;
            uint256 startingIndex = 1;
            for (uint256 i= startingIndex ; i < startingIndex + additionalEntrants;i++){
                address player = address(uint160(i));
                hoax(player , STARTING_USER_BALANCE);
                raffle.enterRaffle{value : entranceFee}();
            }

            uint256 prizeMoney = entranceFee * (additionalEntrants + 1);

            vm.recordLogs();
            raffle.performUpkeep(""); //emit requestId
            Vm.Log[] memory entries = vm.getRecordedLogs();
            bytes32 requestId = entries[1].topics[1];
            console.log(uint256(requestId));
            
            uint256 previousTimeStamp = raffle.getTimeStamp();

            //pretend to be chainlink vrf to get random number & pick winner
            VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
                uint256(requestId),
                address(raffle)
            );

            console.log(raffle.getRecentWinner());


            uint256 balanceOfRecentWinner = address(raffle.getRecentWinner()).balance;

            assert(uint256(raffle.getRaffleState()) == 0);
            assert(raffle.getRecentWinner() != address(0));
            assert(raffle.getLengthOfPlayers() == 0);
            assert(raffle.getTimeStamp() > previousTimeStamp );


           assert(balanceOfRecentWinner == (prizeMoney+(STARTING_USER_BALANCE-entranceFee)));
        }
}

