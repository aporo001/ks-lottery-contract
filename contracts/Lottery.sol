// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

contract Lottery is VRFConsumerBase, Ownable {
    enum LOTTERY_STATE {
        OPEN,
        CLOSED,
        CALCULATING_WINNER
    }
    LOTTERY_STATE public lottery_state;
    address[] public players;
    uint256 public lotteryId;
    IERC20 internal iKitcoin;

    uint256 public ticketPrice;

    bytes32 internal keyHash;
    uint256 internal fee;

    mapping(bytes32 => uint256) internal mapRequestIdToLotteryId;
    mapping(uint256 => address) public mapLotteryIdToWinningAddress;
    mapping(uint256 => uint256) public mapLotteryIdToRandomNumber;
    mapping(uint256 => mapping(address => uint256))
        internal roundAddressCountTicket;

    constructor(address _kitCoinAddr, uint256 _ticketPrice)
        public
        VRFConsumerBase(
            0x8C7382F9D8f56b33781fE506E897a4F1e2d17255, // VRF Coordinator
            0x326C977E6efc84E512bB9C30f76E30c160eD06FB // LINK Token
        )
    {
        lotteryId = 1;
        lottery_state = LOTTERY_STATE.CLOSED;
        iKitcoin = IERC20(_kitCoinAddr);
        ticketPrice = _ticketPrice;

        keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
        fee = 0.0001 * 10**18; // 0.1 LINK (Varies by network)
    }

    function getNumberOfBuyTicket(uint256 _lotteryId, address addr)
        public
        view
        returns (uint256 count)
    {
        return roundAddressCountTicket[_lotteryId][addr];
    }

    function startNewLottery() public onlyOwner {
        require(
            lottery_state == LOTTERY_STATE.CLOSED,
            "can't start a new lottery yet"
        );
        lottery_state = LOTTERY_STATE.OPEN;
    }

    function enter() public {
        require(lottery_state == LOTTERY_STATE.OPEN, "lottery state not open");
        require(
            iKitcoin.allowance(msg.sender, address(this)) >= ticketPrice,
            "not allowace kitcoin"
        );

        iKitcoin.transferFrom(msg.sender, address(this), ticketPrice);
        players.push(msg.sender);

        roundAddressCountTicket[lotteryId][msg.sender] =
            roundAddressCountTicket[lotteryId][msg.sender] +
            1;
    }

    /**
     * Requests randomness
     */
    function pickWinner() public onlyOwner {
        require(
            LINK.balanceOf(address(this)) >= fee,
            "Not enough LINK - fill contract with faucet"
        );
        lottery_state = LOTTERY_STATE.CALCULATING_WINNER;
        bytes32 requestId = requestRandomness(keyHash, fee);
        mapRequestIdToLotteryId[requestId] = lotteryId;
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        require(
            lottery_state == LOTTERY_STATE.CALCULATING_WINNER,
            "You aren't at that stage yet!"
        );
        require(randomness > 0, "random-not-found");
        uint256 lid = mapRequestIdToLotteryId[requestId];

        uint256 index = randomness % players.length;

        mapLotteryIdToRandomNumber[lid] = randomness;
        address winningAddr = players[index];
        iKitcoin.transfer(winningAddr, iKitcoin.balanceOf(address(this)));
        mapLotteryIdToWinningAddress[lid] = winningAddr;
        players = new address[](0);

        lottery_state = LOTTERY_STATE.CLOSED;
        lotteryId = lotteryId + 1;
    }
}
