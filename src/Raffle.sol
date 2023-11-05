// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20 ;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {LinkToken} from "../test/mock/LinkToken.sol";



/**NatSpec(Natural specifications) comments are special comments in Solidity code that can be used to generate documentation and provide explanations about the purpose and functionality of a smart contract */

/**
 * @title A sample Raffle Contract
 * @author Yuvaraj
 * @notice This contract is for creating a sample raffle
 * @dev Implements chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2 {
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpKeepNotNeeded(
        uint256 currentBalance, 
        uint256 numPlayers, 
        uint256 raffleState //RaffleState raffleState
    );

    /** Type Decalrations */
    enum RaffleState {
        OPEN,       //0
        CALCULATING //1
    }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

   

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval; // @dev duration of the lottery in seconds
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    LinkToken private immutable i_link;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /**Events */
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee ,
        uint256 interval ,
        address vrfCoordinator ,
        bytes32 gasLane ,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        address link
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        s_lastTimeStamp = block.timestamp;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        i_link = LinkToken(link);
    }

    function enterRaffle()  public payable {
      //  require(msg.value >= i_entranceFee , "Not enough ETH sent! ");
      
      /**Here both require and below if block does the same thing its just that .custom error are more gas efficient and writing contract name bfr the custom is the best practice */
      if(msg.value < i_entranceFee){
        revert Raffle__NotEnoughEthSent();
      }
      if(s_raffleState != RaffleState.OPEN){
        revert Raffle__RaffleNotOpen();
      }
      s_players.push(payable(msg.sender));

      emit EnteredRaffle(msg.sender);
    }

    function checkUpkeep(bytes memory /*checkData */) public view returns(bool upKeepNeeded,bytes memory /* performData */) {
       bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
       bool isOpen = RaffleState.OPEN == s_raffleState;
       bool hasBalance = address(this).balance > 0;
       bool hasPlayers = s_players.length > 0;
       upKeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return(upKeepNeeded ,"0x0");
    }


    function performUpkeep(bytes calldata /* performData */) external {
        (bool upKeepNeeded ,) = checkUpkeep("");
        if(!upKeepNeeded){
            revert Raffle__UpKeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedRaffleWinner(requestId);
    }

    /**CEI(Reccomended design pattern) : checks ,effects , interactions */
    function fulfillRandomWords(
        uint256 /**requestId*/,
        uint256[] memory randomWords
    ) internal override {
        //checks

        //effects
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
        emit PickedWinner(winner);
        //interactions(other contract)
        (bool success , ) = winner.call{value: address(this).balance}("");
        if(!success){
            revert Raffle__TransferFailed();
        }
    }

    /** Getter Functions */

    function getEntranceFee() external view returns(uint256){
        return i_entranceFee;
    }

    function getRaffleState() external view returns(RaffleState){
        return s_raffleState;
    }

    function getPlayers(uint256 indexOfPlayer) external view returns(address){
        return s_players[indexOfPlayer];
    }

    function getRecentWinner() external view returns(address){
        return s_recentWinner;
    }

    function getLengthOfPlayers() external view returns(uint256){
        return s_players.length;
    }

    function getTimeStamp() external view returns(uint256){
        return s_lastTimeStamp;
    }
}
