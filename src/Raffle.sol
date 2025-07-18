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
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.18;

import {VRFConsumerBaseV2Plus} from '@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol';
import {VRFV2PlusClient} from '@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol';

/**
 * @title A simple Raffle contract
 * @author oderah
 * @notice A simple Raffle lottery contact
 * @dev Raffle lottery
 */

/**
 * customErrors
 */
error Raffle__SendMoreToEnterRaffle();
error Raffle__RaffelWillStartSoon();
error Raffle__TransferFailed();
error Raffle__RaffleNOtOpen();

contract Raffle is VRFConsumerBaseV2Plus {
  /* Type declearations */

  enum RaffleState {
    OPEN, //0
    CALCULATING //1
  }

  /**
   * State variable
   * type visibility name
   */
  uint32 private constant NUM_WORDS = 1;
  uint16 private constant REQUEST_CONFIRMATIONS = 3;
  uint256 private immutable i_entranceFee;
  uint256 private immutable i_interval;
  bytes32 private immutable i_keyHash;
  uint256 private immutable i_subscriptionId;
  uint32 private immutable i_callbackGasLimit;

  uint256 private s_lastRaffleTime;
  address payable[] private s_players;
  address private s_recentWinner;
  RaffleState private s_raffleState;

  /**
   * Events
   */
  event RaffleEntered(address indexed player);
  event WinnerPicked(address indexed winner);

  constructor(
    uint256 entranceFee,
    uint256 interval,
    address vrfCoordinator,
    bytes32 gasLane,
    uint256 subscriptionId,
    uint32 callbackGasLimit
  ) VRFConsumerBaseV2Plus(vrfCoordinator) {
    i_entranceFee = entranceFee;
    i_interval = interval;
    i_keyHash = gasLane;
    i_subscriptionId = subscriptionId;
    i_callbackGasLimit = callbackGasLimit;

    s_lastRaffleTime = block.timestamp;
    s_raffleState = RaffleState.OPEN;
  }

  function enterRaffle() external payable {
    if (msg.value < i_entranceFee) revert Raffle__SendMoreToEnterRaffle();

    if (s_raffleState != RaffleState.OPEN) {
      revert Raffle__RaffleNOtOpen();
    }

    s_players.push(payable(msg.sender));
    emit RaffleEntered(msg.sender);
  }

  function pickWinner() external {
    if ((block.timestamp - s_lastRaffleTime) < i_interval) {
      revert Raffle__RaffelWillStartSoon();
    }

    s_raffleState = RaffleState.CALCULATING;
    VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
      keyHash: i_keyHash,
      subId: i_subscriptionId,
      requestConfirmations: REQUEST_CONFIRMATIONS,
      callbackGasLimit: i_callbackGasLimit,
      numWords: NUM_WORDS,
      extraArgs: VRFV2PlusClient._argsToBytes(
        // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
        VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
      )
    });

    uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
  }

  /**
   * Getter functions
   */
  function getEntranceFee() external view returns (uint256) {
    return i_entranceFee;
  }

  function fulfillRandomWords(
    uint256 requestId,
    uint256[] calldata randomWords
  ) internal virtual override {
    uint256 indexOfWinner = randomWords[0] % s_players.length;

    address payable recentWinner = s_players[indexOfWinner];

    s_recentWinner = recentWinner;
    s_raffleState = RaffleState.OPEN;
    s_players = new address payable[](0);
    s_lastRaffleTime = block.timestamp;

    (bool success, ) = recentWinner.call{value: address(this).balance}('');
    if (!success) {
      revert Raffle__TransferFailed();
    }
    emit WinnerPicked(s_recentWinner);
  }
}
